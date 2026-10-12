"""Timed faction rallies. Only authenticated members join; departure is durable.

Uses the existing matched-faction combat rules and limits. Each joined member
contributes one attack, never an invented bot. Hall level is earned from server
combat records, independently of editable offline estate saves.
"""
import hashlib
import secrets
import time
from server import pvp, progression

SCHEMA = """
CREATE TABLE IF NOT EXISTS rallies (
 id TEXT PRIMARY KEY, request_id TEXT NOT NULL, leader_id TEXT NOT NULL,
 faction_id TEXT NOT NULL, opponent_id TEXT NOT NULL, match_id TEXT NOT NULL,
 strategy TEXT NOT NULL, preparation INTEGER NOT NULL, departs_at INTEGER NOT NULL,
 capacity INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'preparing',
 UNIQUE(leader_id,request_id)
);
CREATE TABLE IF NOT EXISTS rally_members (
 rally_id TEXT NOT NULL, player_id TEXT NOT NULL, outcome TEXT NOT NULL DEFAULT '',
 PRIMARY KEY(rally_id,player_id)
);
"""

def hall_level(store, fid):
    return progression.hall_level(store, fid)


def settle_due(store):
    from server.app import ApiError
    now = int(time.time())
    with store.lock:
        rallies = store.execute("SELECT * FROM rallies WHERE status='preparing' AND departs_at<=?", (now,)).fetchall()
        for rally in rallies:
            war = pvp._active_match(store, rally['faction_id'])
            if not war or war['id'] != rally['match_id']:
                with store.db:
                    store.execute("UPDATE rallies SET status='cancelled' WHERE id=?", (rally['id'],))
                continue
            members = store.execute("SELECT * FROM rally_members WHERE rally_id=? ORDER BY player_id", (rally['id'],)).fetchall()
            for member in members:
                if member['outcome']:
                    continue
                actor = store.execute("SELECT * FROM players WHERE id=?", (member['player_id'],)).fetchone()
                result = 'Left faction'
                if actor and actor['faction_id'] == rally['faction_id']:
                    # Stable receipt makes a crash between combat and receipt storage safe.
                    receipt = hashlib.sha256((rally['id']+actor['id']).encode()).hexdigest()[:32]
                    try:
                        _, attack = pvp.route(store, 'POST', '/v1/pvp/attack',
                            {'request_id':receipt, 'strategy':rally['strategy']}, actor)
                        result = str(attack['points'])+' points'
                    except ApiError as exc:
                        result = exc.message
                with store.db:
                    store.execute("UPDATE rally_members SET outcome=? WHERE rally_id=? AND player_id=?",
                                  (result,rally['id'],member['player_id']))
            with store.db:
                store.execute("UPDATE rallies SET status='departed' WHERE id=?", (rally['id'],))


def snapshot(store, fid):
    rows = store.execute("""SELECT r.*, f.name AS faction_name FROM rallies r JOIN factions f ON f.id=r.faction_id
        WHERE r.faction_id=? OR (r.opponent_id=? AND r.status='preparing')
        ORDER BY r.rowid DESC LIMIT 20""", (fid,fid)).fetchall()
    result = []
    for row in rows:
        rally = dict(row)
        rally.pop('request_id')
        rally['incoming'] = row['opponent_id'] == fid
        rally['seconds_remaining'] = max(0,row['departs_at']-int(time.time()))
        rally['members'] = [dict(m) for m in store.execute("""SELECT m.player_id,p.display_name,m.outcome
            FROM rally_members m JOIN players p ON p.id=m.player_id WHERE rally_id=?""", (row['id'],)).fetchall()]
        result.append(rally)
    return {'rallies':result,'hall_level':hall_level(store,fid),'capacity':3+hall_level(store,fid)}


