import os
import tempfile
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
from server.app import Store, ApiError
from server import world


class WorldTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.tmp.name,'world.sqlite')
        self.api = Store(self.path)
        self.players = [self.api.call('POST','/v1/players',{'display_name':f'Player {i}'},'')[1] for i in range(9)]
        self.factions = [self.call(i,'POST','/v1/factions',{'name':f'Family {i}','tag':f'F{i}'})['faction_id'] for i in (0,1)]
        for i in range(2,8):
            invite = self.call(0,'POST','/v1/invitations',{'player_id':self.players[i]['player_id']})
            self.call(i,'POST',f"/v1/invitations/{invite['invitation_id']}/accept")
        self.origin = self.api.execute('SELECT opened_at FROM world_clock').fetchone()[0]
        self.now = self.origin + 60*world.DAY
        self.clock = patch('server.world.time.time', side_effect=lambda:self.now)
        self.clock.start()

    def tearDown(self):
        self.clock.stop()
        self.api.db.close()
        self.tmp.cleanup()

    def call(self, index, method='GET', path='/v1/world', data=None):
        with self.api.lock:
            return self.api.call(method,path,data or {},self.players[index]['session_token'])[1]

    def site(self,index=0,site='city_hall'):
        return next(x for x in self.call(index)['landmarks'] if x['id']==site)

    def order(self,index=0,site='city_hall',strategy='intel',receipt=None):
        return self.call(index,'POST','/v1/world/order',{'site':site,'strategy':strategy,'request_id':receipt or uuid.uuid4().hex,'power':9999999,'diamonds':9999999})

    def test_identity_colors_sectors_and_persistent_slots(self):
        data = self.call(0)
        colors = {p['id']:p['relation'] for p in data['players']}
        self.assertEqual(colors[self.players[0]['player_id']],'self')
        self.assertEqual(colors[self.players[2]['player_id']],'ally')
        self.assertEqual(colors[self.players[1]['player_id']],'other')
        self.assertEqual(colors[self.players[8]['player_id']],'other')
        self.assertEqual({p['relation'] for p in self.call(8)['players']},{'self','other'})
        for _ in range(4): self.call(0)
        self.assertEqual(self.api.execute('SELECT MAX(slot) FROM world_estates').fetchone()[0],9)
        self.api.db.close(); self.api=Store(self.path)
        self.assertEqual(self.call(0)['players'],data['players'])
        self.assertEqual(self.api.execute('SELECT opened_at FROM world_clock').fetchone()[0],self.origin)

    def test_unlock_boundaries_and_membership(self):
        for site,config in world.SITES.items():
            self.now=self.origin+config['unlock_day']*world.DAY-1
            self.assertEqual(self.site(site=site)['phase'],'protected')
            with self.assertRaises(ApiError): self.order(site=site)
            self.now+=1
            self.assertEqual(self.site(site=site)['phase'],'contested')
            with self.assertRaises(ApiError) as error: self.order(8,site)
            self.assertEqual(error.exception.status,403)
            self.order(site=site)
            self.now+=world.WINDOW
            self.assertEqual(self.site(site=site)['phase'],'peace')
            with self.assertRaises(ApiError): self.order(site=site)

    def test_receipts_exact_budgets_cooldown_and_no_paid_power(self):
        receipt=uuid.uuid4().hex
        self.assertEqual(self.order(receipt=receipt)['order_result']['points'],150)
        self.order(receipt=receipt)
        self.assertEqual(self.site()['orders_left'],2)
        with self.assertRaises(ApiError): self.order()
        with self.assertRaises(ApiError): self.order(strategy='muscle',receipt=receipt)
        for _ in range(2):
            self.now+=world.COOLDOWN
            self.order()
        self.now+=world.COOLDOWN
        with self.assertRaises(ApiError): self.order()
        self.assertEqual(self.site()['rankings'][0]['points'],450)

    def test_concurrent_faction_cap_and_faction_hopping(self):
        def attack(i):
            try: self.order(i); return 1
            except ApiError: return 0
        with ThreadPoolExecutor(max_workers=7) as pool:
            self.assertEqual(sum(pool.map(attack,[0,2,3,4,5,6,7])),6)
        member = self.api.execute('SELECT player_id FROM landmark_orders LIMIT 1').fetchone()[0]
        index = next(i for i,p in enumerate(self.players) if p['player_id']==member)
        with self.api.db:
            self.api.execute('UPDATE memberships SET faction_id=? WHERE player_id=?',(self.factions[1],member))
            self.api.execute('UPDATE players SET faction_id=? WHERE id=?',(self.factions[1],member))
        self.now+=world.COOLDOWN
        with self.assertRaises(ApiError): self.order(index)

    def test_settlement_mayor_permissions_and_restart(self):
        self.order(0)
        self.order(1,strategy='convoy')
        self.now+=world.WINDOW
        self.api.db.close(); self.api=Store(self.path)
        world.settle_due(self.api); world.settle_due(self.api)
        self.assertEqual(self.site()['owner_id'],self.factions[0])
        member=self.players[2]['player_id']
        for i in (1,2,8):
            with self.assertRaises(ApiError): self.call(i,'POST','/v1/world/mayor',{'player_id':member})
        with self.assertRaises(ApiError): self.call(0,'POST','/v1/world/mayor',{'player_id':self.players[1]['player_id']})
        self.call(0,'POST','/v1/world/mayor',{'player_id':member})
        self.assertEqual(self.site()['mayor'],'Player 2')
        self.now=self.origin+60*world.DAY+world.PERIOD
        self.assertFalse(self.site()['can_appoint'])
        self.order(1)
        self.now+=world.WINDOW
        self.assertEqual(self.site()['owner_id'],self.factions[1])
        self.assertEqual(self.site()['mayor'],'')

    def test_ties_do_not_grant_ownership(self):
        self.order(0); self.order(1)
        self.now+=world.WINDOW
        self.assertEqual(self.site()['owner_id'],'')
        self.assertFalse(self.site()['can_appoint'])

    def test_invalid_payloads_and_auth(self):
        for value in (None,[],{},'bad'):
            with self.assertRaises(ApiError): self.order(site=value)
        with self.assertRaises(ApiError): self.api.call('GET','/v1/world',{},'')
        with self.assertRaises(ApiError): self.order(receipt='invalid')
        self.assertEqual(self.api.execute('SELECT COUNT(*) FROM landmark_orders').fetchone()[0],0)

    def test_premium_ownership_is_private_revocable_and_cannot_boost_contests(self):
        self.assertEqual(self.call(0)['skin_entitlements'], [])
        self.api.execute('INSERT INTO skin_entitlements VALUES(?,?,?,0)',
                         (self.players[0]['player_id'],'crimson','verified-provider-receipt'))
        self.api.db.commit()
        self.assertEqual(self.call(0)['skin_entitlements'], ['crimson'])
        self.assertEqual(self.call(1)['skin_entitlements'], [])
        result = self.call(0,'POST','/v1/world/order',
                           {'site':'city_hall','strategy':'intel','request_id':uuid.uuid4().hex,
                            'skin':'crimson','attack_multiplier':1.1,'skin_entitlements':['emerald']})
        self.assertEqual(result['order_result']['points'], 150)
        with self.assertRaises(ApiError):
            self.call(1,'POST','/v1/skins/purchase',{'skin':'crimson','paid':True})
        self.api.db.close(); self.api = Store(self.path)
        self.assertEqual(self.call(0)['skin_entitlements'], ['crimson'])
        self.api.execute('UPDATE skin_entitlements SET revoked=1')
        self.assertEqual(self.call(0)['skin_entitlements'], [])
