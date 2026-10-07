# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with Godot 4 and GDScript.

## Core city progression milestone

The three starting buildings now have real long-term gameplay effects instead of only level numbers.

### Safehouse

Safehouse upgrades now provide:

- 4% construction-time reduction per level above Lv.1;
- 2% Alliance Raid Cash reward bonus per level above Lv.1.

Construction-speed reduction is centrally capped through GameBalance.

Current Safehouse upgrade defaults:

- base upgrade cost: $8,000 x current level;
- base upgrade duration: 20 seconds x current level before Safehouse reduction;
- max level: 5.

### Underground Clinic

Clinic upgrades now provide:

- 8% treatment-time reduction per level above Lv.1;
- additional parallel treatment capacity.

Treatment slots:

- Lv.1–2: 1 slot;
- Lv.3–4: 2 slots;
- Lv.5: 3 slots.

The no-permanent-death rule remains unchanged. More Clinic levels only reduce downtime and allow more wounded groups to recover simultaneously.

Current Clinic upgrade defaults:

- base upgrade cost: $7,000 x current level;
- base upgrade duration: 18 seconds x current level;
- max level: 5.

### Crew Barracks

Barracks upgrades now provide:

- 5% Enforcer recruitment-time reduction per level above Lv.1;
- increased recruitment queue capacity.

Recruitment queue capacity:

- Lv.1–2: 1 job;
- Lv.3–4: 2 jobs;
- Lv.5: 3 jobs.

Driver and Spy training-time bonuses still come from Garage and Intel Office progression, so each building retains a distinct purpose.

The recruitment queue now persists both the active job and waiting jobs and processes them sequentially, including offline progression.

## Central balance

Core-building tuning now lives in GameBalance alongside the existing recruitment, facility, progression, and Gold speed-up values.

Current defaults:

- Safehouse construction reduction: 4% per level;
- Safehouse raid-Cash bonus: 2% per level;
- Clinic healing reduction: 8% per level;
- Clinic minimum healing multiplier: 0.60;
- Barracks Enforcer training reduction: 5% per level;
- Barracks minimum training multiplier: 0.70.

## Alliance progression

The mock Alliance now has persistent:

- Alliance Level;
- Alliance XP;
- level-up thresholds;
- frontline command bonus;
- unlockable raid slots.

Winning Alliance Raids grants Alliance XP based on target tier.

Current Alliance XP rewards:

- Downtown: 20
- Harbor: 28
- Midtown: 34
- Northside: 42
- Casino: 52
- Financial: 64
- Industrial: 78

Each Alliance Level above Lv.1 increases NPC frontline power by 2%.

Raid-slot unlocks:

- Alliance Lv.1: Frontline + Driver + Spy + Driver
- Alliance Lv.2: unlock an additional Spy slot
- Alliance Lv.4: unlock an additional Driver slot

This deepens the original synergy design: alliance progression creates more room for support players rather than simply replacing them with higher raw power.

Alliance Level, XP, slot state, and online member state are persistent.

## District mission chain

The mission system now extends beyond the opening tutorial.

New missions include:

- Wheels Up — build the Garage
- Midtown Pressure — defeat Midtown Exchange
- Eyes Everywhere — build the Intel Office
- Take Northside — defeat Northside Turf HQ
- Break the House — defeat Casino Vault
- Own the Skyline — defeat Financial Tower
- Control the Supply — defeat Industrial Depot

They award additional Cash and Account XP while guiding the player through the district ladder.

Existing saves with an already-built Garage or Intel Office automatically receive the corresponding mission progress when MissionTracker initializes.

## HUD updates

Core-building selection now shows the building's current functional bonuses.

The Clinic panel shows current treatment-slot capacity.

The Barracks panel shows:

- recruitment queue capacity;
- active job;
- waiting-job count;
- queue usage.

The Alliance Hub now shows Alliance Level, Alliance XP, frontline command bonus, and current slot count above the social feed.

## Persistence

Save schema is now version 14.

The existing save structure already owns:

- Safehouse level;
- Clinic level;
- Barracks level;
- Alliance state;
- recruitment state.

Recruitment save data now supports an active job plus a waiting queue.

The loader remains compatible with the older single-job recruitment save format.

## Architecture addition

```text
scripts/buildings/
└── CoreBuildingEffects.gd

Main
├── CoreBuildingEffects
├── FacilityEffects
├── ConstructionQueue
├── RecruitmentQueue
├── HospitalQueue
└── AllianceManager
```

CoreBuildingEffects reads the saved building levels and exposes their effects to construction, recruitment, healing, raid rewards, and HUD presentation.

## Future final-test path

When full testing begins:

1. Upgrade Safehouse and compare construction durations.
2. Win raids before/after Safehouse upgrades and compare reward pools.
3. Upgrade Clinic to Lv.3 and confirm two wounded entries recover simultaneously.
4. Upgrade Clinic to Lv.5 and confirm three treatment slots.
5. Upgrade Barracks to Lv.3 and queue two recruitment jobs.
6. Upgrade Barracks to Lv.5 and queue three jobs.
7. Close/reopen during a queued recruitment chain and verify offline processing.
8. Complete Garage/Intel and district missions.
9. Win raids until Alliance Lv.2 and verify the extra Spy slot.
10. Reach Alliance Lv.4 and verify the extra Driver slot.
11. Restart and confirm all building, queue, mission, and Alliance progression persists.
12. Run the smoke-test scene before the manual playthrough.

## Next development direction

The next strong milestone is broader endgame/content completion:

- Safehouse command features beyond passive bonuses;
- more alliance members and alliance tasks;
- resource production/collection;
- district ownership/turf control;
- PvE patrol encounters;
- map fog/intel discovery;
- more building slots;
- localization-ready content data;
- balance simulation and final QA.
