"""Private deployment middleware, health and backup behavior without Docker."""
from io import BytesIO
import json
from pathlib import Path
import sqlite3
import tempfile
import time
import unittest
from unittest.mock import patch
from server.deployment import Runtime
from server.backup import copy_database


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = Path(self.tmp.name)/'game.sqlite'
        self.key = 'x'*64
        self.runtime = Runtime(str(self.db), self.key)
        for _ in range(100):
            if self.runtime.last_tick:
                break
            time.sleep(0.01)

    def tearDown(self):
        self.runtime.close()
        self.tmp.cleanup()

    def request(self, path='/v1/players', key=None, method='POST', raw=b'{"display_name":"Tester"}', **extra):
        env = {'REQUEST_METHOD':method,'PATH_INFO':path,'REMOTE_ADDR':'192.0.2.1',
               'wsgi.input':BytesIO(raw),'CONTENT_LENGTH':str(len(raw)),
               'HTTP_X_PLAYTEST_KEY':self.key if key is None else key}
        env.update(extra)
        response = {}
        def start(status, headers):
            response['status'] = int(status.split()[0])
            response['headers'] = dict(headers)
        response['body'] = json.loads(b''.join(self.runtime(env, start)))
        return response

    def test_key_gate_health_and_body_validation(self):
        self.assertEqual(self.request(key='')['status'],403)
        self.assertEqual(self.request(key='wrong')['status'],403)
        self.assertEqual(self.request('/healthz',key='',method='GET',raw=b'')['status'],200)
        self.assertEqual(self.request(raw=b'[]')['status'],400)
        self.assertEqual(self.request(raw=b'broken')['status'],400)
        self.assertEqual(self.request(raw=b'x'*16385)['status'],413)
        self.assertEqual(self.request(CONTENT_LENGTH='')['status'],411)
        self.assertEqual(self.request(QUERY_STRING='token=forbidden')['status'],400)
        created = self.request()
        self.assertEqual(created['status'],201)
        self.assertEqual(created['headers']['Cache-Control'],'no-store')
        me = self.request('/v1/me', method='GET', raw=b'', HTTP_AUTHORIZATION='Bearer '+created['body']['session_token'])
        self.assertEqual(me['body']['player_id'],created['body']['player_id'])

    def test_unhealthy_worker_and_redacted_errors(self):
        self.runtime.stop.set()
        self.runtime.worker.join(timeout=3)
        self.assertEqual(self.request('/healthz', method='GET', raw=b'')['status'],503)
        with patch.object(self.runtime.store, 'call', side_effect=RuntimeError('secret database details')):
            with self.assertLogs(level='ERROR') as logged:
                result = self.request()
        self.assertEqual(result['status'],500)
        self.assertNotIn('secret database details',str(result)+str(logged.output))

    def test_account_limit_and_new_ip(self):
        for i in range(8):
            self.assertEqual(self.request()['status'],201)
        blocked = self.request()
        self.assertEqual(blocked['status'],429)
        self.assertEqual(blocked['headers']['Retry-After'],'60')
        self.assertEqual(self.request(REMOTE_ADDR='192.0.2.2')['status'],201)

    def test_consistent_backup_and_restore_to_new_path(self):
        player = self.request()['body']
        backup = Path(self.tmp.name)/'backup.sqlite'
        restored = Path(self.tmp.name)/'restored.sqlite'
        copy_database(self.db, backup)
        self.request(raw=b'{"display_name":"Later"}')
        copy_database(backup, restored)
        with sqlite3.connect(restored) as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM players').fetchone()[0],1)
            self.assertEqual(db.execute('SELECT id FROM players').fetchone()[0],player['player_id'])
        with self.assertRaises(ValueError):
            copy_database(self.db, backup)
        with self.assertRaises(ValueError):
            copy_database(Path(self.tmp.name)/'missing', restored)

    def test_missing_or_weak_key_refused(self):
        for key in ('', 'short', 'x'*32+'\n'):
            with self.assertRaises(ValueError):
                Runtime(str(self.db), key)
