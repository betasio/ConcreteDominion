"""Server-authoritative direct challenges between previously matched Factions."""
import secrets
import time

CHALLENGE_SCHEMA = """
CREATE TABLE IF NOT EXISTS pvp_challenges(
 id TEXT PRIMARY KEY, challenger_id TEXT NOT NULL, target_id TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('pending','accepted','declined','cancelled','expired')),
 created_at INTEGER NOT NULL, match_id TEXT,
 FOREIGN KEY(challenger_id) REFERENCES factions(id),
 FOREIGN KEY(target_id) REFERENCES factions(id),
 FOREIGN KEY(match_id) REFERENCES pvp_matches(id)
);
CREATE UNIQUE INDEX IF NOT EXISTS one_pending_direct_challenge
 ON pvp_challenges(challenger_id,target_id) WHERE status='pending';
CREATE INDEX IF NOT EXISTS challenge_inbox ON pvp_challenges(target_id,status);
"""
TTL = 86400


def _ready(store, fid):
    from server import pvp
    return not pvp._active_match(store,fid) and not store.execute(
        "SELECT 1 FROM pvp_queue WHERE faction_id=?", (fid,)
    ).fetchone()


def route(store, method, path, data, actor):
    from server.app import ApiError
    if path != "/v1/pvp/challenges" and not path.startswith("/v1/pvp/challenges/"):
        return None
    fid = actor["faction_id"]
    if not fid or not store.execute("SELECT 1 FROM memberships WHERE player_id=? AND faction_id=?",
                                    (actor["id"],fid)).fetchone():
        raise ApiError(403,"Faction membership required")
    from server import pvp
    pvp._expire(store)
    with store.db:
        store.execute("UPDATE pvp_challenges SET status='expired' WHERE status='pending' AND created_at<?",
                      (int(time.time())-TTL,))
    if method == "GET" and path == "/v1/pvp/challenges":
        rows = store.execute("""SELECT c.id,c.challenger_id,c.target_id,c.status,c.created_at,c.match_id,
             f.name AS opponent_name,f.tag AS opponent_tag
             FROM pvp_challenges c JOIN factions f
              ON f.id=CASE WHEN c.challenger_id=? THEN c.target_id ELSE c.challenger_id END
             WHERE c.challenger_id=? OR c.target_id=?
             ORDER BY c.created_at DESC,c.rowid DESC LIMIT 30""",(fid,fid,fid)).fetchall()
        return 200, {"challenges":[dict(row, direction="sent" if row["challenger_id"]==fid else "received") for row in rows]}
    role = store.execute("SELECT role FROM memberships WHERE player_id=? AND faction_id=?",
                         (actor["id"],fid)).fetchone()
    if method != "POST" or role is None or role["role"] != "leader":
        raise ApiError(403,"Faction leader required")
    if path == "/v1/pvp/challenges":
        target = data.get("target_faction_id")
        if not isinstance(target,str) or len(target)!=24 or any(c not in "0123456789abcdef" for c in target) or target==fid:
            raise ApiError(400,"Invalid rival Faction ID")
        if not store.execute("SELECT 1 FROM factions WHERE id=?",(target,)).fetchone():
            raise ApiError(404,"Faction not found")
        if not store.execute("""SELECT 1 FROM pvp_matches m JOIN pvp_ledger l ON l.match_id=m.id
           WHERE m.status='complete' AND l.faction_id=? AND
            ((m.faction_a=? AND m.faction_b=?) OR (m.faction_a=? AND m.faction_b=?))
           LIMIT 1""",(fid,fid,target,target,fid)).fetchone():
            raise ApiError(403,"Only previous rivals may be challenged")
        if not _ready(store,fid) or not _ready(store,target):
            raise ApiError(409,"Both Factions must be out of matchmaking and active matches")
        pending = store.execute("""SELECT id FROM pvp_challenges WHERE status='pending' AND
         ((challenger_id=? AND target_id=?) OR (challenger_id=? AND target_id=?))""",
         (fid,target,target,fid)).fetchone()
        if pending:
            raise ApiError(409,"A challenge is already pending between these Factions")
        cid = secrets.token_hex(12)
        with store.db:
            store.execute("""INSERT INTO pvp_challenges(id,challenger_id,target_id,status,created_at)
             VALUES(?,?,?,'pending',?)""",(cid,fid,target,int(time.time())))
        return 201, {"challenge_id":cid,"status":"pending"}
    parts=path.split("/")
    if len(parts)!=6 or parts[:4]!=["","v1","pvp","challenges"] or parts[5] not in ("accept","decline","cancel"):
        raise ApiError(404,"Unknown challenge endpoint")
    cid,action=parts[4],parts[5]
    challenge=store.execute("SELECT * FROM pvp_challenges WHERE id=?",(cid,)).fetchone()
    if challenge is None or fid not in (challenge["challenger_id"],challenge["target_id"]):
        raise ApiError(404,"Challenge not found")
    if action=="accept" and challenge["status"]=="accepted" and fid==challenge["target_id"]:
        return 200, {"challenge_id":cid,"status":"accepted","match_id":challenge["match_id"]}
    if challenge["status"]!="pending":
        raise ApiError(409,"Challenge is not pending")
    if action=="cancel":
        if fid!=challenge["challenger_id"]:
            raise ApiError(403,"Only challenger may cancel")
        status="cancelled"
    else:
        if fid!=challenge["target_id"]:
            raise ApiError(403,"Only challenged leader may respond")
        status="accepted" if action=="accept" else "declined"
    match_id = None
    with store.db:
        if action=="accept":
            if not _ready(store,challenge["challenger_id"]) or not _ready(store,challenge["target_id"]):
                raise ApiError(409,"Both Factions must be available for a rematch")
            match_id = secrets.token_hex(12)
            store.execute("INSERT INTO pvp_matches(id,faction_a,faction_b,status) VALUES(?,?,?,'active')",
                          (match_id,challenge["challenger_id"],challenge["target_id"]))
            store.execute("""UPDATE pvp_challenges SET status='cancelled'
                 WHERE status='pending' AND id!=? AND
                 (challenger_id IN (?,?) OR target_id IN (?,?))""",
                 (cid,challenge["challenger_id"],challenge["target_id"],
                  challenge["challenger_id"],challenge["target_id"]))
        store.execute("UPDATE pvp_challenges SET status=?,match_id=? WHERE id=?",
                      (status,match_id,cid))
    return 200, {"challenge_id":cid,"status":status,"match_id":match_id}
