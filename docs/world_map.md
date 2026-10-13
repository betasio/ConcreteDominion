# World map: city operations

The World tab opens **Faction city** with original mansion, neighborhood and
landmark artwork. Green means your own estate, blue a member of your online
faction, and orange another faction or an independent player. Names and relations
come from authenticated server records. A disconnected client shows only its own
local turf and landmark previews; it never invents factionmates.

The **NPC districts** tab preserves all seven solo districts and their discovery,
raid and income systems. They remain separate from online landmark competitions.

- Choose a district in City Operations, or tap an unscouted map marker. Previewing
  shows its account-level gate and base income without spending or launching.
- Once eligible, use a free Command Scan or the explicitly priced Intel action.
  Free scans can target the selected district and retain the existing shared
  cooldown (10 minutes at HQ level 1, reduced by HQ upgrades). Existing automatic
  scan callers still reveal the next eligible district.
- Plan Raid opens the normal troop/loadout preparation and readiness checks.
  Capture, contest pressure, patrols and hourly Cash keep their existing rules.
- The collection button pays the existing accumulated turf bank once. Base income
  in a preview is a potential rate; the collection row shows current effective
  income, including contested districts and existing bonuses.
- Undiscovered opponents remain hidden; gray district markers disclose only the
  district name and level requirement. Gold indicates the selected preview.

Presentation changes restore district scenery and moving traffic, replace
incorrect street-atlas cutouts with continuous lane markings, fix tower windows,
add a harbor/quay surround and bound world navigation. Portrait zoom keeps targets
readable. The estate's artwork, building positions and road-edge camera rule are
unchanged. Generated building and ground art now replace the placeholder skyline. Asset
provenance and atlas regions are recorded in `assets/world/city/README.md`.

## Verification

Run with a fresh `XDG_DATA_HOME` to isolate test saves:

```sh
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . res://scenes/tests/WorldMapAudit.tscn
```

The audit covers non-mutating previews, marker taps versus drags, account gates,
selected free scans, reentrant scan prevention, exact Intel costs, duplicate
rejection, raid preparation, one-time income collection, persisted discovery and
cooldowns, five UI sizes, portrait target readability, bounds and estate isolation.
It is registered in GitHub QA. Local rendered checks cover 1280×720 desktop and
390×844 portrait. Existing functionality, camera, HUD and long-horizon gameplay
audits also cover the affected integration.

Next: connect a separate strategic overview to server-owned faction rallies and
incoming attacks after verified identity and authoritative estate progression are
ready. Keep NPC progression available solo. Do not present local city ownership as
competitive multiplayer state.


## Landmark campaigns (private playtest)

| Landmark | First opening | Purpose |
| --- | ---: | --- |
| Underground Exchange | Server age 30 days | First faction ownership contest |
| Port Authority | Server age 45 days | Second strategic landmark |
| City Hall | Server age 60 days | Ownership and mayor appointment |

The server stores its opening timestamp once when this migration first runs.
Each landmark opens for two hours and then every seven days. The UI displays the
server-provided phase, countdown, owner, top three scores and remaining orders.
Restarting the server or changing the device clock does not restart the schedule.

During an open window, faction members issue Muscle, Convoy or Intel orders.
Each faction can field six commanders, each with three orders and a five-minute
cooldown. The published garrison has a tactical counter: counter/equal/other plans
score 150/100/75. Only server rules determine scores. Neither purchases nor local
army power contribute. These are an initial equal-strength command contest;
landmark marches, garrisons and real troop casualties are not implemented yet.

At the deadline the unique highest-scoring faction takes ownership. A tied
contested round grants no ownership. The holder remains through peace and the
following contest until its settlement; an uncontested week preserves the last
holder. City Hall's winning faction leader can appoint any current faction member
as mayor during peace. A new result resets the appointment. Ownership and mayor
are prestige features for now: they do not mint currency or modify combat stats.

Estates have stable server-assigned slots in 24-player sectors. The client shows
the signed-in player's sector; cross-sector browsing and relocation are future
work. All sectors share the server's three landmark contests. Live data refreshes
on entry, explicitly, and every 30 seconds while the city panel is visible.

Use World → Faction city → Connect city to access the existing private-server
account flow. Without a hosted server, city art and landmark previews work offline;
real factionmates and timed competition require that connection.

## Connected validation

```sh
python3 -m unittest server.test_world -v
python3 tools/online_world_probe.py
# With a display server: captures desktop, portrait and rotated-phone views.
python3 tools/online_world_probe.py --render
```

The probe provisions nine real test accounts across two factions plus an
independent player in a disposable loopback server. It checks relationship colors,
authoritative order scoring and replay, local economy isolation, account clearing,
NPC/online mode separation and responsive layouts. Test-only clock advancement
opens City Hall; there is no public clock-advance API. CI runs both the server
checks and Godot probe, and uploads the rendered city screenshots.

## Turf collection and larger landmarks

The city now uses a 36×31 grid with 24 stable player slots and reserved civic
compounds. New landmark artwork is about 2.2 times the width of a player turf.
The camera fits selected landmarks beside desktop controls or below portrait
controls. The expanded grid is only for faction-city mode; NPC districts and
home-estate placement retain their existing coordinates.

Open **World → Faction city → Turf collection** (also available through Store).
The default Heritage appearance follows the local HQ: villa at levels 1–2,
mansion at 3–4, palace at 5+. Other players use the starter appearance until the
server supplies authoritative HQ progression; their levels are not fabricated.
The local equipped appearance is not yet synchronized to other clients.

| Skin | Availability | Equipped bonus |
| --- | --- | --- |
| Heritage Estate | Free | HQ-dependent appearance |
| Vanguard Estate | HQ 3, free | +10% NPC raid damage |
| Founder's Estate | HQ 5, free | +10% facility production |
| Crimson Citadel | Future verified purchase | +10% NPC raid damage |
| Emerald Exchange | Future verified purchase | +10% facility production |

Only the equipped, unlocked skin grants its bonus. Owning extra skins never stacks
power. Raid damage is captured when the raid starts. Production applies to Cash
businesses, Supplies facilities and Intel facilities, including offline accrual;
it never produces Diamonds or boosts reward payouts. Fractions survive collection
(e.g. 1 Intel/hour becomes 1.1). Accrual stops at six hours of the current rate;
changing skins preserves already-earned stock. Save version 36 stores the selected
skin, not purchase ownership. Existing saves default to Heritage.

Paid skins are previews, **not purchasable yet**. There is no billing provider,
receipt-verification webhook, refund integration or client purchase/grant API.
The authenticated world response reads active `skin_entitlements` belonging to
that account; nothing in a local save grants premium ownership. Logout, invalid
credentials and refreshed revocations remove access. Premium skins require an
online ownership refresh after restart, so they do not grant offline-load bonuses.
Verified billing and durable offline entitlements remain release prerequisites.

This first skin implementation intentionally affects local NPC combat and
facility production only. Online PvP and equal-strength landmark orders receive
no skin multiplier. Defence/HP skins need real combat-health and defensive-army
models before they can be sold with those claims.

Validation: `TurfSkinAudit.tscn` checks HQ transitions, actual raid damage, exclusive
bonuses, fractional offline production, preserved stored resources, save/load,
forged ownership rejection and account clearing. The server world suite checks
receipt ownership isolation, persistence, revocation and unchanged contest scores.
