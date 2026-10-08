"""ConcreteDominion multiplayer prototype: standard-library HTTP API + SQLite.

Launch: python3 -m server.app --db ./server/data.sqlite --host 127.0.0.1 --port 8765
This is a development server, NOT an internet-ready identity provider.
"""
import argparse
import hashlib
import json
import secrets
import sqlite3
import threading
from server import pvp, seasons, profiles, rivalries, challenges
from server.security import RateLimiter
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SCHEMA = """
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS players (
  id TEXT PRIMARY KEY, display_name TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE, recovery_hash TEXT, faction_id TEXT
);
CREATE TABLE IF NOT EXISTS factions (
  id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE,
  tag TEXT NOT NULL UNIQUE, leader_id TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS memberships (
  faction_id TEXT NOT NULL, player_id TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL CHECK(role IN ('leader','member')),
  PRIMARY KEY(faction_id,player_id),
  FOREIGN KEY(faction_id) REFERENCES factions(id),
  FOREIGN KEY(player_id) REFERENCES players(id)
);
CREATE TABLE IF NOT EXISTS invitations (
  id TEXT PRIMARY KEY, faction_id TEXT NOT NULL,
  target_player TEXT NOT NULL, inviter_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('pending','accepted','declined')),
  FOREIGN KEY(faction_id) REFERENCES factions(id)
);
CREATE INDEX IF NOT EXISTS invitations_target ON invitations(target_player,status);
CREATE TABLE IF NOT EXISTS wars (
 id TEXT PRIMARY KEY, faction_id TEXT NOT NULL, opponent_name TEXT NOT NULL,
 status TEXT NOT NULL, our_score INTEGER NOT NULL DEFAULT 0,
 their_score INTEGER NOT NULL DEFAULT 0, rounds INTEGER NOT NULL DEFAULT 0,
 result TEXT NOT NULL DEFAULT '',
 FOREIGN KEY(faction_id) REFERENCES factions(id)
);
CREATE UNIQUE INDEX IF NOT EXISTS one_active_war ON wars(faction_id) WHERE status='active';
CREATE TABLE IF NOT EXISTS war_attacks (
 id INTEGER PRIMARY KEY AUTOINCREMENT, war_id TEXT NOT NULL, player_id TEXT NOT NULL,
 strategy TEXT NOT NULL, defense TEXT NOT NULL, our_points INTEGER NOT NULL,
 enemy_points INTEGER NOT NULL
);
"""

class ApiError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message

