import unittest
from server.security import RateLimiter

class SecurityTests(unittest.TestCase):
    def test_limit_window_and_client_isolation(self):
        now=[0.]
        guard=RateLimiter(limit=2,window=10,clock=lambda:now[0])
        self.assertTrue(guard.allow("a"))
        self.assertTrue(guard.allow("a"))
        self.assertFalse(guard.allow("a"))
        self.assertTrue(guard.allow("b"))
        now[0]=10.
        self.assertTrue(guard.allow("a"))

    def test_bounded_tracking_and_stale_cleanup(self):
        now=[0.]
        guard=RateLimiter(limit=1,window=10,max_clients=2,clock=lambda:now[0])
        self.assertTrue(guard.allow("a"))
        self.assertTrue(guard.allow("b"))
        self.assertFalse(guard.allow("c"))
        now[0]=11.
        self.assertTrue(guard.allow("c"))
        self.assertLessEqual(len(guard.hits),2)

if __name__ == "__main__":
    unittest.main()
