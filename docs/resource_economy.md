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
