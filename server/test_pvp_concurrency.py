"""Concurrent HTTP regression tests for authoritative PvP combat and settlement."""
from concurrent.futures import ThreadPoolExecutor
from http.server import ThreadingHTTPServer
import http.client
import json
import tempfile
import threading
import unittest
import uuid

from server.app import Store, handler_factory


class ConcurrentPvpTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.store = Store(self.tmp.name + "/concurrency.sqlite")
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), handler_factory(self.store))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.teams = []
        for side in ("North", "South"):
            leaders = []
            for role in ("Boss", "Wing"):
                _, player = self.store.call("POST", "/v1/players",
                                            {"display_name": side + " " + role}, "")
                leaders.append(player)
            self.store.call("POST", "/v1/factions",
                            {"name": side + " Syndicate", "tag": side[:3].upper()},
                            leaders[0]["session_token"])
            _, invite = self.store.call("POST", "/v1/invitations",
                                         {"player_id": leaders[1]["player_id"]},
                                         leaders[0]["session_token"])
            self.store.call("POST", "/v1/invitations/" + invite["invitation_id"] + "/accept",
                            {}, leaders[1]["session_token"])
            self.teams.append(leaders)
        for team in self.teams:
            self.store.call("POST", "/v1/pvp/queue", {}, team[0]["session_token"])
        self.match_id = self.store.call("GET", "/v1/pvp", {},
                                        self.teams[0][0]["session_token"])[1]["match"]["id"]

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)
        self.store.db.close()
        self.tmp.cleanup()

    def attack(self, token, request_id, strategy="muscle"):
        body = json.dumps({"strategy": strategy, "request_id": request_id}).encode()
        conn = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=10)
        try:
            conn.request("POST", "/v1/pvp/attack", body,
                         {"Authorization": "Bearer " + token, "Content-Type": "application/json"})
            response = conn.getresponse()
            return response.status, json.loads(response.read())
        finally:
            conn.close()

    def test_parallel_identical_requests_award_exactly_one_attack(self):
        token = self.teams[0][0]["session_token"]
        request_id = uuid.uuid4().hex
        with ThreadPoolExecutor(max_workers=8) as pool:
            responses = list(pool.map(lambda _: self.attack(token, request_id), range(8)))
        self.assertEqual([status for status, _ in responses], [200] * 8)
        self.assertEqual(sum(not result["replayed"] for _, result in responses), 1)
        self.assertEqual(sum(result["replayed"] for _, result in responses), 7)
        self.assertEqual(len({result["points"] for _, result in responses}), 1)
        attacks = self.store.execute("SELECT COUNT(*),COALESCE(SUM(points),0) FROM pvp_attacks WHERE match_id=?",
                                     (self.match_id,)).fetchone()
        self.assertEqual(attacks[0], 1)
        self.assertEqual(attacks[1], responses[0][1]["points"])

    def test_parallel_attacks_settle_once_and_respect_player_caps(self):
        # Each of four players makes three unique attacks concurrently.
        jobs = [(player["session_token"], uuid.uuid4().hex)
                for team in self.teams for player in team for _ in range(3)]
        with ThreadPoolExecutor(max_workers=12) as pool:
            responses = list(pool.map(lambda job: self.attack(*job), jobs))
        self.assertTrue(all(status == 200 for status, _ in responses), responses)
        with self.store.lock:
            match = self.store.execute("SELECT * FROM pvp_matches WHERE id=?", (self.match_id,)).fetchone()
            attacks = self.store.execute(
                "SELECT faction_id,player_id,points FROM pvp_attacks WHERE match_id=?", (self.match_id,)
            ).fetchall()
            ledger = self.store.execute(
                "SELECT faction_id,points,reason FROM pvp_ledger WHERE match_id=?", (self.match_id,)
            ).fetchall()
        self.assertEqual(match["status"], "complete")
        self.assertEqual((match["rounds_a"], match["rounds_b"]), (6, 6))
        self.assertEqual(len(attacks), 12)
        self.assertEqual(len(ledger), 2)
        self.assertTrue(all(row["reason"] == "pvp_settlement" for row in ledger))
        self.assertEqual(len({row["faction_id"] for row in ledger}), 2)
        for team in self.teams:
            for player in team:
                self.assertEqual(sum(row["player_id"] == player["player_id"] for row in attacks), 3)
        self.assertEqual(match["score_a"] + match["score_b"],
                         sum(row["points"] for row in attacks))
        replay_token, replay_id = jobs[0]
        status, replay = self.attack(replay_token, replay_id)
        self.assertEqual(status, 200)
        self.assertTrue(replay["replayed"])
        self.assertEqual(self.store.execute(
            "SELECT COUNT(*) FROM pvp_ledger WHERE match_id=?", (self.match_id,)
        ).fetchone()[0], 2)
        status, rejected = self.attack(replay_token, uuid.uuid4().hex)
        self.assertEqual(status, 409)


if __name__ == "__main__":
    unittest.main()
