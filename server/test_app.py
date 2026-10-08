import os
import uuid
import tempfile
import unittest
from server.app import Store, ApiError


class FactionApiTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.temp.name,"game.sqlite")
        self.api = Store(self.path)

    def tearDown(self):
        self.api.db.close()
        self.temp.cleanup()

    def register(self, name):
        status, data = self.api.call("POST","/v1/players",{"display_name":name},"")
        self.assertEqual(status,201)
        return data

    def test_create_invite_accept_and_reopen(self):
        leader = self.register("Leader")
        player = self.register("Recruit")
        outsider = self.register("Outsider")
        leader_token = leader["session_token"]
        player_token = player["session_token"]
        outsider_token = outsider["session_token"]
        status, faction = self.api.call("POST","/v1/factions",{"name":"Night Union","tag":"NU"},leader_token)
        self.assertEqual(status,201)
        self.assertEqual(faction["tag"],"NU")
        with self.assertRaises(ApiError) as denied:
            self.api.call("POST","/v1/invitations",{"player_id":player["player_id"]},outsider_token)
        self.assertEqual(denied.exception.status,403)
        _, invite = self.api.call("POST","/v1/invitations",{"player_id":player["player_id"]},leader_token)
        with self.assertRaises(ApiError) as denied:
            self.api.call("POST",f"/v1/invitations/{invite['invitation_id']}/accept",{},outsider_token)
        self.assertEqual(denied.exception.status,404)
        self.assertEqual(len(self.api.call("GET","/v1/invitations",{},player_token)[1]["invitations"]),1)
        self.api.db.close()
        self.api = Store(self.path)
        status, joined = self.api.call("POST",f"/v1/invitations/{invite['invitation_id']}/accept",{},player_token)
        self.assertEqual(status,200)
        self.assertEqual(joined["faction_id"],faction["faction_id"])
        members = self.api.call("GET","/v1/faction",{},leader_token)[1]["members"]
        self.assertEqual({m["role"] for m in members},{"leader","member"})
        with self.assertRaises(ApiError) as duplicate:
            self.api.call("POST",f"/v1/invitations/{invite['invitation_id']}/accept",{},player_token)
        self.assertEqual(duplicate.exception.status,404)

    def test_two_member_shared_war_and_server_scoring(self):
        leader = self.register("Boss")
        member = self.register("Partner")
        outsider = self.register("Intruder")
        lt, mt, ot = (x["session_token"] for x in (leader, member, outsider))
        self.api.call("POST","/v1/factions",{"name":"Steel Union","tag":"STL"},lt)
        _, invite = self.api.call("POST","/v1/invitations",{"player_id":member["player_id"]},lt)
        self.api.call("POST",f"/v1/invitations/{invite['invitation_id']}/accept",{},mt)
        with self.assertRaises(ApiError) as denied:
            self.api.call("POST","/v1/war/start",{},mt)
        self.assertEqual(denied.exception.status,403)
        _, war = self.api.call("POST","/v1/war/start",{},lt)
        with self.assertRaises(ApiError) as duplicate:
            self.api.call("POST","/v1/war/start",{},lt)
        self.assertEqual(duplicate.exception.status,409)
        with self.assertRaises(ApiError) as outsider_denied:
            self.api.call("GET","/v1/war",{},ot)
        self.assertEqual(outsider_denied.exception.status,403)
        with self.assertRaises(ApiError) as bad_strategy:
            self.api.call("POST","/v1/war/attack",{"strategy":"win","our_points":999999},lt)
        self.assertEqual(bad_strategy.exception.status,400)
        for i in range(6):
            token = lt if i % 2 == 0 else mt
            _, before = self.api.call("GET","/v1/war",{},token)
            defense = before["defense"]
            strategy = {"watchful":"muscle","fortified":"convoy","mobile":"intel"}[defense]
            _, result = self.api.call("POST","/v1/war/attack",{"strategy":strategy,"our_points":999999},token)
            self.assertEqual(result["our_points"],140)
            self.assertTrue(result["countered"])
        _, ended = self.api.call("GET","/v1/war",{},mt)
        self.assertEqual(ended["war"]["status"],"complete")
        self.assertEqual(ended["war"]["result"],"VICTORY")
        self.assertEqual(ended["war"]["our_score"],840)
        self.assertEqual(len(ended["attacks"]),6)
        self.assertEqual(sum(x["contribution"] for x in ended["contributions"]),840)
        self.assertEqual({x["attacks"] for x in ended["contributions"]},{3})
        with self.assertRaises(ApiError) as extra:
            self.api.call("POST","/v1/war/attack",{"strategy":"muscle"},lt)
        self.assertEqual(extra.exception.status,409)
        self.api.db.close()
        self.api = Store(self.path)
        self.assertEqual(self.api.call("GET","/v1/war",{},mt)[1]["war"]["our_score"],840)

    def test_pvp_two_factions_settlement_and_replay(self):
        tokens = []
        ids = []
        for name in ("Alpha Leader","Alpha Wing","Bravo Leader","Bravo Wing","Spectator"):
            player = self.register(name)
            ids.append(player["player_id"])
            tokens.append(player["session_token"])
        a,b,c,d,outsider = tokens
        self.api.call("POST","/v1/factions",{"name":"Alpha Syndicate","tag":"AAA"},a)
        self.api.call("POST","/v1/factions",{"name":"Bravo Syndicate","tag":"BBB"},c)
        for leader,member_id,member_token in ((a,ids[1],b),(c,ids[3],d)):
            _, invitation = self.api.call("POST","/v1/invitations",{"player_id":member_id},leader)
            self.api.call("POST",f"/v1/invitations/{invitation['invitation_id']}/accept",{},member_token)
        with self.assertRaises(ApiError) as forbidden:
            self.api.call("POST","/v1/pvp/queue",{},b)
        self.assertEqual(forbidden.exception.status,403)
        self.assertTrue(self.api.call("POST","/v1/pvp/queue",{},a)[1]["queued"])
        match = self.api.call("POST","/v1/pvp/queue",{},c)[1]["match"]
        self.assertEqual(match["status"],"active")
        self.assertEqual(self.api.call("GET","/v1/pvp",{},a)[1]["match"]["id"],
                         self.api.call("GET","/v1/pvp",{},d)[1]["match"]["id"])
        with self.assertRaises(ApiError) as unauthorized:
            self.api.call("GET","/v1/pvp",{},outsider)
        self.assertEqual(unauthorized.exception.status,403)
        with self.assertRaises(ApiError) as invalid:
            self.api.call("POST","/v1/pvp/attack",{"strategy":"muscle","request_id":"bad"},a)
        self.assertEqual(invalid.exception.status,400)
        for team in ((a,b),(c,d)):
            for round_no in range(6):
                token = team[round_no%2]
                defense = self.api.call("GET","/v1/pvp",{},token)[1]["match"]["defense"]
                strategy = {"watchful":"muscle","fortified":"convoy","mobile":"intel"}[defense]
                request = {"strategy":strategy,"request_id":uuid.uuid4().hex,"points":1000000}
                status, result = self.api.call("POST","/v1/pvp/attack",request,token)
                self.assertEqual(status,200)
                self.assertEqual(result["points"],140)
                self.assertFalse(result["replayed"])
                before = self.api.call("GET","/v1/pvp",{},token)[1]["match"]["our_score"]
                status, replay = self.api.call("POST","/v1/pvp/attack",request,token)
                self.assertEqual(status,200)
                self.assertTrue(replay["replayed"])
                self.assertEqual(self.api.call("GET","/v1/pvp",{},token)[1]["match"]["our_score"],before)
                with self.assertRaises(ApiError) as mismatched:
                    self.api.call("POST","/v1/pvp/attack",
                                  {"strategy":"muscle" if strategy!="muscle" else "intel",
                                   "request_id":request["request_id"]},token)
                self.assertEqual(mismatched.exception.status,409)
        state = self.api.call("GET","/v1/pvp",{},a)[1]
        self.assertEqual(state["match"]["status"],"complete")
        self.assertEqual(state["match"]["result"],"DRAW")
        self.assertEqual(state["match"]["our_score"],840)
        self.assertEqual(len(state["ledger"]),2)
        self.assertEqual(sorted(x["points"] for x in state["ledger"]),[50,50])
        self.assertEqual(len(state["attacks"]),12)
        with self.assertRaises(ApiError) as exhausted:
            self.api.call("POST","/v1/pvp/attack",
                          {"strategy":"muscle","request_id":uuid.uuid4().hex},a)
        self.assertEqual(exhausted.exception.status,409)
        self.api.db.close()
        self.api = Store(self.path)
        self.assertEqual(self.api.call("GET","/v1/pvp",{},c)[1]["match"]["status"],"complete")
        self.assertEqual(len(self.api.call("GET","/v1/pvp",{},c)[1]["ledger"]),2)

    def test_match_timestamp_schema(self):
        columns = {row["name"] for row in self.api.execute("PRAGMA table_info(pvp_matches)")}
        self.assertIn("created_at", columns)

    def test_queue_cancel_and_expiry(self):
        from server import pvp
        leader = self.register("Queue Leader")
        member = self.register("Queue Member")
        rival = self.register("Other Leader")
        lt, mt, rt = (x["session_token"] for x in (leader, member, rival))
        self.api.call("POST","/v1/factions",{"name":"Cancel Crew","tag":"CAN"},lt)
        self.api.call("POST","/v1/factions",{"name":"Rival Crew","tag":"RIV"},rt)
        _, invitation = self.api.call("POST","/v1/invitations",{"player_id":member["player_id"]},lt)
        self.api.call("POST",f"/v1/invitations/{invitation['invitation_id']}/accept",{},mt)
        self.api.call("POST","/v1/pvp/queue",{},lt)
        with self.assertRaises(ApiError) as denied:
            self.api.call("POST","/v1/pvp/cancel",{},mt)
        self.assertEqual(denied.exception.status,403)
        self.assertFalse(self.api.call("POST","/v1/pvp/cancel",{},lt)[1]["queued"])
        with self.assertRaises(ApiError):
            self.api.call("POST","/v1/pvp/cancel",{},lt)
        self.api.call("POST","/v1/pvp/queue",{},lt)
        self.api.execute("UPDATE pvp_queue SET queued_at=0")
        self.api.db.commit()
        self.assertFalse(self.api.call("GET","/v1/pvp",{},lt)[1]["queued"])
        self.api.call("POST","/v1/pvp/queue",{},lt)
        self.api.call("POST","/v1/pvp/queue",{},rt)
        state = self.api.call("GET","/v1/pvp",{},lt)[1]
        match_id = state["match"]["id"]
        with self.assertRaises(ApiError):
            self.api.call("POST","/v1/pvp/cancel",{},lt)
        self.api.execute("UPDATE pvp_matches SET created_at=0 WHERE id=?", (match_id,))
        self.api.db.commit()
        ended = self.api.call("GET","/v1/pvp",{},rt)[1]
        self.assertEqual(ended["match"]["status"],"complete")
        self.assertEqual(sorted(x["points"] for x in ended["ledger"]),[0,0])
        self.assertEqual({x["reason"] for x in ended["ledger"]},{"pvp_timeout"})
        self.assertEqual(len(self.api.call("GET","/v1/pvp",{},lt)[1]["ledger"]),2)

    def test_permissions_and_names(self):
        p = self.register("Alpha")
        with self.assertRaises(ApiError) as invalid:
            self.api.call("POST","/v1/factions",{"name":"X","tag":"?"},p["session_token"])
        self.assertEqual(invalid.exception.status,400)
        self.api.call("POST","/v1/factions",{"name":"The Family","tag":"FAM"},p["session_token"])
        with self.assertRaises(ApiError) as duplicate:
            self.api.call("POST","/v1/factions",{"name":"Another","tag":"ABC"},p["session_token"])
        self.assertEqual(duplicate.exception.status,409)
        with self.assertRaises(ApiError) as invalid_token:
            self.api.call("GET","/v1/me",{},"fake")
        self.assertEqual(invalid_token.exception.status,401)


if __name__ == "__main__":
    unittest.main()
