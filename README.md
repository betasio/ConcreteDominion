# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## District progression + live-event milestone

The World map now behaves like a progression ladder instead of a flat list of raid targets.

### District ladder

Current districts unlock through Account Level:

| Level | District | Target |
| ---: | --- | --- |
| 1 | Downtown Core | Downtown Bank |
| 2 | Harbor District | Harbor Bank |
| 4 | Northside | Northside Turf HQ |
| 5 | High Roller Strip | Casino Vault |
| 6 | Financial District | Financial Tower |

The Progression panel now shows this full district ladder.

## Defensive target modifiers

Higher districts now change encounter rules through data-driven target modifiers.

Each raid data resource owns:

- district name;
- base HP;
- HP multiplier;
- modifier name;
- modifier description;
- difficulty;
- unlock level;
- rewards and cooldown.

Current modifiers:

- **Downtown Bank** — Standard Security — no HP modifier
- **Harbor Bank** — Armored Doors — +5% effective HP
- **Northside Turf HQ** — Fortified Turf — +10% effective HP
- **Casino Vault** — Private Security — +15% effective HP
- **Financial Tower** — Hardened Vault — +20% effective HP

The raid lobby shows the district and modifier before launch, and target HP displays the effective HP after the modifier.

This keeps future encounter design data-driven: new modifiers can be added to raid resources without rebuilding the world-selection flow.

## Blackout Week event

A new 7-day prototype event is available through the **EVENT** shortcut.

Winning raids while the event is active awards **Event Marks**.

Current Mark rewards:

- Downtown Bank — 2 Marks
- Harbor Bank — 4 Marks
- Northside Turf HQ — 6 Marks
- Casino Vault — 9 Marks
- Financial Tower — 12 Marks

Harder districts therefore advance the event track faster.

## Event milestone track

Blackout Week currently has four claimable milestones:

### 5 Marks
- $2,500 Cash
- 30 XP

### 12 Marks
- 5 Gold
- Parts x2

### 25 Marks
- $7,500 Cash
- 100 XP
- Intel x2

### 45 Marks
- 15 Gold
- 180 XP
- Contraband x1

The event panel shows:

- event name;
- remaining days/hours;
- current Event Marks;
- milestone reward buttons.

Milestones can only be claimed once.

## Persistence

Save version 10 now also stores:

- event start timestamp;
- event end timestamp;
- Event Marks;
- claimed event milestones.

All previous profile, mailbox, alliance, progression, rewards, world, battle, and economy state remains in the same save.

## Architecture additions

```text
Main
├── EventManager
└── EventUI

scripts/events/
└── EventManager.gd

scripts/ui/
└── EventUI.gd

scenes/ui/
└── EventUI.tscn
```

`EventManager` listens to raid results and awards event progress.

`RaidTargetData` now contains district and modifier metadata.

`RaidTarget` calculates effective HP from the target's base HP and defense multiplier.

## Suggested future test path

When the full game is ready to test:

1. Open World view and compare district names/modifiers.
2. Preview Downtown and Harbor to compare effective HP.
3. Win raids and watch EVENT Marks increase.
4. Claim event milestones.
5. Level through Northside, Casino Vault, and Financial Tower.
6. Confirm stronger targets award Event Marks faster.
7. Restart and confirm event timer/Marks/claims persist.

## Production note

The event timer currently uses the local system clock and is client-authoritative.

For a live game, event start/end times, Event Marks, milestone claims, raid modifiers, and district eligibility must be server-authoritative.

## Next strong milestone

The next major gameplay step should add **strategic combat loadouts and target counterplay**:

- crew loadout presets;
- specialist equipment/perks;
- target weaknesses and recommended roles;
- optional consumable boosts;
- pre-raid risk/reward choices;
- post-raid performance grading;
- deeper wounded/healing severity.
