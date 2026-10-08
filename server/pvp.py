"""Server-authoritative development PvP matchmaking and settlement.

Two separate factions queue, then each side gets six attacks. All combat points,
standings, and non-spendable season ledger points are computed by the server.
"""
import json
import secrets
import time

QUEUE_TTL_SECONDS = 900
MATCH_TTL_SECONDS = 86400

PVP_SCHEMA = """
CREATE TABLE IF NOT EXISTS pvp_queue (
 faction_id TEXT PRIMARY KEY,
 queued_at INTEGER NOT NULL DEFAULT (unixepoch()),
 FOREIGN KEY(faction_id) REFERENCES factions(id)
);
CREATE TABLE IF NOT EXISTS pvp_matches (
 id TEXT PRIMARY KEY,
 faction_a TEXT NOT NULL, faction_b TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('active','complete')),
 score_a INTEGER NOT NULL DEFAULT 0, score_b INTEGER NOT NULL DEFAULT 0,
 rounds_a INTEGER NOT NULL DEFAULT 0, rounds_b INTEGER NOT NULL DEFAULT 0,
 winner_id TEXT NOT NULL DEFAULT '',
 created_at INTEGER NOT NULL DEFAULT (unixepoch()),
 FOREIGN KEY(faction_a) REFERENCES factions(id),
 FOREIGN KEY(faction_b) REFERENCES factions(id)
);
CREATE TABLE IF NOT EXISTS pvp_attacks (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 match_id TEXT NOT NULL, faction_id TEXT NOT NULL, player_id TEXT NOT NULL,
 request_id TEXT NOT NULL, strategy TEXT NOT NULL,
 defense TEXT NOT NULL, points INTEGER NOT NULL,
 UNIQUE(player_id,request_id),
 FOREIGN KEY(match_id) REFERENCES pvp_matches(id)
);
CREATE TABLE IF NOT EXISTS pvp_ledger (
 match_id TEXT NOT NULL, faction_id TEXT NOT NULL,
 points INTEGER NOT NULL, reason TEXT NOT NULL,
 created_at INTEGER NOT NULL DEFAULT (unixepoch()),
 PRIMARY KEY(match_id,faction_id),
 FOREIGN KEY(match_id) REFERENCES pvp_matches(id)
);
CREATE INDEX IF NOT EXISTS pvp_match_a ON pvp_matches(faction_a,status);
CREATE INDEX IF NOT EXISTS pvp_match_b ON pvp_matches(faction_b,status);
"""


def _expire(store):
    now = int(time.time())
    with store.db:
        store.execute("DELETE FROM pvp_queue WHERE queued_at < ?", (now - QUEUE_TTL_SECONDS,))
        expired = store.execute(
            "SELECT id,faction_a,faction_b FROM pvp_matches WHERE status='active' AND created_at < ?",
            (now - MATCH_TTL_SECONDS,)
        ).fetchall()
        for match in expired:
            store.execute("UPDATE pvp_matches SET status='complete',winner_id='' WHERE id=?", (match["id"],))
            for fid in (match["faction_a"],match["faction_b"]):
                store.execute(
                    "INSERT OR IGNORE INTO pvp_ledger(match_id,faction_id,points,reason,created_at) VALUES(?,?,0,'pvp_timeout',unixepoch())",
                    (match["id"],fid)
                )


def _member_faction(store, actor):
    from server.app import ApiError
    fid = actor["faction_id"]
    if not fid or not store.execute(
        "SELECT 1 FROM memberships WHERE player_id=? AND faction_id=?",
        (actor["id"],fid)
    ).fetchone():
        raise ApiError(403, "Faction membership required")
    return fid


def _active_match(store, fid):
    return store.execute(
        "SELECT * FROM pvp_matches WHERE (faction_a=? OR faction_b=?) AND status='active' ORDER BY rowid DESC LIMIT 1",
        (fid,fid)
    ).fetchone()


def _latest_match(store, fid):
    return store.execute(
        "SELECT * FROM pvp_matches WHERE faction_a=? OR faction_b=? ORDER BY rowid DESC LIMIT 1",
        (fid,fid)
    ).fetchone()


