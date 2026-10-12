"""Online war economy. All awards come from settled server combat transactions."""
import time
from server import pvp

DAILY_REWARDS = 3
REWARDS = {'victory': (3000, 3, 2), 'draw': (2500, 2, 2), 'defeat': (2000, 2, 1)}
UPGRADES = {1: (6000, 6, 2), 2: (12000, 12, 4)}
SCHEMA = """
CREATE TABLE IF NOT EXISTS faction_progression (
 faction_id TEXT PRIMARY KEY REFERENCES factions(id),
 cash INTEGER NOT NULL DEFAULT 0 CHECK(cash>=0),
 supplies INTEGER NOT NULL DEFAULT 0 CHECK(supplies>=0),
 intel INTEGER NOT NULL DEFAULT 0 CHECK(intel>=0),
 hall_level INTEGER NOT NULL DEFAULT 1 CHECK(hall_level BETWEEN 1 AND 3)
);
CREATE TABLE IF NOT EXISTS faction_war_rewards (
 match_id TEXT NOT NULL REFERENCES pvp_matches(id), faction_id TEXT NOT NULL,
 day INTEGER NOT NULL, result TEXT NOT NULL, cash INTEGER NOT NULL,
 supplies INTEGER NOT NULL, intel INTEGER NOT NULL,
 PRIMARY KEY(match_id,faction_id)
);
CREATE INDEX IF NOT EXISTS faction_reward_day ON faction_war_rewards(faction_id,day);
CREATE TABLE IF NOT EXISTS player_command_rewards (
 match_id TEXT NOT NULL REFERENCES pvp_matches(id), player_id TEXT NOT NULL REFERENCES players(id),
 day INTEGER NOT NULL, xp INTEGER NOT NULL, PRIMARY KEY(match_id,player_id)
);
CREATE INDEX IF NOT EXISTS player_command_day ON player_command_rewards(player_id,day);
CREATE TABLE IF NOT EXISTS faction_hall_upgrades (
 faction_id TEXT NOT NULL, level INTEGER NOT NULL, player_id TEXT NOT NULL,
 cash INTEGER NOT NULL, supplies INTEGER NOT NULL, intel INTEGER NOT NULL,
 created_at INTEGER NOT NULL, PRIMARY KEY(faction_id,level)
);
"""


def initialize(store):
    store.db.executescript(SCHEMA)
    # Preserve the useful capacity of previously earned online halls. Historical
    # matches do not mint money; only settlements after this migration do.
    store.execute("""INSERT OR IGNORE INTO faction_progression(faction_id,hall_level)
        SELECT f.id, MIN(3,1+(SELECT COUNT(*) FROM pvp_matches m WHERE m.winner_id=f.id))
        FROM factions f""")


def _ensure(store, fid):
    store.execute('INSERT OR IGNORE INTO faction_progression(faction_id) VALUES(?)', (fid,))


def hall_level(store, fid):
    row = store.execute('SELECT hall_level FROM faction_progression WHERE faction_id=?', (fid,)).fetchone()
    return row['hall_level'] if row else 1


def award_match(store, match, winner):
    """Called INSIDE the final attack transaction; never independently commits."""
    day = int(time.time()) // 86400
    for fid in (match['faction_a'], match['faction_b']):
        _ensure(store, fid)
        result = 'victory' if winner == fid else ('draw' if not winner else 'defeat')
        count = store.execute('SELECT COUNT(*) FROM faction_war_rewards WHERE faction_id=? AND day=? AND cash>0',
                              (fid, day)).fetchone()[0]
        cash, supplies, intel = REWARDS[result] if count < DAILY_REWARDS else (0, 0, 0)
        inserted = store.execute('''INSERT OR IGNORE INTO faction_war_rewards
            (match_id,faction_id,day,result,cash,supplies,intel) VALUES(?,?,?,?,?,?,?)''',
            (match['id'], fid, day, result, cash, supplies, intel)).rowcount
        if inserted:
            store.execute('UPDATE faction_progression SET cash=cash+?,supplies=supplies+?,intel=intel+? WHERE faction_id=?',
                          (cash, supplies, intel, fid))
    # Rewards follow the contributing account, even if it later changes faction.
    members = store.execute('SELECT player_id,COUNT(*) AS attacks FROM pvp_attacks WHERE match_id=? GROUP BY player_id',
                            (match['id'],)).fetchall()
    for member in members:
        count = store.execute('SELECT COUNT(*) FROM player_command_rewards WHERE player_id=? AND day=? AND xp>0',
                              (member['player_id'], day)).fetchone()[0]
        xp = 25 + 10 * member['attacks'] if count < DAILY_REWARDS else 0
        store.execute('INSERT OR IGNORE INTO player_command_rewards(match_id,player_id,day,xp) VALUES(?,?,?,?)',
                      (match['id'], member['player_id'], day, xp))


