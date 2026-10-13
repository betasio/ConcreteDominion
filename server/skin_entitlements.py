"""Verified purchase storage, reserved for a future payment-provider webhook.

There is deliberately no client grant/purchase endpoint. Receipt verification and
refund handling must be integrated before checkout can be enabled.
"""
SCHEMA = '''
CREATE TABLE IF NOT EXISTS skin_entitlements(
 player_id TEXT NOT NULL REFERENCES players(id),
 skin_id TEXT NOT NULL CHECK(skin_id IN ('crimson','emerald')),
 provider_receipt TEXT NOT NULL UNIQUE,
 revoked INTEGER NOT NULL DEFAULT 0 CHECK(revoked IN (0,1)),
 PRIMARY KEY(player_id,skin_id));
'''


def owned(store, player_id):
    return [row[0] for row in store.execute(
        'SELECT skin_id FROM skin_entitlements WHERE player_id=? AND revoked=0 ORDER BY skin_id',
        (player_id,))]
