"""Run Godot against a disposable, loopback-only multiplayer fixture.

Use --render with a display server to also capture the actual war chest UI.
No credentials or developer saves are printed or retained.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
from http.server import ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from server.app import handler_factory
from server.test_progression import ProgressionTests


def main():
    fixture = ProgressionTests()
    fixture.setUp()
    http = None
    worker = None
    try:
        fixture.match()
        fixture.match()
        http = ThreadingHTTPServer(('127.0.0.1', 0), handler_factory(fixture.api))
        worker = threading.Thread(target=http.serve_forever, daemon=True)
        worker.start()
        with tempfile.TemporaryDirectory(prefix='cd-online-audit-') as home:
            env = dict(os.environ, XDG_DATA_HOME=home,
                       CD_AUDIT_URL=f'http://127.0.0.1:{http.server_port}',
                       CD_AUDIT_TOKEN=fixture.players[0]['session_token'])
            flags = ['--audio-driver','Dummy','--rendering-driver','opengl3'] if '--render' in sys.argv else ['--headless']
            result = subprocess.run(['godot', '--path', str(ROOT), *flags,
                'res://scenes/tests/OnlineProgressionAudit.tscn'], env=env, timeout=90,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            print(result.stdout, end='')
            if result.returncode or '[ONLINE PROGRESSION AUDIT] PASS' not in result.stdout or any(
                    marker in result.stdout for marker in ('SCRIPT ERROR:', '\nERROR:')):
                return 1
            return 0
    finally:
        if http:
            http.shutdown()
            http.server_close()
        if worker:
            worker.join(timeout=3)
        fixture.tearDown()


if __name__ == '__main__':
    sys.exit(main())
