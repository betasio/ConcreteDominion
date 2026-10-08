"""Read-only server-authoritative 28-day PvP seasons (UTC epoch windows)."""
import time

SEASON_SECONDS = 28 * 86400


def current_season(now=None):
    timestamp = int(time.time() if now is None else now)
    season = timestamp // SEASON_SECONDS
    return {"id": season, "starts_at": season * SEASON_SECONDS,
            "ends_at": (season + 1) * SEASON_SECONDS}


def leaderboard(store, faction_id, now=None):
    season = current_season(now)
    rows = store.execute(
        """SELECT f.id AS faction_id, f.name, f.tag,
        COALESCE(SUM(l.points),0) AS points,
        SUM(CASE WHEN l.points=100 AND l.reason='pvp_settlement' THEN 1 ELSE 0 END) AS wins,
        COUNT(l.match_id) AS settled
        FROM factions f
        LEFT JOIN pvp_ledger l ON l.faction_id=f.id
          AND l.created_at >= ? AND l.created_at < ?
        GROUP BY f.id ORDER BY points DESC, wins DESC, f.name ASC, f.id ASC
        LIMIT 100""",
        (season["starts_at"],season["ends_at"])
    ).fetchall()
    entries = []
    for index, row in enumerate(rows):
        entry = dict(row)
        entry["rank"] = index + 1
        entries.append(entry)
    your_rank = next((item["rank"] for item in entries if item["faction_id"] == faction_id), None)
    return {"season":season, "leaderboard":entries, "your_rank":your_rank,
            "source":"server_settlements", "redeemable":False}
