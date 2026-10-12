# Cash, Supplies, Intel and Diamonds

The player-facing resource identities are Cash, Supplies, Intel and Diamonds.
Diamonds use a red gemstone icon and are the optional premium currency. Supplies
use a strapped cargo crate. Inventory, operation rewards, costs, progression,
production summaries, events and the prototype store use the same names.

Existing balances are preserved: `gold` / `Gold` and `Parts` remain the internal
save, inventory and catalog keys. `ResourceIdentity.gd` maps those keys to display
names. This avoids resetting players or requiring a save migration. Prices and
ordinary building/recruitment timers are unchanged.

## Free and paid roles

Diamonds buy convenience through existing timer skips and instant healing.
Normal construction and recruitment use Cash and waiting; no premium-only unit,
building, or new power gate was introduced. The new-account grant remains 75.
Free earning paths remain:

| Source | Diamonds |
| --- | --- |
| Login cycle, day 3 / day 7 | 5 / 15 |
| Daily objective / full mastery | 3 / 2 |
| Weekly objective / full mastery | 15 / 5 |
| Event milestones | 5 and 15 |
| Chapters, achievements and comeback rewards | Existing finite or conditional rewards |

The recurring login + daily + weekly budget is up to 75 per seven-day cycle for
an active player, before events and one-time progression rewards. This is a
starting balance, not a revenue projection; retention and spending data should
guide later tuning. Existing construction speedups cost 2 per five-minute chunk.

Repeatable crafting no longer generates premium currency. Street Cache now pays
5,000 Cash + 60 XP (previously 3,500 Cash + 4 premium units); Syndicate Crate pays
12,500 Cash + 150 XP (previously 9,000 Cash + 12 premium units). Crafting input
costs are unchanged. The cash increase keeps ordinary resources useful while
avoiding an unlimited crafting-to-premium conversion.

The existing store catalog now describes Diamonds. Its prices remain examples
and purchasing remains disabled. Launching real purchases requires platform
billing, server-verified receipts, an idempotent entitlement ledger and refund
handling. Local save balances are a prototype implementation, not a secure
production wallet. Do not connect real payments to a client-only balance.

`ResourceEconomyAudit` verifies legacy balances, display mapping, free login,
daily and weekly rewards, duplicate-claim prevention, crafting payouts and
billing remaining disabled. It runs in CI.

## Flexible empire contracts

Daily and weekly rewards now count four activities: recruitment, NPC raid wins,
construction, and collecting produced Supplies/Intel. Complete **any two** for
the main reward or **any three** for the mastery bonus. Production requires two
collected goods daily and ten weekly, combined across Supplies and Intel from
core facilities or expansion districts. Collection works after offline income;
empty taps, Cash collections, raid loot and reward grants do not count. This
provides a peaceful route and an alternative once construction is exhausted.

The daily reward offers one fixed package, shown before claiming:

| Choice | Cash | Supplies | Intel | Diamonds | XP |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cash reserve (original payout) | 2,500 | 1 | 0 | 3 | 50 |
| Supply shipment | 1,000 | 3 | 0 | 3 | 50 |
| Intel dossier | 1,000 | 0 | 2 | 3 | 50 |

The choice trades Cash for ordinary materials. No paid rerolls or random rewards
are involved. The mastery and weekly payouts, login schedule and maximum free
Diamond budget remain unchanged. Rewards exposes the full payout and an estate
collection button. Claims refresh their period immediately, preserve the chosen
package in saves, and reject duplicate or invalid claims. Old saves default to
the original Cash package and zero production progress.

This is a local prototype economy. Real-money billing remains disabled; these
changes improve free-player choice without adding a paid progression gate.
