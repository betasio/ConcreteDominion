"""Single-process private-playtest entry point behind a trusted HTTPS proxy."""
import json
import logging
import os
from pathlib import Path
import secrets
import signal
import threading
import time
from http import HTTPStatus
from server.app import Store, ApiError
from server.security import RateLimiter
from server import rallies, world


class Runtime:
    def __init__(self, database, key):
        if len(key) < 32 or not key.isascii() or any(c.isspace() for c in key):
            raise ValueError('A playtest key of at least 32 non-whitespace ASCII characters is required')
        self.key = key.encode('ascii')
        self.store = Store(database)
        self.store.execute('PRAGMA journal_mode=WAL')
        self.store.execute('PRAGMA busy_timeout=5000')
        self.stop = threading.Event()
        self.last_tick = 0.0
        self.worker = threading.Thread(target=self._tick, name='rally-departures', daemon=True)
        self.worker.start()
        self.quota = RateLimiter(limit=120, window=60)
        self.accounts = RateLimiter(limit=8, window=60)

    def _tick(self):
        while not self.stop.is_set():
            try:
                rallies.settle_due(self.store)
                world.settle_due(self.store)
                self.last_tick = time.monotonic()
            except Exception as exc:
                logging.error('Rally worker failed (%s)', type(exc).__name__)
            self.stop.wait(1.0)

    def healthy(self):
        if not self.worker.is_alive() or time.monotonic()-self.last_tick > 5:
            return False
        with self.store.lock:
            return self.store.execute('SELECT 1').fetchone()[0] == 1

    def close(self):
        self.stop.set()
        self.worker.join(timeout=10)
        if not self.worker.is_alive():
            self.store.db.close()

    def __call__(self, environ, start_response):
        try:
            method, path = environ['REQUEST_METHOD'], environ.get('PATH_INFO', '')
            if method == 'GET' and path == '/healthz':
                healthy = self.healthy()
                status, payload = (200 if healthy else 503), {'status':'ok' if healthy else 'unavailable'}
            else:
                ip = environ.get('REMOTE_ADDR', '')
                if not self.quota.allow(ip):
                    raise ApiError(429, 'Request rate limit exceeded')
                supplied = environ.get('HTTP_X_PLAYTEST_KEY', '').encode('utf-8')
                if not secrets.compare_digest(supplied, self.key):
                    raise ApiError(403, 'Private playtest access required')
                if method not in ('GET', 'POST'):
                    raise ApiError(405, 'Method not allowed')
                if environ.get('QUERY_STRING'):
                    raise ApiError(400, 'Query parameters are not supported')
                if method == 'POST' and path in ('/v1/players', '/v1/recover') and not self.accounts.allow(ip):
                    raise ApiError(429, 'Account request limit exceeded')
                length = environ.get('CONTENT_LENGTH', '')
                if method == 'POST' and not length:
                    raise ApiError(411, 'Content-Length required')
                size = int(length or '0')
                if size < 0 or size > 16384:
                    raise ApiError(413, 'Request too large')
                raw = environ['wsgi.input'].read(size) if size else b''
                if len(raw) != size:
                    raise ApiError(400, 'Incomplete request body')
                data = json.loads(raw) if size else {}
                if not isinstance(data, dict):
                    raise ApiError(400, 'JSON object required')
                authorization = environ.get('HTTP_AUTHORIZATION', '')
                token = authorization[7:] if authorization.startswith('Bearer ') else ''
                with self.store.lock:
                    status, payload = self.store.call(method, path, data, token)
        except ApiError as exc:
            status, payload = exc.status, {'error':exc.message}
        except (ValueError, UnicodeDecodeError):
            status, payload = 400, {'error':'Invalid request'}
        except Exception as exc:
            # No request headers, credentials, bodies, or database details in logs.
            logging.error('API request failed (%s)', type(exc).__name__)
            status, payload = 500, {'error':'Request could not be completed'}
        body = json.dumps(payload).encode()
        headers = [('Content-Type','application/json'), ('Content-Length',str(len(body))),
                   ('Cache-Control','no-store'), ('X-Content-Type-Options','nosniff')]
        if status == 429:
            headers.append(('Retry-After','60'))
        start_response(f'{status} {HTTPStatus(status).phrase}', headers)
        return [body]


def main():
    from waitress import create_server
    logging.basicConfig(level=logging.INFO, format='%(levelname)s %(message)s')
    key_file = os.environ.get('CD_PLAYTEST_KEY_FILE', '/run/secrets/playtest_key')
    runtime = Runtime(os.environ.get('CD_DATABASE', '/data/concrete_dominion.sqlite'), Path(key_file).read_text().strip())
    http = create_server(runtime, host='0.0.0.0', port=8765, threads=4,
                         connection_limit=64, channel_timeout=15,
                         max_request_body_size=16384, max_request_header_size=8192,
                         trusted_proxy='*', trusted_proxy_count=1,
                         trusted_proxy_headers={'x-forwarded-for','x-forwarded-proto'},
                         clear_untrusted_proxy_headers=True, expose_tracebacks=False,
                         ident='ConcreteDominion')
    # The API has NO published port. Only Caddy shares this internal network;
    # Caddy overwrites forwarded addresses instead of trusting client headers.
    def shutdown(_signum, _frame):
        http.close()
    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    try:
        http.run()
    finally:
        http.task_dispatcher.shutdown(timeout=10)
        runtime.close()


if __name__ == '__main__':
    main()
