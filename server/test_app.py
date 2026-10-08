import os
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
