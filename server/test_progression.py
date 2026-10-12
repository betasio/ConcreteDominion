"""Earned online progression: settlement, budgets, upgrade races and restarts."""
import tempfile
import time
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
from server.app import Store, ApiError
from server import progression, rallies


class ProgressionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = self.tmp.name+'/game.sqlite'
        self.api = Store(self.path)
        self.players = []
        self.factions = []
        for team in ('North', 'South'):
            group = []
            for role in ('Boss', 'Wing', 'Idle'):
                group.append(self.api.call('POST', '/v1/players', {'display_name':team+role}, '')[1])
            self.players.extend(group)
            faction = self.call(len(self.players)-3, 'POST', '/v1/factions', {'name':team+' Family', 'tag':team[:3]})
            self.factions.append(faction['faction_id'])
            for offset in (1, 2):
                invite = self.call(len(self.players)-3, 'POST', '/v1/invitations', {'player_id':group[offset]['player_id']})
                self.call(len(self.players)-3+offset, 'POST', '/v1/invitations/'+invite['invitation_id']+'/accept')

    def tearDown(self):
        self.api.db.close()
        self.tmp.cleanup()

    def call(self, player, method, path, data=None):
        with self.api.lock:
            return self.api.call(method, path, data or {}, self.players[player]['session_token'])[1]

    def match(self, finish=True, draw=False):
        for leader in (0, 3):
            self.call(leader, 'POST', '/v1/pvp/queue')
            with self.api.db:
                self.api.execute('UPDATE pvp_queue SET queued_at=?', (int(time.time()),))
        mid = self.api.execute("SELECT id FROM pvp_matches WHERE status='active'").fetchone()['id']
        with self.api.db:
            self.api.execute('UPDATE pvp_matches SET created_at=? WHERE id=?', (int(time.time()), mid))
        if finish:
            for player in (0, 1, 3, 4):
                for strategy in ('muscle', 'convoy', 'intel') if player < 3 or draw else ('intel', 'muscle', 'convoy'):
                    self.call(player, 'POST', '/v1/pvp/attack', {'strategy':strategy, 'request_id':uuid.uuid4().hex})
        return mid

    def state(self, player=0):
        return self.call(player, 'GET', '/v1/progression')

    def test_winners_losers_participants_and_replay(self):
        mid = self.match()
        self.assertEqual(self.state()['treasury'], {'cash':3000,'supplies':3,'intel':2})
        self.assertEqual(self.state(3)['treasury']['cash'], 2000)
        self.assertEqual(self.state()['command_xp'], 55)
        self.assertEqual(self.state(2)['command_xp'], 0)
        self.assertEqual(self.state()['hall_level'], 1)  # Upgrades require a choice.
        receipt = self.api.execute('SELECT * FROM pvp_attacks WHERE player_id=?', (self.players[0]['player_id'],)).fetchone()
        replay = self.call(0, 'POST', '/v1/pvp/attack', {'strategy':receipt['strategy'],'request_id':receipt['request_id']})
        self.assertTrue(replay['replayed'])
        with self.api.db:
            progression.award_match(self.api, self.api.execute('SELECT * FROM pvp_matches WHERE id=?',(mid,)).fetchone(), self.factions[0])
        self.assertEqual(self.state()['treasury']['cash'], 3000)
        self.assertEqual(self.state()['command_xp'], 55)
        self.api.db.close()
        self.api = Store(self.path)
        self.assertEqual(self.state()['treasury']['cash'], 3000)

    def test_daily_limits_draws_and_reset(self):
        now = int(time.time())
        with patch('server.progression.time.time', return_value=now):
            for _ in range(4):
                self.match(draw=True)
            self.assertEqual(self.state()['treasury']['cash'], 7500)
            self.assertEqual(self.state()['command_xp'], 165)
            self.assertEqual(self.state()['command_rank'], 2)
            self.assertEqual(self.state()['rewards_remaining'], 0)
            self.assertEqual(self.state()['recent_rewards'][0]['cash'], 0)
        with patch('server.progression.time.time', return_value=now+86400):
            self.assertEqual(self.state()['rewards_remaining'], 3)
            self.match()
            self.assertEqual(self.state()['treasury']['cash'], 10500)
            self.assertEqual(self.state()['command_xp'], 220)

    def test_upgrade_authority_cost_retry_race_and_capacity(self):
        for invalid in (True, '1', 0, 3):
            with self.assertRaises(ApiError):
                self.call(0, 'POST', '/v1/progression/hall', {'expected_level':invalid})
        with self.assertRaises(ApiError):
            self.call(0, 'POST', '/v1/progression/hall', {'expected_level':1})
        for _ in range(2):
            self.match()
        with self.assertRaises(ApiError):
            self.call(1, 'POST', '/v1/progression/hall', {'expected_level':1})
        def upgrade(_):
            try:
                return self.call(0, 'POST', '/v1/progression/hall', {'expected_level':1})['hall_level']
            except ApiError as exc:
                return exc.status
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(upgrade, range(4)))
        self.assertEqual(results.count(2), 1)
        self.assertEqual(results.count(409), 3)
        self.assertEqual(self.state()['treasury'], {'cash':0,'supplies':0,'intel':2})
        self.match(finish=False)
        rally = self.call(0, 'POST', '/v1/rallies', {'strategy':'muscle','preparation':60,'request_id':uuid.uuid4().hex})
        self.assertEqual(rally['capacity'], 5)
        self.assertEqual(rally['rallies'][0]['capacity'], 5)
        self.api.db.close()
        self.api = Store(self.path)
        self.assertEqual(self.state()['hall_level'], 2)
        self.assertEqual(self.state()['treasury']['cash'], 0)
        with self.api.db:
            self.api.execute('UPDATE faction_progression SET cash=12000,supplies=12,intel=4 WHERE faction_id=?', (self.factions[0],))
        self.call(0, 'POST', '/v1/progression/hall', {'expected_level':2})
        self.assertEqual(self.state()['capacity'], 6)
        self.assertEqual(self.state()['treasury'], {'cash':0,'supplies':0,'intel':0})
        self.assertFalse(self.state()['can_upgrade'])
        self.assertEqual(self.call(0, 'GET', '/v1/rallies')['rallies'][0]['capacity'], 5)

    def test_timeouts_do_not_pay_and_inputs_cannot_mint_resources(self):
        mid = self.match(finish=False)
        with self.api.db:
            self.api.execute('UPDATE pvp_matches SET created_at=1 WHERE id=?', (mid,))
        self.call(0, 'GET', '/v1/pvp')
        self.assertEqual(self.state()['treasury']['cash'], 0)
        self.assertEqual(self.state()['command_xp'], 0)
        with self.assertRaises(ApiError):
            self.call(0, 'POST', '/v1/progression', {'cash':999999,'command_xp':99999})
        with self.assertRaises(ApiError):
            self.api.call('GET', '/v1/progression', {}, '')
        solo = self.api.call('POST', '/v1/players', {'display_name':'Solo'}, '')[1]
        with self.assertRaises(ApiError):
            self.api.call('GET', '/v1/progression', {}, solo['session_token'])
        self.assertEqual(self.state()['treasury']['cash'], 0)

    def test_rally_departure_settles_progression_once(self):
        self.match(finish=False)
        # Leave the final attack for a timed rally; no clients need to be online.
        for player, count in ((0,3),(1,3),(3,3),(4,2)):
            for _ in range(count):
                self.call(player, 'POST', '/v1/pvp/attack', {'strategy':'muscle','request_id':uuid.uuid4().hex})
        rally = self.call(4, 'POST', '/v1/rallies', {'strategy':'muscle','preparation':60,'request_id':uuid.uuid4().hex})['rallies'][0]
        with patch('server.rallies.time.time', return_value=rally['departs_at']):
            rallies.settle_due(self.api)
            rallies.settle_due(self.api)
        self.assertEqual(self.state()['treasury']['cash'], 2500)
        self.assertEqual(self.state(4)['command_xp'], 55)
        self.assertEqual(self.api.execute('SELECT COUNT(*) FROM faction_war_rewards').fetchone()[0], 2)

    def test_failed_reward_write_rolls_back_final_attack(self):
        self.match(finish=False)
        for player, count in ((0,3),(1,3),(3,3),(4,2)):
            for _ in range(count):
                self.call(player, 'POST', '/v1/pvp/attack', {'strategy':'muscle','request_id':uuid.uuid4().hex})
        original = progression.award_match
        def fail_after_award(*args):
            original(*args)
            raise RuntimeError('Simulated interruption')
        receipt = {'strategy':'muscle','request_id':uuid.uuid4().hex}
        with patch('server.progression.award_match', side_effect=fail_after_award):
            with self.assertRaises(RuntimeError):
                self.call(4, 'POST', '/v1/pvp/attack', receipt)
        self.assertEqual(self.api.execute('SELECT COUNT(*) FROM pvp_attacks').fetchone()[0], 11)
        self.assertEqual(self.state()['treasury']['cash'], 0)
        self.call(4, 'POST', '/v1/pvp/attack', receipt)
        self.assertEqual(self.state()['treasury']['cash'], 2500)

    def test_legacy_hall_migration_does_not_mint_historical_rewards(self):
        self.match()
        self.match()
        with self.api.db:
            self.api.execute('DELETE FROM faction_progression')
            self.api.execute('DELETE FROM faction_war_rewards')
            self.api.execute('DELETE FROM player_command_rewards')
        self.api.db.close()
        self.api = Store(self.path)
        self.assertEqual(self.state()['hall_level'], 3)
        self.assertEqual(self.state()['capacity'], 6)
        self.assertEqual(self.state()['treasury']['cash'], 0)
        self.assertEqual(self.state()['command_xp'], 0)
