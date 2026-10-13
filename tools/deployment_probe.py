"""Disposable HTTPS Compose check. Never targets or removes an existing deployment.

Requires a prebuilt concrete-dominion-api:local image; --godot also checks the game.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import ssl
import subprocess
import tempfile
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='cd-deployment-') as tmp:
        directory = Path(tmp)
        key = secrets.token_hex(32)
        key_path = directory/'playtest_key'
        key_path.write_text(key)
        key_path.chmod(0o444)  # Parent is 0700; Compose mounts secrets read-only.
        env = dict(os.environ, CD_DOMAIN='localhost', CD_RELEASE='local',
                   CD_HTTP_BIND='127.0.0.1:0', CD_HTTPS_BIND='127.0.0.1:0',
                   CD_PLAYTEST_KEY_PATH=str(key_path), CD_DATABASE='/data/concrete_dominion.sqlite')
        project = 'cd-probe-'+uuid.uuid4().hex[:10]
        command = ['docker','compose','-p',project,'-f',str(ROOT/'deploy/compose.yml')]
        def compose(*arguments):
            result = subprocess.run(command+list(arguments), env=env, capture_output=True, text=True, timeout=90)
            if result.returncode:
                raise RuntimeError(result.stderr)
            return result.stdout.strip()
        exported_backups = []
        try:
            compose('up','-d','--no-build','--wait','--wait-timeout','45')
            port = compose('port','proxy','443').rsplit(':',1)[1]
            certificate = compose('exec','-T','proxy','cat','/data/caddy/pki/authorities/local/root.crt')
            ca = directory/'root.crt'
            ca.write_text(certificate+'\n')
            context = ssl.create_default_context(cafile=str(ca))
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), urllib.request.HTTPSHandler(context=context))
            base = 'https://localhost:'+port
            def request(path, data=None, token='', access=True, extra=None):
                headers = {'Content-Type':'application/json'}
                if access:
                    headers['X-Playtest-Key'] = key
                if token:
                    headers['Authorization'] = 'Bearer '+token
                headers.update(extra or {})
                body = json.dumps(data).encode() if data is not None else None
                req = urllib.request.Request(base+path, data=body, headers=headers)
                try:
                    response = opener.open(req, timeout=10)
                except urllib.error.HTTPError as exc:
                    response = exc
                with response:
                    return response.status, json.loads(response.read())
            assert request('/healthz', access=False) == (200, {'status':'ok'})
            assert request('/v1/players', {'display_name':'Blocked'}, access=False)[0] == 403
            accounts = []
            for name in ('North Boss','North Wing','South Boss','South Wing'):
                status, player = request('/v1/players', {'display_name':name})
                assert status == 201
                accounts.append(player)
            def call(index, path, data=None):
                status, body = request(path, data, accounts[index]['session_token'])
                assert 200 <= status < 300, (status, body)
                return body
            for leader, name in ((0,'North'),(2,'South')):
                call(leader, '/v1/factions', {'name':name+' Family','tag':name[:3]})
                invitation = call(leader, '/v1/invitations', {'player_id':accounts[leader+1]['player_id']})
                call(leader+1, '/v1/invitations/'+invitation['invitation_id']+'/accept', {})
            for _ in range(2):
                call(0, '/v1/pvp/queue', {})
                call(2, '/v1/pvp/queue', {})
                for index in range(4):
                    plans = ('muscle','convoy','intel') if index < 2 else ('intel','muscle','convoy')
                    for strategy in plans:
                        call(index, '/v1/pvp/attack', {'strategy':strategy,'request_id':uuid.uuid4().hex})
            assert call(0,'/v1/progression')['treasury']['cash'] == 6000
            # Client-supplied forwarded addresses must not bypass the account quota.
            spoofed = [request('/v1/players', {'display_name':'Quota Probe'},
                       extra={'X-Forwarded-For':f'198.51.100.{i+1}'})[0] for i in range(5)]
            assert spoofed == [201,201,201,201,429], spoofed
            compose('exec','-T','api','python','-m','server.backup','--source','/data/concrete_dominion.sqlite','--destination','/data/probe-backup.sqlite')
            backup_folder = ROOT/'deploy/backups'
            previous_backups = set(backup_folder.glob('*.sqlite'))
            backup_job = subprocess.run(['bash',str(ROOT/'deploy/backup.sh')],
                env=dict(env, COMPOSE_PROJECT_NAME=project), capture_output=True, text=True, timeout=30)
            exported_backups = list(set(backup_folder.glob('*.sqlite'))-previous_backups)
            assert backup_job.returncode == 0 and len(exported_backups) == 1, backup_job.stderr
            compose('restart','api')
            compose('up','-d','--no-build','--wait','--wait-timeout','45')
            assert call(0,'/v1/progression')['command_xp'] == 110
            assert call(0,'/v1/progression')['treasury']['cash'] == 6000
            status, canary = request('/v1/players', {'display_name':'After Backup'})
            assert status == 201
            assert compose('exec','-T','api','id','-u') == '10001'
            # API port must not be published: requests go through Caddy only.
            api_id = compose('ps','-q','api')
            published = subprocess.check_output(['docker','inspect','--format','{{json .HostConfig.PortBindings}}',api_id], text=True)
            assert json.loads(published) in (None,{})
            if args.godot:
                game_env = dict(env, CD_AUDIT_URL=base, CD_AUDIT_KEY=key,
                                CD_AUDIT_TOKEN=accounts[0]['session_token'], CD_AUDIT_CA=str(ca), XDG_DATA_HOME=str(directory/'godot'))
                game = subprocess.run(['godot','--headless','--path',str(ROOT),'res://scenes/tests/OnlineProgressionAudit.tscn'],
                                      env=game_env, capture_output=True, text=True, timeout=90)
                output = game.stdout+game.stderr
                assert game.returncode == 0 and '[ONLINE PROGRESSION AUDIT] PASS' in output and 'SCRIPT ERROR:' not in output and '\nERROR:' not in output, output
                print('[DEPLOYMENT] Godot HTTPS account, progression and upgrade passed')
            compose('stop','api')
            compose('run','--rm','--no-deps','api','python','-m','server.backup',
                    '--source','/data/probe-backup.sqlite','--destination','/data/restored.sqlite')
            env['CD_DATABASE'] = '/data/restored.sqlite'
            compose('up','-d','--no-build','--wait','--wait-timeout','45')
            assert call(0,'/v1/progression')['treasury']['cash'] == 6000
            assert call(0,'/v1/progression')['hall_level'] == 1
            assert request('/v1/me', token=canary['session_token'])[0] == 401
            print('[DEPLOYMENT] PASS — verified TLS, private access, real wars, persistent restart, backup/restore, proxy trust and isolated non-root API')
        except Exception:
            print(compose('logs','--no-color','--tail','30'))
            raise
        finally:
            compose('down','--volumes','--remove-orphans')
            for backup in exported_backups:
                backup.unlink()


if __name__ == '__main__':
    main()
