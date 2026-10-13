"""Disposable loopback fixture for real Godot city API and UI checks.

--render also saves desktop/portrait screenshots. No credentials are printed.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
from http.server import ThreadingHTTPServer
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from server.app import handler_factory
from server.test_world import WorldTests


def main():
    fixture=WorldTests()
    fixture.setUp()
    http=ThreadingHTTPServer(('127.0.0.1',0),handler_factory(fixture.api))
    worker=threading.Thread(target=http.serve_forever,daemon=True)
    worker.start()
    try:
        with tempfile.TemporaryDirectory(prefix='cd-world-audit-') as home:
            env=dict(os.environ,XDG_DATA_HOME=home,CD_AUDIT_URL=f'http://127.0.0.1:{http.server_port}',CD_AUDIT_TOKEN=fixture.players[0]['session_token'])
            flags=['--audio-driver','Dummy','--rendering-driver','opengl3'] if '--render' in sys.argv else ['--headless']
            result=subprocess.run(['godot','--path',str(ROOT),*flags,'res://scenes/tests/OnlineWorldAudit.tscn'],env=env,timeout=90,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
            print(result.stdout,end='')
            return int(result.returncode!=0 or '[ONLINE WORLD AUDIT] PASS' not in result.stdout or any(x in result.stdout for x in ('SCRIPT ERROR:','\nERROR:')))
    finally:
        http.shutdown(); http.server_close(); worker.join(timeout=3)
        fixture.tearDown()

if __name__=='__main__': sys.exit(main())
