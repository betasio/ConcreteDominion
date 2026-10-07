# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Functional facilities + economy content milestone

This milestone turns the Garage and Intel Office from visual build-lot completions into real progression systems, expands the district ladder, and adds a non-transactional store prototype.

## Functional Garage

The Garage unlocks at Account Lv.2.

After construction it becomes an upgradeable facility up to Lv.5.

Each Garage level currently provides:

- +2% Driver support effectiveness in Alliance Raids;
- -5% Driver recruitment time.

The training reduction is capped through the shared balance configuration so future tuning cannot reduce training time indefinitely.

Garage upgrades use the existing Construction Queue, Cash costs, timers, and Gold Finish Now system.

## Functional Intel Office

The Intel Office unlocks at Account Lv.3.

After construction it also upgrades to Lv.5.

Each Intel Office level currently provides:

- +2.5% Spy support effectiveness in Alliance Raids;
- -5% Spy recruitment time.

Like the Garage, all upgrades use the normal construction queue rather than a separate upgrade system.

## Facility UI

Selecting a completed Garage or Intel Office now shows:

- current facility level;
- active raid-support bonus;
- training-time reduction;
- next upgrade Cash cost;
- MAX LEVEL state;
- construction progress while upgrading.

This means completed build lots are now meaningful long-term city assets instead of one-time construction objectives.

## Central facility balance

Facility tuning lives in `GameBalance.gd`.

Current defaults:

- Garage Driver support: +2% per level
- Garage Driver training reduction: 5% per level
- Intel Office Spy support: +2.5% per level
- Intel Office Spy training reduction: 5% per level
- minimum specialist training-time multiplier: 0.70

The diagnostics panel now includes facility tuning alongside recruitment and Gold speed-up values.

## Expanded district ladder

Two additional data-driven raid targets fill progression gaps.

### Midtown Exchange — Account Lv.3

- District: Midtown
- Hard difficulty
- Layered Surveillance
- 8% defensive HP modifier
- Spy weakness
- +10% counter bonus
- $12,500 Cash
- 180 XP
- Parts x3
- Intel x2

### Industrial Depot — Account Lv.7

- District: Industrial Belt
- Mythic difficulty
- Heavy Barriers
- 18% defensive HP modifier
- Driver weakness
- +16% counter bonus
- $38,000 Cash
- 520 XP
- Parts x7
- Intel x4
- Contraband x2

The complete progression ladder is now:

1. Lv.1 — Downtown Core
2. Lv.2 — Harbor District + Garage
3. Lv.3 — Midtown + Intel Office
4. Lv.4 — Northside
5. Lv.5 — High Roller Strip
6. Lv.6 — Financial District
7. Lv.7 — Industrial Belt

Both new targets have their own world-map positions, convoy routes, cooldowns, event rewards, target weaknesses, save state, and progression gates.

## Blackout Week expansion

The event system now recognizes the new raid targets.

Event Marks:

- Downtown Bank — 2
- Harbor Bank — 4
- Midtown Exchange — 5
- Northside Turf HQ — 6
- Casino Vault — 9
- Financial Tower — 12
- Industrial Depot — 15

This gives higher progression tiers stronger event efficiency without creating exclusive event-only combat stats.

## Prototype store

A new **Store** screen is included for monetization UX planning.

Current example offers:

- Gold Starter
- Builder Pack
- Crew Support Pack
- Recovery Pack

The catalog intentionally focuses on:

- Gold;
- construction progression;
- queue speed-ups;
- ordinary progression materials.

It does **not** sell exclusive troops, exclusive raid roles, or unique combat power.

### Important

Real-money purchases are deliberately disabled.

Every offer displays:

**Purchases Disabled — Prototype Catalog**

There is currently:

- no billing SDK;
- no payment request;
- no receipt validation;
- no platform-store transaction;
- no real-money grant logic.

The price labels are example UX placeholders only.

This lets the economy/store experience be designed before introducing platform billing or server-authoritative entitlement validation.

## Persistence

Save schema is now **version 13**.

City save data now includes:

- Garage built state;
- Garage level;
- Intel Office built state;
- Intel Office level.

Older saves with already-built facilities automatically migrate those facilities to Lv.1.

The Store has no purchase state because billing is not connected.

## Architecture additions

```text
Main
├── FacilityEffects
├── StoreManager
└── StoreUI

scripts/buildings/
├── BuildLot.gd
└── FacilityEffects.gd

scripts/store/
└── StoreManager.gd

scripts/ui/
└── StoreUI.gd

scenes/ui/
└── StoreUI.tscn

data/raids/
├── midtown_exchange.tres
└── industrial_depot.tres
```

## Design intent

The facility system reinforces the original alliance philosophy:

- specialist players become more valuable through city investment;
- Garage progression improves Driver support rather than replacing frontline strength;
- Intel Office progression improves Spy support rather than creating a solo-win mechanic;
- whales still benefit from strong frontline progression;
- coordinated specialist roles remain strategically important.

The store follows the same philosophy: pay for progression/time convenience, not exclusive battlefield participation.

## Future final-test path

When the full game is ready for testing:

1. Reach Lv.2 and build the Garage.
2. Recruit Drivers before and after Garage upgrades and compare training time.
3. Preview a raid and confirm Driver support increases per Garage level.
4. Reach Lv.3 and build the Intel Office.
5. Repeat the same test with Spies.
6. Upgrade each facility through multiple levels.
7. Restart and confirm facility levels persist.
8. Raid Midtown Exchange.
9. Progress to Lv.7 and verify Industrial Depot unlocks.
10. Open Store and confirm every real-money action remains disabled.
11. Run the smoke test and confirm FacilityEffects, StoreManager, and StoreUI exist.

## Next strong milestone

The strongest remaining development direction is **content completion and economy depth**:

- functional Safehouse bonuses;
- functional Clinic and Barracks level effects;
- multiple construction/recruitment queue unlocks;
- district-specific missions;
- additional alliance progression;
- economy simulation/balance checks;
- real art/audio replacement hooks;
- localization-ready text data;
- broader final QA and device testing.
