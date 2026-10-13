"""Private-playtest city: stable estates and server-clock landmark campaigns.

Equal command budgets; no client power, premium boosts or offline-save inputs.
Campaigns are independent of the matched-faction war economy.
"""
import time
from server import pvp

DAY = 86400
PERIOD = 7 * DAY
WINDOW = 2 * 3600
COOLDOWN = 300
MEMBERS = 6
ORDERS = 3
SITES = {
    'exchange': {'name': 'Underground Exchange', 'unlock_day': 30, 'cell': [9, 14], 'art': 3},
    'port': {'name': 'Port Authority', 'unlock_day': 45, 'cell': [19, 14], 'art': 4},
    'city_hall': {'name': 'City Hall', 'unlock_day': 60, 'cell': [14, 9], 'art': 2},
}
SCHEMA = """
CREATE TABLE IF NOT EXISTS world_clock(id INTEGER PRIMARY KEY CHECK(id=1), opened_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS world_estates(slot INTEGER PRIMARY KEY AUTOINCREMENT, player_id TEXT NOT NULL UNIQUE REFERENCES players(id));
CREATE TABLE IF NOT EXISTS landmark_campaigns(
 site TEXT NOT NULL, cycle INTEGER NOT NULL, opens_at INTEGER NOT NULL, ends_at INTEGER NOT NULL,
 settled INTEGER NOT NULL DEFAULT 0, winner TEXT NOT NULL DEFAULT '', mayor TEXT NOT NULL DEFAULT '',
 PRIMARY KEY(site,cycle));
CREATE TABLE IF NOT EXISTS landmark_orders(
 player_id TEXT NOT NULL REFERENCES players(id), receipt TEXT NOT NULL, site TEXT NOT NULL, cycle INTEGER NOT NULL,
 faction_id TEXT NOT NULL REFERENCES factions(id), strategy TEXT NOT NULL, points INTEGER NOT NULL,
 created_at INTEGER NOT NULL, PRIMARY KEY(player_id,receipt));
CREATE INDEX IF NOT EXISTS landmark_orders_cycle ON landmark_orders(site,cycle,faction_id);
"""


def initialize(store):
    store.db.executescript(SCHEMA)
    store.execute('INSERT OR IGNORE INTO world_clock VALUES(1,?)', (int(time.time()),))


def _rankings(store, site, cycle):
    return [dict(r) for r in store.execute('''SELECT o.faction_id,f.name,f.tag,SUM(o.points) AS points
        FROM landmark_orders o JOIN factions f ON f.id=o.faction_id
        WHERE site=? AND cycle=? GROUP BY o.faction_id ORDER BY points DESC,o.faction_id''', (site,cycle))]


def settle_due(store):
    with store.lock, store.db:
        for row in store.execute('SELECT * FROM landmark_campaigns WHERE settled=0 AND ends_at<=?', (int(time.time()),)).fetchall():
            ranks = _rankings(store, row['site'], row['cycle'])
            winner = ranks[0]['faction_id'] if ranks and (len(ranks)==1 or ranks[0]['points']>ranks[1]['points']) else ''
            store.execute('UPDATE landmark_campaigns SET settled=1,winner=? WHERE site=? AND cycle=?', (winner,row['site'],row['cycle']))