class Store:
    def __init__(self, path):
        self.lock = threading.RLock()
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.db.executescript(SCHEMA)
        self.db.executescript(pvp.PVP_SCHEMA)
        self.db.executescript(seasons.ARCHIVE_SCHEMA)
        self.db.executescript(profiles.PROFILE_SCHEMA)
        self.db.executescript(challenges.CHALLENGE_SCHEMA)
        if "created_at" not in {r["name"] for r in self.db.execute("PRAGMA table_info(pvp_ledger)")}:
            self.db.execute("ALTER TABLE pvp_ledger ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0")
            self.db.execute("UPDATE pvp_ledger SET created_at=unixepoch() WHERE created_at=0")
        if 'recovery_hash' not in {row['name'] for row in self.db.execute('PRAGMA table_info(players)')}:
            self.db.execute('ALTER TABLE players ADD COLUMN recovery_hash TEXT')
        # Existing development databases predate the PvP timeout timestamp.
        columns = {row["name"] for row in self.db.execute("PRAGMA table_info(pvp_matches)")}
        if "created_at" not in columns:
            self.db.execute("ALTER TABLE pvp_matches ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0")
            self.db.execute("UPDATE pvp_matches SET created_at=unixepoch() WHERE created_at=0")
        self.db.commit()

    def execute(self, query, params=()):
        return self.db.execute(query, params)

    def player(self, token):
        digest = hashlib.sha256(token.encode()).hexdigest()
        row = self.execute("SELECT id,display_name,faction_id FROM players WHERE token_hash=?", (digest,)).fetchone()
        if row is None:
            raise ApiError(401, "Invalid session")
        return row

    def call(self, method, path, data, token):
        if method == "POST" and path == "/v1/players":
            name = str(data.get("display_name", "")).strip()
            if not 2 <= len(name) <= 32:
                raise ApiError(400, "Display name must contain 2–32 characters")
            player_id, session = secrets.token_hex(12), secrets.token_urlsafe(32)
            recovery_key = secrets.token_urlsafe(32)
            with self.db:
                self.execute("INSERT INTO players(id,display_name,token_hash,recovery_hash) VALUES(?,?,?,?)",
                             (player_id,name,hashlib.sha256(session.encode()).hexdigest(),hashlib.sha256(recovery_key.encode()).hexdigest()))
            return 201, {"player_id":player_id,"session_token":session,"recovery_key":recovery_key}
        if method == "POST" and path == "/v1/recover":
            player_id = data.get("player_id")
            recovery_key = data.get("recovery_key")
            if not isinstance(player_id,str) or not isinstance(recovery_key,str):
                raise ApiError(400,"Player ID and recovery key required")
            key_hash = hashlib.sha256(recovery_key.encode()).hexdigest()
            account = self.execute("SELECT id FROM players WHERE id=? AND recovery_hash=?", (player_id,key_hash)).fetchone()
            if account is None:
                raise ApiError(401,"Invalid recovery credentials")
            new_session, new_recovery = secrets.token_urlsafe(32),secrets.token_urlsafe(32)
            with self.db:
                self.execute("UPDATE players SET token_hash=?,recovery_hash=? WHERE id=?",
                    (hashlib.sha256(new_session.encode()).hexdigest(),
                     hashlib.sha256(new_recovery.encode()).hexdigest(),player_id))
            return 200, {"player_id":player_id,"session_token":new_session,"recovery_key":new_recovery}
        if not token:
            raise ApiError(401, "Bearer token required")
        actor = self.player(token)
        if method == "GET" and path == "/v1/me":
            return 200, {"player_id":actor["id"],"display_name":actor["display_name"],
                         "faction_id":actor["faction_id"]}
        if method == "POST" and path == "/v1/factions":
            if actor["faction_id"]:
                raise ApiError(409, "Already in a Faction")
            name, tag = str(data.get("name","")).strip(), str(data.get("tag","")).strip().upper()
            if not 3 <= len(name) <= 32 or not 2 <= len(tag) <= 5 or not tag.isalnum():
                raise ApiError(400, "Invalid Faction name or tag")
            fid = secrets.token_hex(12)
            try:
                with self.db:
                    self.execute("INSERT INTO factions(id,name,tag,leader_id) VALUES(?,?,?,?)",
                                 (fid,name,tag,actor["id"]))
                    self.execute("INSERT INTO memberships(faction_id,player_id,role) VALUES(?,?,?)",
                                 (fid,actor["id"],"leader"))
                    self.execute("UPDATE players SET faction_id=? WHERE id=?", (fid,actor["id"]))
            except sqlite3.IntegrityError:
                raise ApiError(409, "Faction name or tag already exists")
            return 201, {"faction_id":fid,"name":name,"tag":tag}
        if method == "GET" and path == "/v1/faction":
            if not actor["faction_id"]:
                raise ApiError(404, "Not in a Faction")
            f = self.execute("SELECT id,name,tag,leader_id FROM factions WHERE id=?",
                             (actor["faction_id"],)).fetchone()
            members = self.execute("""SELECT m.player_id,p.display_name,m.role FROM memberships m
                JOIN players p ON p.id=m.player_id WHERE m.faction_id=? ORDER BY m.role,m.player_id""",
                (f["id"],)).fetchall()
            return 200, {"faction":dict(f),"members":[dict(x) for x in members]}
        if method == "POST" and path == "/v1/invitations":
            if not actor["faction_id"]:
                raise ApiError(403, "Not in a Faction")
            role = self.execute("SELECT role FROM memberships WHERE player_id=? AND faction_id=?",
                                (actor["id"],actor["faction_id"])).fetchone()
            if role is None or role["role"] != "leader":
                raise ApiError(403, "Only the Faction leader may invite")
            target = str(data.get("player_id", ""))
            recipient = self.execute("SELECT faction_id FROM players WHERE id=?", (target,)).fetchone()
            if recipient is None or recipient["faction_id"] or target == actor["id"]:
                raise ApiError(409, "Target unavailable")
            existing = self.execute("""SELECT id FROM invitations WHERE target_player=? AND faction_id=?
                                      AND status='pending'""", (target,actor["faction_id"])).fetchone()
            if existing:
                raise ApiError(409, "Invite already pending")
            invitation_id = secrets.token_hex(12)
            with self.db:
                self.execute("""INSERT INTO invitations(id,faction_id,target_player,inviter_id,status)
                                VALUES(?,?,?,?,'pending')""",
                             (invitation_id,actor["faction_id"],target,actor["id"]))
            return 201, {"invitation_id":invitation_id}
        if method == "GET" and path == "/v1/invitations":
            rows = self.execute("""SELECT i.id,i.faction_id,f.name AS faction_name
                FROM invitations i JOIN factions f ON f.id=i.faction_id
                WHERE i.target_player=? AND i.status='pending'""", (actor["id"],)).fetchall()
            return 200, {"invitations":[dict(x) for x in rows]}
        if method == "POST" and path.startswith("/v1/invitations/") and path.endswith("/accept"):
            invite_id = path.split("/")[3]
            with self.db:
                invitation = self.execute("""SELECT faction_id FROM invitations WHERE id=?
                    AND target_player=? AND status='pending'""", (invite_id,actor["id"])).fetchone()
                if invitation is None:
                    raise ApiError(404, "Invitation not found")
                if self.execute("SELECT faction_id FROM players WHERE id=?",
                                (actor["id"],)).fetchone()["faction_id"]:
                    raise ApiError(409, "Already in a Faction")
                self.execute("INSERT INTO memberships(faction_id,player_id,role) VALUES(?,?,'member')",
                             (invitation["faction_id"],actor["id"]))
                self.execute("UPDATE players SET faction_id=? WHERE id=?",
                             (invitation["faction_id"],actor["id"]))
                self.execute("UPDATE invitations SET status='accepted' WHERE id=?", (invite_id,))
                self.execute("UPDATE invitations SET status='declined' WHERE target_player=? AND status='pending'",
                             (actor["id"],))
            return 200, {"faction_id":invitation["faction_id"]}
        if path == "/v1/war" and method == "GET":
            if not actor["faction_id"]:
                raise ApiError(403, "Faction membership required")
            war = self.execute("SELECT * FROM wars WHERE faction_id=? ORDER BY CASE status WHEN 'active' THEN 0 ELSE 1 END, rowid DESC LIMIT 1", (actor["faction_id"],)).fetchone()
            if war is None:
                return 200, {"war":None,"attacks":[],"contributions":[]}
            attacks = self.execute("SELECT a.player_id,p.display_name,a.strategy,a.defense,a.our_points,a.enemy_points FROM war_attacks a JOIN players p ON p.id=a.player_id WHERE a.war_id=? ORDER BY a.id", (war["id"],)).fetchall()
            contributions = self.execute("SELECT p.id AS player_id,p.display_name,COUNT(a.id) AS attacks,COALESCE(SUM(a.our_points),0) AS contribution FROM memberships m JOIN players p ON p.id=m.player_id LEFT JOIN war_attacks a ON a.player_id=p.id AND a.war_id=? WHERE m.faction_id=? GROUP BY p.id ORDER BY contribution DESC", (war["id"],actor["faction_id"])).fetchall()
            defense = ("watchful","fortified","mobile")[war["rounds"] % 3] if war["status"] == "active" else ""
            return 200, {"war":dict(war),"defense":defense,"attacks":[dict(a) for a in attacks],"contributions":[dict(x) for x in contributions]}
        if path == "/v1/war/start" and method == "POST":
            if not actor["faction_id"]:
                raise ApiError(403,"Faction membership required")
            role = self.execute("SELECT role FROM memberships WHERE player_id=?", (actor["id"],)).fetchone()
            if role is None or role["role"] != "leader":
                raise ApiError(403,"Only leaders can start wars")
            if self.execute("SELECT id FROM wars WHERE faction_id=? AND status='active'", (actor["faction_id"],)).fetchone():
                raise ApiError(409,"War already active")
            war_id = secrets.token_hex(12)
            with self.db:
                self.execute("INSERT INTO wars(id,faction_id,opponent_name,status) VALUES(?,?,'Iron Serpents','active')", (war_id,actor["faction_id"]))
            return 201, {"war_id":war_id,"status":"active"}
        if path == "/v1/war/attack" and method == "POST":
            if not actor["faction_id"]:
                raise ApiError(403,"Faction membership required")
            strategy = data.get("strategy")
            if strategy not in ("muscle","convoy","intel"):
                raise ApiError(400,"Unknown strategy")
            war = self.execute("SELECT * FROM wars WHERE faction_id=? AND status='active'", (actor["faction_id"],)).fetchone()
            if war is None:
                raise ApiError(409,"No active war")
            own_attacks = self.execute("SELECT COUNT(*) FROM war_attacks WHERE war_id=? AND player_id=?", (war["id"],actor["id"])).fetchone()[0]
            if own_attacks >= 3:
                raise ApiError(409,"Member attack limit reached")
            if war["rounds"] >= 6:
                raise ApiError(409,"War complete")
            defense = ("watchful","fortified","mobile")[war["rounds"] % 3]
            counter = {"muscle":"watchful","convoy":"fortified","intel":"mobile"}[strategy]
            our = 100 + (40 if counter == defense else -10)
            enemy = 105 + (war["rounds"] % 2) * 9
            total_our, total_enemy = war["our_score"] + our, war["their_score"] + enemy
            rounds = war["rounds"] + 1
            status = "complete" if rounds == 6 else "active"
            result = ("VICTORY" if total_our > total_enemy else "DEFEAT") if status == "complete" else ""
            with self.db:
                self.execute("INSERT INTO war_attacks(war_id,player_id,strategy,defense,our_points,enemy_points) VALUES(?,?,?,?,?,?)", (war["id"],actor["id"],strategy,defense,our,enemy))
                self.execute("UPDATE wars SET our_score=?,their_score=?,rounds=?,status=?,result=? WHERE id=?", (total_our,total_enemy,rounds,status,result,war["id"]))
            return 200, {"war_id":war["id"],"round":rounds,"strategy":strategy,"defense":defense,"our_points":our,"enemy_points":enemy,"countered":counter==defense,"status":status,"result":result}
        if method == "GET" and path == "/v1/pvp/trophies":
            if not actor["faction_id"]:
                raise ApiError(403,"Faction membership required")
            return 200, rivalries.trophy_case(self,actor["faction_id"])
        if method == "GET" and path == "/v1/pvp/history":
            if not actor["faction_id"]:
                raise ApiError(403,"Faction membership required")
            return 200, rivalries.rivalry_history(self,actor["faction_id"])
        if method == "GET" and path == "/v1/seasons/history":
            if not actor["faction_id"]:
                raise ApiError(403, "Faction membership required")
            return 200, seasons.history(self, actor["faction_id"])
        if method == "GET" and path == "/v1/seasons/leaderboard":
            if not actor["faction_id"]:
                raise ApiError(403, "Faction membership required")
            return 200, seasons.leaderboard(self, actor["faction_id"])
        challenge_result = challenges.route(self, method, path, data, actor)
        if challenge_result is not None:
            return challenge_result
        profile_result = profiles.route(self, method, path, data, actor)
        if profile_result is not None:
            return profile_result
        pvp_result = pvp.route(self, method, path, data, actor)
        if pvp_result is not None:
            return pvp_result
        raise ApiError(404, "Unknown endpoint")


