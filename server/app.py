"""ConcreteDominion multiplayer prototype: standard-library HTTP API + SQLite.

Launch: python3 -m server.app --db ./server/data.sqlite --host 127.0.0.1 --port 8765
This is a development server, NOT an internet-ready identity provider.
"""
import argparse
import hashlib
import json
import secrets
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SCHEMA = """
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS players (
  id TEXT PRIMARY KEY, display_name TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE, faction_id TEXT
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
"""

class ApiError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message

class Store:
    def __init__(self, path):
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.db.executescript(SCHEMA)
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
            with self.db:
                self.execute("INSERT INTO players(id,display_name,token_hash) VALUES(?,?,?)",
                             (player_id,name,hashlib.sha256(session.encode()).hexdigest()))
            return 201, {"player_id":player_id,"session_token":session}
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
        raise ApiError(404, "Unknown endpoint")


def handler_factory(store):
    class Handler(BaseHTTPRequestHandler):
        def send_json(self, status, payload):
            body = json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        def dispatch(self):
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if size < 0 or size > 16384:
                    raise ApiError(413, "Request too large")
                data = json.loads(self.rfile.read(size)) if size else {}
                if not isinstance(data, dict):
                    raise ApiError(400, "JSON object required")
                header = self.headers.get("Authorization", "")
                token = header[7:] if header.startswith("Bearer ") else ""
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
    ThreadingHTTPServer((args.host,args.port),handler_factory(store)).serve_forever()


if __name__ == "__main__":
    main()