def _schedule(store, site, now):
    origin = store.execute('SELECT opened_at FROM world_clock WHERE id=1').fetchone()[0]
    first = origin + SITES[site]['unlock_day'] * DAY
    cycle = max(0, (now-first)//PERIOD)
    start = first + cycle * PERIOD
    return cycle, start, start+WINDOW


def snapshot(store, actor):
    now = int(time.time())
    settle_due(store)
    with store.db:
        # Allocation is durable, collision-free, and independent of names/factions.
        store.execute('INSERT OR IGNORE INTO world_estates(player_id) SELECT p.id FROM players p WHERE NOT EXISTS(SELECT 1 FROM world_estates e WHERE e.player_id=p.id) ORDER BY p.rowid')
    own_slot = store.execute('SELECT slot FROM world_estates WHERE player_id=?', (actor['id'],)).fetchone()[0]-1
    sector = own_slot // 24
    players = []
    for row in store.execute('''SELECT e.slot,p.id,p.display_name,p.faction_id,COALESCE(f.tag,'') AS tag
            FROM world_estates e JOIN players p ON p.id=e.player_id LEFT JOIN factions f ON f.id=p.faction_id
            WHERE e.slot BETWEEN ? AND ? ORDER BY e.slot''', (sector*24+1,sector*24+24)):
        item = dict(row)
        item['relation'] = 'self' if row['id']==actor['id'] else ('ally' if actor['faction_id'] and row['faction_id']==actor['faction_id'] else 'other')
        players.append(item)
    landmarks = []
    for site, config in SITES.items():
        cycle, start, end = _schedule(store,site,now)
        phase = 'protected' if now < start else ('contested' if now < end else 'peace')
        last = store.execute('SELECT * FROM landmark_campaigns WHERE site=? AND settled=1 ORDER BY cycle DESC LIMIT 1', (site,)).fetchone()
        rows = store.execute('SELECT * FROM landmark_orders WHERE site=? AND cycle=? AND player_id=?', (site,cycle,actor['id'])).fetchall()
        participant_count = store.execute('SELECT COUNT(DISTINCT player_id) FROM landmark_orders WHERE site=? AND cycle=? AND faction_id=?', (site,cycle,actor['faction_id'])).fetchone()[0]
        remaining = max(0, ORDERS-len(rows))
        next_order = max([r['created_at']+COOLDOWN for r in rows], default=0)
        mayor = store.execute('SELECT display_name FROM players WHERE id=?', (last['mayor'],)).fetchone() if last and last['mayor'] else None
        owner = store.execute('SELECT name,tag FROM factions WHERE id=?', (last['winner'],)).fetchone() if last and last['winner'] else None
        defense = ('muscle','convoy','intel')[(cycle+config['unlock_day'])%3]
        blocker = ''
        if phase != 'contested': blocker = 'Protected until the next contest window.'
        elif not actor['faction_id']: blocker = 'Join a faction to contest landmarks.'
        elif rows and rows[0]['faction_id'] != actor['faction_id']: blocker = 'Your orders are committed to another faction this round.'
        elif remaining == 0: blocker = 'All three orders used this round.'
        elif not rows and participant_count >= MEMBERS: blocker = 'Your faction has six commanders committed this round.'
        elif now < next_order: blocker = 'Next order available in %ds.' % (next_order-now)
        landmarks.append(dict(config, id=site, cycle=cycle, phase=phase, opens_at=start if now<end else start+PERIOD,
            ends_at=end, owner_id=last['winner'] if last else '', owner_name=owner['name'] if owner else 'Unoccupied',
            mayor=mayor[0] if mayor else '', orders_left=remaining, next_order_at=next_order,
            defense=defense, blocker=blocker, rankings=_rankings(store,site,cycle),
            can_appoint=bool(site=='city_hall' and phase!='contested' and last and last['winner'] and last['winner']==actor['faction_id'] and store.execute('SELECT 1 FROM factions WHERE id=? AND leader_id=?',(actor['faction_id'],actor['id'])).fetchone())))
    return {'server_time':now,'opened_at':store.execute('SELECT opened_at FROM world_clock').fetchone()[0],
            'faction_members':[dict(m) for m in store.execute('SELECT p.id AS player_id,p.display_name FROM players p JOIN memberships m ON m.player_id=p.id WHERE m.faction_id=? ORDER BY p.display_name',(actor['faction_id'],))],
            'sector':sector,'players':players,'landmarks':landmarks,'member_cap':MEMBERS,'orders_per_member':ORDERS}


def route(store, method, path, data, actor):
    if not path.startswith('/v1/world'): return None
    from server.app import ApiError
    with store.lock:
        if method=='GET' and path=='/v1/world': return 200,snapshot(store,actor)
        if method=='POST' and path=='/v1/world/order':
            fid = pvp._member_faction(store,actor)
            site, strategy, receipt = data.get('site'),data.get('strategy'),data.get('request_id')
            if not isinstance(site,str) or site not in SITES or strategy not in ('muscle','convoy','intel'):
                raise ApiError(400,'Choose a landmark and valid strategy')
            if not isinstance(receipt,str) or len(receipt)!=32 or any(c not in '0123456789abcdef' for c in receipt):
                raise ApiError(400,'32-character request_id required')
            prior = store.execute('SELECT * FROM landmark_orders WHERE player_id=? AND receipt=?', (actor['id'],receipt)).fetchone()
            if prior:
                if prior['site']!=site or prior['strategy']!=strategy or prior['faction_id']!=fid:
                    raise ApiError(409,'Receipt already used with different orders')
                return 200,snapshot(store,actor)
            state = snapshot(store,actor)
            info = next(x for x in state['landmarks'] if x['id']==site)
            if info['blocker']: raise ApiError(409,info['blocker'])
            # Equal-strength simultaneous faction contest. The published garrison
            # favors tactical counters; money, local power and purchases do not enter.
            counter = {'muscle':'intel','convoy':'muscle','intel':'convoy'}[info['defense']]
            points = 150 if strategy==counter else (100 if strategy==info['defense'] else 75)
            cycle,start,end = _schedule(store,site,state['server_time'])
            with store.db:
                store.execute('INSERT OR IGNORE INTO landmark_campaigns(site,cycle,opens_at,ends_at) VALUES(?,?,?,?)', (site,cycle,start,end))
                store.execute('INSERT INTO landmark_orders VALUES(?,?,?,?,?,?,?,?)', (actor['id'],receipt,site,cycle,fid,strategy,points,state['server_time']))
            result = snapshot(store,actor)
            result['order_result'] = {'points':points,'strategy':strategy,'defense':info['defense']}
            return 200,result
        if method=='POST' and path=='/v1/world/mayor':
            fid = pvp._member_faction(store,actor)
            state = snapshot(store,actor)
            hall = next(x for x in state['landmarks'] if x['id']=='city_hall')
            if not hall['can_appoint']: raise ApiError(403,'Only the winning faction leader can appoint a mayor during peace')
            candidate = data.get('player_id')
            if not isinstance(candidate,str) or not store.execute('SELECT 1 FROM memberships WHERE faction_id=? AND player_id=?',(fid,candidate)).fetchone():
                raise ApiError(400,'Choose a member of your faction')
            with store.db:
                store.execute('UPDATE landmark_campaigns SET mayor=? WHERE site=? AND cycle=(SELECT MAX(cycle) FROM landmark_campaigns WHERE site=? AND settled=1)',(candidate,'city_hall','city_hall'))
            return 200,snapshot(store,actor)
    raise ApiError(404,'Unknown world endpoint')
