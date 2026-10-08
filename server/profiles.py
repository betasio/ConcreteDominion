"""Server-side cosmetic identity and read-only public profiles."""
EMBLEMS = ("crown","serpent","shield","wolf")
BANNERS = ("obsidian","crimson","gold","steel")
PROFILE_SCHEMA = """
CREATE TABLE IF NOT EXISTS faction_identity(
 faction_id TEXT PRIMARY KEY REFERENCES factions(id),
 emblem TEXT NOT NULL DEFAULT 'shield',
 banner TEXT NOT NULL DEFAULT 'obsidian'
);
CREATE TABLE IF NOT EXISTS player_identity(
 player_id TEXT PRIMARY KEY REFERENCES players(id),
 featured_badge TEXT NOT NULL DEFAULT ''
);
"""

def route(store, method, path, data, actor):
    from server.app import ApiError
    if not path.startswith("/v1/profiles/"):
        return None
    if method == "POST" and path == "/v1/profiles/faction":
        fid = actor["faction_id"]
        leader = store.execute("SELECT 1 FROM factions WHERE id=? AND leader_id=?", (fid,actor["id"])).fetchone()
        if not fid or not leader:
            raise ApiError(403,"Only your Faction leader may edit identity")
        emblem,banner = data.get("emblem"),data.get("banner")
        if emblem not in EMBLEMS or banner not in BANNERS:
            raise ApiError(400,"Invalid emblem or banner")
        with store.db:
            store.execute("""INSERT INTO faction_identity(faction_id,emblem,banner) VALUES(?,?,?)
                ON CONFLICT(faction_id) DO UPDATE SET emblem=excluded.emblem,banner=excluded.banner""",
                (fid,emblem,banner))
        return 200, {"faction_id":fid,"emblem":emblem,"banner":banner}
    if method == "POST" and path == "/v1/profiles/badge":
        badge = data.get("badge")
        if not isinstance(badge,str) or badge not in ("","CHAMPION","RUNNER_UP","PODIUM","VETERAN"):
            raise ApiError(400,"Invalid badge")
        if badge:
            if not actor["faction_id"] or not store.execute(
                """SELECT 1 FROM season_awards WHERE faction_id=? AND badge=? LIMIT 1""",
                (actor["faction_id"],badge)
            ).fetchone():
                raise ApiError(403,"Badge not earned by your current Faction")
        with store.db:
            store.execute("""INSERT INTO player_identity(player_id,featured_badge) VALUES(?,?)
                ON CONFLICT(player_id) DO UPDATE SET featured_badge=excluded.featured_badge""",
                (actor["id"],badge))
        return 200, {"featured_badge":badge}
    if method == "GET" and path.startswith("/v1/profiles/faction/"):
        fid = path[len("/v1/profiles/faction/"):]
        row = store.execute("""SELECT f.id,f.name,f.tag,
            COALESCE(i.emblem,'shield') AS emblem,COALESCE(i.banner,'obsidian') AS banner
            FROM factions f LEFT JOIN faction_identity i ON i.faction_id=f.id
            WHERE f.id=?""",(fid,)).fetchone()
        if row is None:
            raise ApiError(404,"Faction not found")
        achievements = store.execute(
            """SELECT season_id,rank,points,badge FROM season_awards
            WHERE faction_id=? ORDER BY season_id DESC LIMIT 20""",(fid,)
        ).fetchall()
        return 200, {"faction":dict(row),"achievements":[dict(x) for x in achievements],"cosmetic_only":True}
    if method == "GET" and path.startswith("/v1/profiles/player/"):
        pid = path[len("/v1/profiles/player/"):]
        row = store.execute("""SELECT p.id,p.display_name,p.faction_id,
            COALESCE(i.featured_badge,'') AS featured_badge FROM players p
            LEFT JOIN player_identity i ON i.player_id=p.id WHERE p.id=?""",(pid,)).fetchone()
        if row is None:
            raise ApiError(404,"Player not found")
        profile = dict(row)
        if profile["featured_badge"] and not store.execute(
            "SELECT 1 FROM season_awards WHERE faction_id=? AND badge=?",
            (profile["faction_id"],profile["featured_badge"])
        ).fetchone():
            profile["featured_badge"] = ""
        return 200, {"player":profile,"cosmetic_only":True}
    raise ApiError(404,"Unknown profile endpoint")
