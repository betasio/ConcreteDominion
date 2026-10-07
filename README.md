# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with Godot 4 and GDScript.

## Rival factions + contested turf milestone

The World map now supports persistent rival crews, visible ownership states, contested turf pressure, richer PvE encounters, resource-production facilities, and renewable Alliance tasks.

## Rival factions

Discovered districts that the player has not yet captured now show a named rival owner.

Current prototype factions:

- Downtown Core — Dock Rats
- Harbor District — Iron Serpents
- Midtown — Meridian Boys
- Northside — Northside Crew
- High Roller Strip — Velvet Circle
- Financial District — Velvet Circle
- Industrial Belt — Iron Serpents

Capturing the district through its normal Alliance Raid transfers the turf to the player.

## Turf pressure

Owned districts now accumulate rival pressure while the game is active.

Pressure does not automatically delete ownership.

When pressure reaches 100%, the district becomes **CONTESTED** and generates a dedicated turf-push encounter.

Contested districts:

- remain owned by the player;
- continue producing Cash at 65% of normal output;
- display an orange ownership ring and pressure state;
- return to normal after a successful turf defense.

If the player loses a turf-push encounter, ownership is still retained. Pressure falls to 80% so the player has time to rebuild and try again.

Offline pressure is deliberately capped below the contested threshold. Returning after a break therefore never causes automatic territory loss or an unavoidable instant defeat.

## Territory overlays

The World map now draws procedural ownership overlays around discovered targets.

Colors indicate:

- green — player-controlled turf;
- red — rival-controlled discovered district;
- orange — contested player turf.

Owned districts also display their current pressure bar and ownership label.

No imported map textures are required.

## Richer rival encounters

World encounters now rotate between troop-role requirements.

### Roadblock
Uses Enforcer power.

### Surveillance Sweep
Uses Spy power and can reward Intel.

### Convoy Ambush
Uses Driver power and can reward Parts.

### Turf Push
Triggered by 100% district pressure and uses Enforcer power at increased difficulty.

This gives the existing specialist roster more purpose outside Alliance Raids.

Failure still follows the no-permanent-death rule. At most one relevant participating troop enters the Clinic.

## Resource-production buildings

Two additional base build lots are now available.

### Scrapyard — Account Lv.4

Produces Parts.

Current rate:

- +2 Parts/hour per building level;
- maximum level 5;
- six-hour resource bank.

### Data Hub — Account Lv.5

Produces Intel.

Current rate:

- +1 Intel/hour per building level;
- maximum level 5;
- six-hour resource bank.

Both facilities:

- use the existing Construction Queue;
- use normal Cash upgrade costs/timers;
- support Gold Finish Now through the shared construction system;
- generate resources while offline;
- persist build state, level, and banked output.

The Territory panel contains a single collection action for both resource facilities.

## Updated city unlock ladder

- Lv.2 — Harbor District + Garage
- Lv.3 — Midtown + Intel Office
- Lv.4 — Northside + Scrapyard
- Lv.5 — High Roller Strip + Data Hub
- Lv.6 — Financial District
- Lv.7 — Industrial Belt

## Renewable Alliance tasks

Alliance tasks now refresh on a 24-hour cycle instead of remaining permanently completed.

The panel displays the live refresh countdown.

Existing tasks still reward Cash and Alliance XP:

- Hit the Streets — raid wins
- Keep It Moving — turf-income collections
- Clean the Block — rival encounter clears

Task-cycle timing is persistent and advances across offline time.

## Territory income behavior

Normal turf Cash production remains capped at eight hours.

Contested districts reduce only current production rate. Previously banked Cash is preserved and is not destroyed when a district becomes contested.

## Persistence

Save schema is now **version 16**.

New persistent state includes:

- Scrapyard built state and level;
- Data Hub built state and level;
- Parts resource bank;
- Intel resource bank;
- resource-production timing;
- rival pressure per district;
- contested states;
- encounter rotation;
- active encounter details;
- Alliance task refresh timer.

Older saves default the new resource facilities to unbuilt and safely initialize the new banks.

## Architecture additions

```text
CityMap
├── Buildings
│   ├── BuildLotC → Scrapyard
│   └── BuildLotD → Data Hub
└── TurfOverlay

Main
├── WorldControlManager
└── ResourceProductionManager

scripts/buildings/
└── ResourceProductionManager.gd

scripts/world/
├── WorldControlManager.gd
└── TurfOverlay.gd
```

## Recommended future test path

When final testing begins:

1. Reach Lv.4 and build Scrapyard.
2. Confirm Parts production begins and survives restart/offline time.
3. Reach Lv.5 and build Data Hub.
4. Confirm Intel production and the six-hour cap.
5. Enter World view and verify red rival ownership rings.
6. Capture a district and verify its overlay turns green.
7. Allow pressure to increase and confirm its pressure bar.
8. Reach 100% pressure and confirm a turf-push encounter appears.
9. Win the defense and verify pressure drops and full income returns.
10. Lose a turf defense and confirm the district remains owned.
11. Clear Roadblock, Surveillance Sweep, and Convoy Ambush encounters with their matching troop roles.
12. Verify Surveillance rewards Intel and Convoy Ambush can reward Parts.
13. Complete Alliance tasks and confirm they reset when the refresh cycle expires.
14. Restart with active pressure/encounter/task timers and confirm persistence.
15. Run the smoke-test scene.

## Next development direction

The strongest next milestone is approaching final content and QA:

- additional NPC faction personalities and progression;
- district-specific encounter modifiers;
- more city build lots and visual variety;
- localization-ready text resources;
- economy/balance simulation;
- real audio/art replacement;
- tutorial/onboarding polish;
- achievement/endgame goals;
- automated CI smoke testing;
- full Godot runtime and device QA.