def snapshot(store, actor):
    fid = pvp._member_faction(store, actor)
    row = store.execute('SELECT * FROM faction_progression WHERE faction_id=?', (fid,)).fetchone()
    treasury = {key: row[key] if row else 0 for key in ('cash', 'supplies', 'intel')}
    level = row['hall_level'] if row else 1
    cost = dict(zip(('cash', 'supplies', 'intel'), UPGRADES[level])) if level in UPGRADES else {}
    role = store.execute('SELECT role FROM memberships WHERE faction_id=? AND player_id=?', (fid, actor['id'])).fetchone()['role']
    if not cost:
        blocker = 'Rally Hall is at maximum capacity.'
    elif role != 'leader':
        blocker = 'Your faction leader can upgrade the Rally Hall.'
    elif any(treasury[k] < v for k, v in cost.items()):
        blocker = 'Complete faction matches to fill the war chest.'
    else:
        blocker = ''
    day = int(time.time()) // 86400
    rewards_today = store.execute('SELECT COUNT(*) FROM faction_war_rewards WHERE faction_id=? AND day=? AND cash>0', (fid, day)).fetchone()[0]
    own_today = store.execute('SELECT COUNT(*) FROM player_command_rewards WHERE player_id=? AND day=? AND xp>0', (actor['id'], day)).fetchone()[0]
    xp = store.execute('SELECT COALESCE(SUM(xp),0) FROM player_command_rewards WHERE player_id=?', (actor['id'],)).fetchone()[0]
    history = store.execute('SELECT match_id,result,cash,supplies,intel FROM faction_war_rewards WHERE faction_id=? ORDER BY rowid DESC LIMIT 5', (fid,)).fetchall()
    return {'faction_id': fid, 'treasury': treasury, 'hall_level': level, 'capacity': 3+level,
            'upgrade_cost': cost, 'upgrade_blocker': blocker, 'can_upgrade': not blocker,
            'command_xp': xp, 'command_rank': 1+xp//150, 'rank_xp': xp % 150, 'rank_xp_required': 150,
            'rewards_remaining': max(0, DAILY_REWARDS-rewards_today),
            'command_rewards_remaining': max(0, DAILY_REWARDS-own_today),
            'resets_at': (day+1)*86400, 'recent_rewards': [dict(r) for r in history]}


def route(store, method, path, data, actor):
    if path not in ('/v1/progression', '/v1/progression/hall'):
        return None
    from server.app import ApiError
    with store.lock:
        fid = pvp._member_faction(store, actor)
        if method == 'GET' and path == '/v1/progression':
            return 200, snapshot(store, actor)
        if method == 'POST' and path == '/v1/progression/hall':
            role = store.execute('SELECT role FROM memberships WHERE faction_id=? AND player_id=?', (fid, actor['id'])).fetchone()['role']
            if role != 'leader':
                raise ApiError(403, 'Only your faction leader can spend the war chest')
            expected = data.get('expected_level')
            if type(expected) is not int or expected not in UPGRADES:
                raise ApiError(400, 'Choose a valid Rally Hall level to upgrade')
            with store.db:
                _ensure(store, fid)
                state = snapshot(store, actor)
                # Compare-and-swap prevents a retry from buying the next level.
                if state['hall_level'] != expected:
                    raise ApiError(409, 'Rally Hall changed. Refresh before upgrading again.')
                if not state['can_upgrade']:
                    raise ApiError(409, state['upgrade_blocker'])
                cash, supplies, intel = UPGRADES[expected]
                store.execute('UPDATE faction_progression SET hall_level=hall_level+1,cash=cash-?,supplies=supplies-?,intel=intel-? WHERE faction_id=?',
                              (cash, supplies, intel, fid))
                store.execute('INSERT INTO faction_hall_upgrades VALUES(?,?,?,?,?,?,?)',
                              (fid, expected+1, actor['id'], cash, supplies, intel, int(time.time())))
            return 200, snapshot(store, actor)
    raise ApiError(404, 'Unknown progression endpoint')