def _snapshot(store, fid):
    war = _latest_match(store,fid)
    queue = bool(store.execute("SELECT 1 FROM pvp_queue WHERE faction_id=?", (fid,)).fetchone())
    if war is None:
        return {"queued":queue,"match":None,"attacks":[],"contributions":[],"ledger":[]}
    side_a = war["faction_a"] == fid
    opponent_id = war["faction_b"] if side_a else war["faction_a"]
    opponent = store.execute("SELECT name,tag FROM factions WHERE id=?", (opponent_id,)).fetchone()
    identities = {}
    for team_id in (fid, opponent_id):
        row = store.execute("""SELECT f.id,f.name,f.tag,
            COALESCE(i.emblem,'shield') AS emblem,
            COALESCE(i.banner,'obsidian') AS banner
            FROM factions f LEFT JOIN faction_identity i ON i.faction_id=f.id
            WHERE f.id=?""", (team_id,)).fetchone()
        identities[team_id] = dict(row)
    rounds = war["rounds_a"] if side_a else war["rounds_b"]
    defense = ("watchful","fortified","mobile")[rounds % 3] if war["status"] == "active" and rounds < 6 else ""
    attacks = store.execute(
        "SELECT player_id,strategy,defense,points FROM pvp_attacks WHERE match_id=? ORDER BY id", (war["id"],)
    ).fetchall()
    members = store.execute(
        """SELECT p.id AS player_id,p.display_name,COUNT(a.id) AS attacks,
        COALESCE(SUM(a.points),0) AS contribution
        FROM memberships m JOIN players p ON p.id=m.player_id
        LEFT JOIN pvp_attacks a ON a.player_id=p.id AND a.match_id=?
        WHERE m.faction_id=? GROUP BY p.id ORDER BY contribution DESC""",
        (war["id"],fid)
    ).fetchall()
    ledger = store.execute(
        "SELECT faction_id,points,reason FROM pvp_ledger WHERE match_id=?", (war["id"],)
    ).fetchall()
    return {"queued":queue,"match":{
        "id":war["id"],"status":war["status"],"opponent_name":opponent["name"],
        "opponent_tag":opponent["tag"],"our_score":war["score_a"] if side_a else war["score_b"],
        "enemy_score":war["score_b"] if side_a else war["score_a"],
        "our_rounds":rounds,"enemy_rounds":war["rounds_b"] if side_a else war["rounds_a"],
        "result":"DRAW" if war["status"] == "complete" and not war["winner_id"] else (
            "VICTORY" if war["winner_id"] == fid else "DEFEAT"
        ) if war["status"] == "complete" else "",
        "defense":defense
    },"our_identity":identities[fid],"opponent_identity":identities[opponent_id],
       "attacks":[dict(r) for r in attacks],
       "contributions":[dict(r) for r in members],
       "ledger":[dict(r) for r in ledger]}


