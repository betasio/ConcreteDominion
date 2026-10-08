"""Server-controlled PvP seasons, immutable results and cosmetic prestige."""
import time

SEASON_SECONDS = 28 * 86400
ARCHIVE_SCHEMA = """
CREATE TABLE IF NOT EXISTS season_archives(
 season_id INTEGER PRIMARY KEY, starts_at INTEGER NOT NULL,
 ends_at INTEGER NOT NULL, finalized_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS season_awards(
 season_id INTEGER NOT NULL, faction_id TEXT NOT NULL,
 rank INTEGER NOT NULL, points INTEGER NOT NULL, wins INTEGER NOT NULL,
 faction_name TEXT NOT NULL, faction_tag TEXT NOT NULL, badge TEXT NOT NULL,
 PRIMARY KEY(season_id,faction_id),
 FOREIGN KEY(season_id) REFERENCES season_archives(season_id)
);
"""

def current_season(now=None):
    timestamp = int(time.time() if now is None else now)
    season = timestamp // SEASON_SECONDS
    return {"id":season,"starts_at":season*SEASON_SECONDS,
            "ends_at":(season+1)*SEASON_SECONDS}


def _standings(store, start, end):
    rows = store.execute(
        """SELECT f.id AS faction_id, f.name, f.tag,
        COALESCE(i.emblem,'shield') AS emblem,
        COALESCE(i.banner,'obsidian') AS banner,
        COALESCE(SUM(l.points),0) AS points,
        COALESCE(SUM(CASE WHEN l.points=100 AND l.reason='pvp_settlement'
          THEN 1 ELSE 0 END),0) AS wins,
        COUNT(l.match_id) AS settled
        FROM factions f
        LEFT JOIN faction_identity i ON i.faction_id=f.id
        LEFT JOIN pvp_ledger l ON l.faction_id=f.id
          AND l.created_at >= ? AND l.created_at < ?
        GROUP BY f.id
        ORDER BY points DESC, wins DESC, f.name ASC, f.id ASC""",
        (start,end)
    ).fetchall()
    return [dict(row,rank=i+1) for i,row in enumerate(rows)]


def leaderboard(store, faction_id, now=None):
    season = current_season(now)
    entries = _standings(store,season["starts_at"],season["ends_at"])
    rank = next((row["rank"] for row in entries if row["faction_id"]==faction_id),None)
    return {"season":season,"leaderboard":entries[:100],"your_rank":rank,
            "source":"server_settlements","redeemable":False}


def _badge(rank, points):
    if points <= 0:
        return ""
    return {1:"CHAMPION",2:"RUNNER_UP",3:"PODIUM"}.get(rank,"VETERAN")


def finalize_expired(store, now=None):
    """Archive ended seasons with settled points; never finalize a current season.

    Call under Store.lock. Archives are immutable and written in one SQLite transaction.
    """
    current = current_season(now)["id"]
    row = store.execute("SELECT MIN(created_at) AS first FROM pvp_ledger WHERE points>0").fetchone()
    if row is None or row["first"] is None:
        return
    first = int(row["first"]) // SEASON_SECONDS
    with store.db:
        for season_id in range(first,min(current,first+128)):
            if store.execute("SELECT 1 FROM season_archives WHERE season_id=?",(season_id,)).fetchone():
                continue
            start,end = season_id*SEASON_SECONDS,(season_id+1)*SEASON_SECONDS
            standings = _standings(store,start,end)
            store.execute(
                "INSERT INTO season_archives(season_id,starts_at,ends_at,finalized_at) VALUES(?,?,?,?)",
                (season_id,start,end,int(time.time() if now is None else now))
            )
            for entry in standings:
                if entry["points"] <= 0:
                    continue
                store.execute(
                    """INSERT INTO season_awards(season_id,faction_id,rank,points,wins,
                       faction_name,faction_tag,badge) VALUES(?,?,?,?,?,?,?,?)""",
                    (season_id,entry["faction_id"],entry["rank"],entry["points"],
                     entry["wins"],entry["name"],entry["tag"],_badge(entry["rank"],entry["points"]))
                )


def history(store, faction_id, now=None):
    finalize_expired(store,now)
    rows = store.execute(
        """SELECT s.season_id,s.starts_at,s.ends_at,a.faction_id,a.rank,a.points,
           a.wins,a.faction_name,a.faction_tag,a.badge
           FROM season_awards a JOIN season_archives s ON s.season_id=a.season_id
           ORDER BY s.season_id DESC,a.rank ASC LIMIT 300"""
    ).fetchall()
    champions = []
    awards = []
    for row in rows:
        item = dict(row)
        if item["rank"] == 1 and item["points"] > 0:
            champions.append(item)
        if item["faction_id"] == faction_id:
            awards.append(item)
    return {"completed_seasons":store.execute("SELECT COUNT(*) FROM season_archives").fetchone()[0],
            "champions":champions[:20],"your_awards":awards[:20],
            "cosmetic_only":True,"redeemable":False}
