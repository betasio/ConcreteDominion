# World map: city operations

The World tab now previews all seven **solo NPC districts**. The optional online
faction server remains a separate system; these markers do not represent other
players or live multiplayer territory.

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
unchanged. This remains a stylized strategic map, not final illustrated city art.

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