def route(store, method, path, data, actor):
    from server.app import ApiError
    if path not in ("/v1/pvp", "/v1/pvp/queue", "/v1/pvp/attack", "/v1/pvp/cancel"):
        return None
    fid = _member_faction(store, actor)
    _expire(store)
    if method == "GET" and path == "/v1/pvp":
        return 200, _snapshot(store,fid)

    if method == "POST" and path == "/v1/pvp/queue":
        leader = store.execute("SELECT role FROM memberships WHERE player_id=? AND faction_id=?",
                               (actor["id"],fid)).fetchone()
        if leader is None or leader["role"] != "leader":
            raise ApiError(403,"Only Faction leaders may queue")
        if _active_match(store,fid):
            raise ApiError(409,"Faction already has an active PvP match")
        if store.execute("SELECT 1 FROM pvp_queue WHERE faction_id=?", (fid,)).fetchone():
            return 200, _snapshot(store,fid)
        with store.db:
            opponent = store.execute(
                """SELECT q.faction_id FROM pvp_queue q WHERE q.faction_id != ?
                AND NOT EXISTS (SELECT 1 FROM pvp_matches m
                  WHERE m.status='active' AND (m.faction_a=q.faction_id OR m.faction_b=q.faction_id))
                ORDER BY q.queued_at,q.rowid LIMIT 1""", (fid,)
            ).fetchone()
            if opponent is None:
                store.execute("INSERT INTO pvp_queue(faction_id) VALUES(?)",(fid,))
            else:
                oid = opponent["faction_id"]
                match_id = secrets.token_hex(12)
                store.execute("DELETE FROM pvp_queue WHERE faction_id=?",(oid,))
                store.execute(
                    "INSERT INTO pvp_matches(id,faction_a,faction_b,status) VALUES(?,?,?,'active')",
                    (match_id,oid,fid)
                )
        return 200, _snapshot(store,fid)

    if method == "POST" and path == "/v1/pvp/cancel":
        role = store.execute("SELECT role FROM memberships WHERE player_id=? AND faction_id=?",
                             (actor["id"],fid)).fetchone()
        if role is None or role["role"] != "leader":
            raise ApiError(403, "Only Faction leaders may cancel queue")
        with store.db:
            deleted = store.execute("DELETE FROM pvp_queue WHERE faction_id=?", (fid,)).rowcount
        if not deleted:
            raise ApiError(409, "Faction is not queued; active matches cannot be cancelled")
        return 200, _snapshot(store,fid)

    if method == "POST" and path == "/v1/pvp/attack":
        request_id = data.get("request_id")
        strategy = data.get("strategy")
        if not isinstance(request_id,str) or len(request_id) != 32 or any(c not in "0123456789abcdef" for c in request_id):
            raise ApiError(400,"32-character lowercase hexadecimal request_id required")
        if strategy not in ("muscle","convoy","intel"):
            raise ApiError(400,"Invalid attack strategy")
        previous = store.execute(
            "SELECT match_id,faction_id,strategy,defense,points FROM pvp_attacks WHERE player_id=? AND request_id=?",
            (actor["id"],request_id)
        ).fetchone()
        if previous:
            if previous["faction_id"] != fid or previous["strategy"] != strategy:
                raise ApiError(409,"Request ID reused with different parameters")
            return 200, {"replayed":True,"match_id":previous["match_id"],
                         "points":previous["points"],"defense":previous["defense"]}
        war = _active_match(store,fid)
        if war is None:
            raise ApiError(409,"No active PvP match")
        side_a = war["faction_a"] == fid
        rounds = war["rounds_a"] if side_a else war["rounds_b"]
        if rounds >= 6:
            raise ApiError(409,"Your Faction used all six attacks")
        own = store.execute(
            "SELECT COUNT(*) FROM pvp_attacks WHERE match_id=? AND player_id=?",
            (war["id"],actor["id"])
        ).fetchone()[0]
        if own >= 3:
            raise ApiError(409,"Player has used all three attacks")
        defense = ("watchful","fortified","mobile")[rounds % 3]
        points = 140 if {"muscle":"watchful","convoy":"fortified","intel":"mobile"}[strategy] == defense else 90
        with store.db:
            store.execute(
                """INSERT INTO pvp_attacks(match_id,faction_id,player_id,request_id,strategy,defense,points)
                VALUES(?,?,?,?,?,?,?)""",
                (war["id"],fid,actor["id"],request_id,strategy,defense,points)
            )
            column_score = "score_a" if side_a else "score_b"
            column_rounds = "rounds_a" if side_a else "rounds_b"
            store.execute(
                f"UPDATE pvp_matches SET {column_score}={column_score}+?, {column_rounds}={column_rounds}+1 WHERE id=?",
                (points,war["id"])
            )
            final = store.execute("SELECT * FROM pvp_matches WHERE id=?",(war["id"],)).fetchone()
            if final["rounds_a"] == 6 and final["rounds_b"] == 6:
                winner = final["faction_a"] if final["score_a"] > final["score_b"] else (
                    final["faction_b"] if final["score_b"] > final["score_a"] else ""
                )
                store.execute("UPDATE pvp_matches SET status='complete',winner_id=? WHERE id=?",
                              (winner,war["id"]))
                for candidate in (final["faction_a"],final["faction_b"]):
                    earned = 100 if candidate == winner else (50 if not winner else 25)
                    store.execute(
                        "INSERT INTO pvp_ledger(match_id,faction_id,points,reason,created_at) VALUES(?,?,?,'pvp_settlement',unixepoch())",
                        (war["id"],candidate,earned)
                    )
        return 200, {"replayed":False,"match_id":war["id"],"points":points,
                     "defense":defense,"state":_snapshot(store,fid)}
    raise ApiError(404,"Unknown PvP endpoint")
