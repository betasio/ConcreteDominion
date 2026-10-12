"""Rally membership, deadlines, restart safety and defender visibility."""
import tempfile
import unittest
import uuid
from unittest.mock import patch
from concurrent.futures import ThreadPoolExecutor
from server.app import Store, ApiError
from server import rallies

class RallyTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.path=self.tmp.name+'/rallies.sqlite'
        self.api=Store(self.path)
        self.players=[]
        for name in ('Alpha','Beta','Wing','Solo','Fourth','Fifth','Sixth'):
            self.players.append(self.api.call('POST','/v1/players',{'display_name':name},'')[1])
        for index in (0,1):
            self.call(index,'POST','/v1/factions',{'name':['Alpha Family','Beta Family'][index],'tag':['ALP','BET'][index]})
        for index in (2,4,5,6):
            invite=self.call(0,'POST','/v1/invitations',{'player_id':self.players[index]['player_id']})['invitation_id']
            self.call(index,'POST','/v1/invitations/'+invite+'/accept')
        for index in (0,1): self.call(index,'POST','/v1/pvp/queue')
    def tearDown(self):
        self.api.db.close()
        self.tmp.cleanup()
    def call(self,index,method,path,data=None):
        with self.api.lock:
            return self.api.call(method,path,data or {},self.players[index]['session_token'])[1]
    def prepare(self,seconds=60,request=None):
        return self.call(0,'POST','/v1/rallies',{'strategy':'muscle','preparation':seconds,'request_id':request or uuid.uuid4().hex})['rallies'][0]
    def test_membership_alerts_and_automatic_departure(self):
        with self.assertRaises(ApiError): self.call(3,'GET','/v1/rallies')
        rally=self.prepare()
        rid=rally['id']
        self.assertTrue(self.call(1,'GET','/v1/rallies')['rallies'][0]['incoming'])
        with self.assertRaises(ApiError): self.call(1,'POST',f'/v1/rallies/{rid}/join')
        self.call(2,'POST',f'/v1/rallies/{rid}/join')
        self.call(2,'POST',f'/v1/rallies/{rid}/join')
        self.assertEqual(len(self.call(0,'GET','/v1/rallies')['rallies'][0]['members']),2)
        with patch('server.rallies.time.time',return_value=rally['departs_at']):
            rallies.settle_due(self.api)
            with self.assertRaises(ApiError): self.call(4,'POST',f'/v1/rallies/{rid}/join')
        row=self.call(0,'GET','/v1/rallies')['rallies'][0]
        self.assertEqual(row['status'],'departed')
        self.assertTrue(all('points' in x['outcome'] for x in row['members']))
        self.assertEqual(self.api.execute('SELECT COUNT(*) FROM pvp_attacks').fetchone()[0],2)
        self.assertEqual(self.call(1,'GET','/v1/rallies')['rallies'],[])
    def test_parallel_join_capacity_and_cancellation(self):
        rid=self.prepare()['id']
        def join(index):
            try: self.call(index,'POST',f'/v1/rallies/{rid}/join'); return True
            except ApiError: return False
        with ThreadPoolExecutor(max_workers=4) as pool:
            self.assertEqual(sum(pool.map(join,(2,4,5,6))),3)
        with self.assertRaises(ApiError): self.call(2,'POST',f'/v1/rallies/{rid}/cancel')
        self.call(0,'POST',f'/v1/rallies/{rid}/cancel')
        self.assertEqual(self.call(0,'GET','/v1/rallies')['rallies'][0]['status'],'cancelled')
    def test_retry_restart_and_invalid_preparation(self):
        for invalid in (0,True,59,'60',999):
            with self.assertRaises(ApiError): self.prepare(invalid)
        receipt=uuid.uuid4().hex
        rally=self.prepare(180,receipt)
        self.assertEqual(self.prepare(180,receipt)['id'],rally['id'])
        with self.assertRaises(ApiError): self.prepare(300,receipt)
        self.api.db.close(); self.api=Store(self.path)
        with patch('server.rallies.time.time',return_value=rally['departs_at']+1):
            rallies.settle_due(self.api); rallies.settle_due(self.api)
        self.assertEqual(self.api.execute('SELECT COUNT(*) FROM pvp_attacks').fetchone()[0],1)
    def test_departure_does_not_attack_a_later_match(self):
        rally=self.prepare()
        with self.api.db:
            self.api.execute("UPDATE pvp_matches SET status='complete'")
        for index in (0,1): self.call(index,'POST','/v1/pvp/queue')
        with patch('server.rallies.time.time',return_value=rally['departs_at']+1): rallies.settle_due(self.api)
        self.assertEqual(self.api.execute('SELECT COUNT(*) FROM pvp_attacks').fetchone()[0],0)
        self.assertEqual(self.call(0,'GET','/v1/rallies')['rallies'][0]['status'],'cancelled')
    def test_departure_recovers_after_combat_receipt_crash(self):
        import hashlib
        from server import pvp
        rally=self.prepare()
        actor=self.api.execute('SELECT * FROM players WHERE id=?',(self.players[0]['player_id'],)).fetchone()
        receipt=hashlib.sha256((rally['id']+actor['id']).encode()).hexdigest()[:32]
        pvp.route(self.api,'POST','/v1/pvp/attack',{'request_id':receipt,'strategy':'muscle'},actor)
        self.api.db.close(); self.api=Store(self.path)
        with patch('server.rallies.time.time',return_value=rally['departs_at']+1): rallies.settle_due(self.api)
        self.assertEqual(self.api.execute('SELECT COUNT(*) FROM pvp_attacks').fetchone()[0],1)
        self.assertEqual(self.call(0,'GET','/v1/rallies')['rallies'][0]['status'],'departed')
    def test_members_who_leave_before_departure_do_not_attack(self):
        rally=self.prepare()
        self.call(2,'POST',f"/v1/rallies/{rally['id']}/join")
        with self.api.db:
            self.api.execute('DELETE FROM memberships WHERE player_id=?',(self.players[2]['player_id'],))
            self.api.execute("UPDATE players SET faction_id=NULL WHERE id=?",(self.players[2]['player_id'],))
        with patch('server.rallies.time.time',return_value=rally['departs_at']+1): rallies.settle_due(self.api)
        self.assertEqual(self.api.execute('SELECT COUNT(*) FROM pvp_attacks').fetchone()[0],1)
        self.assertTrue(any(m['outcome']=='Left faction' for m in self.call(0,'GET','/v1/rallies')['rallies'][0]['members']))