def handler_factory(store):
    sensitive_limit = RateLimiter(limit=8,window=60)
    request_limit = RateLimiter(limit=120,window=60)
    class Handler(BaseHTTPRequestHandler):
        def send_json(self, status, payload):
            body = json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        def dispatch(self):
            try:
                client_ip = self.client_address[0]
                if not request_limit.allow(client_ip):
                    raise ApiError(429, "Request rate limit exceeded")
                if self.command == "POST" and self.path in ("/v1/players", "/v1/recover"):
                    if not sensitive_limit.allow(client_ip):
                        raise ApiError(429, "Account request limit exceeded")
                # Reject ambiguous HTTP framing instead of treating an unread body
                # as a fresh request on a persistent connection.
                lengths = self.headers.get_all("Content-Length", [])
                if self.headers.get("Transfer-Encoding") is not None or len(lengths) > 1:
                    self.close_connection = True
                    raise ApiError(400, "Unsupported request framing")
                if self.command == "POST" and not lengths:
                    self.close_connection = True
                    raise ApiError(411, "Content-Length required")
                try:
                    size = int(lengths[0]) if lengths else 0
                except ValueError:
                    self.close_connection = True
                    raise ApiError(400, "Invalid Content-Length")
                if size < 0 or size > 16384:
                    self.close_connection = True
                    raise ApiError(413, "Request too large")
                raw = self.rfile.read(size)
                if len(raw) != size:
                    self.close_connection = True
                    raise ApiError(400, "Incomplete request body")
                data = json.loads(raw) if size else {}
                if not isinstance(data, dict):
                    raise ApiError(400, "JSON object required")
                header = self.headers.get("Authorization", "")
                token = header[7:] if header.startswith("Bearer ") else ""
                with store.lock:
                    status, payload = store.call(self.command,self.path,data,token)
                self.send_json(status,payload)
            except ApiError as exc:
                self.send_json(exc.status,{"error":exc.message})
            except (ValueError,UnicodeDecodeError,json.JSONDecodeError):
                self.send_json(400,{"error":"Invalid request"})
        def do_GET(self): self.dispatch()
        def do_POST(self): self.dispatch()
        def log_message(self, *_args): pass
    return Handler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db",default="server/data.sqlite")
    parser.add_argument("--host",default="127.0.0.1")
    parser.add_argument("--port",type=int,default=8765)
    args = parser.parse_args()
    store = Store(args.db)
    httpd = ThreadingHTTPServer((args.host,args.port),handler_factory(store))
    httpd.timeout = 10
    httpd.serve_forever()


if __name__ == "__main__":
    main()
