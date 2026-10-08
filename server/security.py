"""Bounded in-memory abuse protection for the local development HTTP server.

This is intentionally single-process and is NOT a distributed production quota.
"""
from collections import deque
import threading
import time

class RateLimiter:
    def __init__(self, limit=12, window=60, max_clients=4096, clock=None):
        self.limit, self.window, self.max_clients = limit, window, max_clients
        self.clock = clock or time.monotonic
        self.lock = threading.Lock()
        self.hits = {}

    def allow(self, client):
        now = self.clock()
        with self.lock:
            if client not in self.hits and len(self.hits) >= self.max_clients:
                stale = [k for k, q in self.hits.items() if not q or now-q[-1] >= self.window]
                for k in stale:
                    del self.hits[k]
                if len(self.hits) >= self.max_clients:
                    return False
            q = self.hits.setdefault(client, deque())
            while q and now - q[0] >= self.window:
                q.popleft()
            if len(q) >= self.limit:
                return False
            q.append(now)
            return True
