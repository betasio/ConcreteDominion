"""HTTP framing regression checks against the actual threaded development server."""
import http.client
import json
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer

from server.app import Store, handler_factory


class HttpFramingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.store = Store(self.tmp.name + "/test.sqlite")
        self.httpd = ThreadingHTTPServer(("127.0.0.1", 0), handler_factory(self.store))
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=3)
        self.store.db.close()
        self.tmp.cleanup()

    def request(self, headers, body=b"", path="/v1/players"):
        connection = http.client.HTTPConnection("127.0.0.1", self.httpd.server_port, timeout=3)
        try:
            connection.putrequest("POST", path)
            for key, value in headers:
                connection.putheader(key, value)
            connection.endheaders(body)
            response = connection.getresponse()
            return response.status, json.loads(response.read())
        finally:
            connection.close()

    def test_rejects_missing_length(self):
        status, payload = self.request([])
        self.assertEqual(status, 411)
        self.assertIn("Content-Length", payload["error"])

    def test_rejects_invalid_length(self):
        status, _ = self.request([("Content-Length", "not-a-number")])
        self.assertEqual(status, 400)

    def test_rejects_duplicate_length(self):
        status, _ = self.request([("Content-Length", "0"), ("Content-Length", "0")])
        self.assertEqual(status, 400)

    def test_rejects_chunked_transfer_encoding(self):
        status, _ = self.request([("Transfer-Encoding", "chunked")])
        self.assertEqual(status, 400)

    def test_rejects_oversized_body_before_parsing(self):
        status, _ = self.request([("Content-Length", "16385")])
        self.assertEqual(status, 413)

    def test_valid_player_creation_still_works(self):
        body = json.dumps({"display_name": "Test Leader"}).encode()
        status, payload = self.request([("Content-Length", str(len(body)))], body)
        self.assertEqual(status, 201)
        self.assertIn("session_token", payload)


if __name__ == "__main__":
    unittest.main()