def route(store, method, path, data, actor):
    if not path.startswith('/v1/rallies'):
        return None
    from server.app import ApiError
    fid = pvp._member_faction(store,actor)
    settle_due(store)
    if method == 'GET' and path == '/v1/rallies':
        return 200,snapshot(store,fid)
    if method == 'POST' and path == '/v1/rallies':
        request = data.get('request_id')
        strategy = data.get('strategy')
        preparation = data.get('preparation')
        if not isinstance(request,str) or len(request)!=32 or any(c not in '0123456789abcdef' for c in request):
            raise ApiError(400,'32-character request_id required')
        if strategy not in ('muscle','convoy','intel') or type(preparation) is not int or preparation not in (60,180,300):
            raise ApiError(400,'Choose a strategy and 60, 180 or 300 seconds preparation')
        previous = store.execute('SELECT * FROM rallies WHERE leader_id=? AND request_id=?',(actor['id'],request)).fetchone()
        if previous:
            if previous['strategy']!=strategy or previous['preparation']!=preparation or previous['faction_id']!=fid:
                raise ApiError(409,'Request ID reused with different parameters')
            return 200,snapshot(store,fid)
        war = pvp._active_match(store,fid)
        if not war:
            raise ApiError(409,'Queue against another faction first')
        if store.execute("SELECT 1 FROM rallies WHERE faction_id=? AND status='preparing'",(fid,)).fetchone():
            raise ApiError(409,'Join the rally already preparing')
        _eligible(store,actor,war)
        rid = secrets.token_hex(12)
        opponent = war['faction_b'] if war['faction_a']==fid else war['faction_a']
        with store.db:
            store.execute('''INSERT INTO rallies(id,request_id,leader_id,faction_id,opponent_id,match_id,strategy,preparation,departs_at,capacity)
                VALUES(?,?,?,?,?,?,?,?,?,?)''',(rid,request,actor['id'],fid,opponent,war['id'],strategy,preparation,int(time.time())+preparation,3+hall_level(store,fid)))
            store.execute('INSERT INTO rally_members(rally_id,player_id) VALUES(?,?)',(rid,actor['id']))
        return 201,snapshot(store,fid)
    parts = path.split('/')
    if method == 'POST' and len(parts)==5 and parts[4] in ('join','cancel'):
        rally = store.execute('SELECT * FROM rallies WHERE id=?',(parts[3],)).fetchone()
        if not rally or rally['faction_id']!=fid:
            raise ApiError(404,'Rally unavailable')
        if rally['status']!='preparing':
            raise ApiError(409,'Rally has already departed or was cancelled')
        if parts[4]=='cancel':
            if rally['leader_id']!=actor['id']:
                raise ApiError(403,'Only the rally leader may cancel')
            with store.db:
                store.execute("UPDATE rallies SET status='cancelled' WHERE id=?",(rally['id'],))
        else:
            if store.execute('SELECT 1 FROM rally_members WHERE rally_id=? AND player_id=?',(rally['id'],actor['id'])).fetchone():
                return 200,snapshot(store,fid)
            war = pvp._active_match(store,fid)
            if not war or war['id']!=rally['match_id']:
                raise ApiError(409,'Match no longer active')
            _eligible(store,actor,war)
            count = store.execute('SELECT COUNT(*) FROM rally_members WHERE rally_id=?',(rally['id'],)).fetchone()[0]
            remaining = 6-war['rounds_a' if war['faction_a']==fid else 'rounds_b']
            if count>=min(rally['capacity'],remaining):
                raise ApiError(409,'Rally capacity reached')
            with store.db:
                store.execute('INSERT INTO rally_members(rally_id,player_id) VALUES(?,?)',(rally['id'],actor['id']))
        return 200,snapshot(store,fid)
    raise ApiError(404,'Unknown rally endpoint')


def _eligible(store,actor,war):
    from server.app import ApiError
    rounds = war['rounds_a' if war['faction_a']==actor['faction_id'] else 'rounds_b']
    count = store.execute('SELECT COUNT(*) FROM pvp_attacks WHERE match_id=? AND player_id=?',(war['id'],actor['id'])).fetchone()[0]
    if rounds>=6 or count>=3:
        raise ApiError(409,'No attacks remaining for this match')
