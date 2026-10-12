# Gated estate districts

The estate now uses `expanded_estate.png`, a continuous land foundation with water behind HQ. Animated open water surrounds the side cliffs on wide PC windows; small boats follow offshore routes with wakes. The surrounding forest backplate is no longer rendered. Terrain and water stay fixed in world coordinates, and a narrow edge blend conceals the texture boundary. Water, boats, road traffic and plot fog use the existing reduced-motion clock. The camera limits its visible southern edge to the terrain boundary at every zoom, accounting for the HUD, while preserving the portrait starting zoom. The top resource order is Cash, Supplies, Intel, Diamonds.

## Layout and progression

- Inside the gate: HQ, Garage (Driver support), Intel Office (Spy support), Data Hub (Intel and radar), and the new Rally Hall.
- First outer row: the existing Clinic, Barracks and Scrapyard. Their node IDs and upgrade levels are retained in old saves.
- Garden row: three flexible plots after completing Chapter 2.
- South row: three flexible plots after completing Chapter 4.
- Each flexible plot can become a Cash Business, Supply Depot, Intel Exchange, Hospital or Barracks. There is no Diamond producer. Buildings cannot be replaced once construction starts.
- The Districts HUD shortcut opens the plot list, production collection and a camera shortcut to the outer estate. PC opens on the command estate; phone portrait includes the expansion rows. Drag or zoom to inspect the grounds.

New buildings cost $7,000 / 60 seconds. Upgrades use $5,000 and 90 seconds times the current level, modified by HQ/faction construction effects. Maximum level is five. The gate and Rally Hall start at level one.

## Additive effects

| Facility | Effect per level |
| --- | --- |
| Cash Business | $1,200/hour, six-hour storage |
| Supply Depot | 2 Supplies/hour, six-hour storage |
| Intel Exchange | 1 Intel/hour, six-hour storage |
| Hospital | 25 casualty beds; each building adds one treatment lane |
| Barracks | 10 troops per training batch, 3% training reduction; each building adds one queue slot |
| Gate | 4% local war defense and reduced local raid wound severity |
| Rally Hall | Local rally member capacity +1 and command power +3% |

The starting Clinic and Barracks also supply 25 beds and 10 batch capacity per level. Training reductions retain a 30% building-effect cap. The full-batch recruitment button uses the new capacity. Hospital admission removes wounded troops from the ready roster, admits only free beds, and records excess as permanent overflow losses. The Clinic and Hospital panels disclose capacity/overflow. Existing patients are retained across upgrades and loads, including saves already above capacity.

Plot type, level, Cash storage and in-progress construction use the existing save/queue lifecycle. Offline production is capped at six hours, and fractional collection balances are retained. Invalid/locked plot construction is rejected before spending Cash.

## Faction rallies and radar

NPC raid entry remains available without faction membership. Online PvP uses the existing optional development backend and matched factions. In Online → Wars, select 1, 3 or 5 minutes of preparation and a strategy. Authenticated members join their own faction's rally. A server timer departs it automatically, including when the leader disconnects, and persists/replays combat receipts across restart. Late joins, outsiders, duplicate joins and capacity overflow are rejected. Participants each contribute an attack under the existing three-attacks-per-player and six-per-faction match budgets. A departing rally cannot transfer to a later match. This is scored faction combat, not an implemented march against a player's physical estate or a live troop-loss simulation.

Defenders receive an incoming alert while connected, polled every five seconds. Without a Data Hub, it warns of the threat and timer. Data Hub level one identifies the faction; level two reveals strategy and members. These are presentation unlocks, not secrecy guarantees against a modified client.

Offline estate progression is not authoritative online. The online Rally Hall starts at level one and increases with server-recorded faction wins (maximum five); capacity is 3 + level, further bounded by available match attacks. Its progression is separate from the local building. Local gate defence likewise does not alter online match scores. Synchronizing player estates, resource spending, hospital casualties and building upgrades to a production backend remains future work. The existing direct PvP development endpoint remains available for older clients/tests; the new Wars buttons prepare rallies.

## QA

- `EstateDistrictAudit`: chapter locks, rejection before spending, offline construction restore, production caps/collection, additive beds/training, gate and command upgrades, modal input blocking.
- Existing resource, balance, camera, artwork, estate interaction, HUD, economy and gameplay regression audits.
- `server.test_rallies`: membership, real joins, alerts, preparation validation, concurrency/capacity, cancellation, late joins, departure, restart, receipt replay and match identity.
- `IllustratedEstateScreenshot`: PC 1080p, phone portrait/landscape, locked and developed districts, plot management and upgrade dialogs. Output is under ignored `build/previews/`.
