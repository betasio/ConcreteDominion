# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Retention and content-loop milestone

The prototype now has a persistent rewards/objectives layer built on top of the existing progression, alliance, raid, and loot systems.

## Daily login rewards

The new **Rewards** panel contains a 7-day login reward cycle.

Current cycle:

1. $1,500 Cash
2. Parts x2
3. 5 Gold
4. Intel x2
5. $3,000 Cash + 40 XP
6. Parts x3 + Intel x1
7. 15 Gold + Contraband x1 + 100 XP

Consecutive daily claims increase the login streak.

Missing a day resets the streak back to day 1.

The prototype uses a UTC-style day index from the system clock. This is appropriate for a local prototype, but live rewards should use server timestamps.

## Daily objectives

Daily progress resets automatically when the calendar day changes.

Current daily goals:

- Recruit 3 troops
- Win 1 raid

Daily completion reward:

- $2,500 Cash
- 3 Gold
- 50 XP
- Parts x1

## Weekly objectives

Weekly progress resets on a seven-day period boundary.

Current weekly goals:

- Recruit 15 troops
- Win 5 raids

Weekly completion reward:

- $10,000 Cash
- 15 Gold
- 200 XP
- Parts x3
- Intel x2
- Contraband x1

## Reward crates

Raid loot can now be converted into deterministic reward crates.

### Street Cache

Cost:

- Parts x3
- Intel x1

Reward:

- $3,500 Cash
- 4 Gold
- 60 XP

### Syndicate Crate

Cost:

- Parts x5
- Intel x3
- Contraband x1

Reward:

- $9,000 Cash
- 12 Gold
- 150 XP

These crates create an additional loot sink beyond specialist upgrades.

## Achievements

The first persistent achievements are now tracked:

- **First Blood** — win a raid
- **Crew Builder** — recruit 20 troops
- **Specialist** — upgrade any specialist
- **Known Name** — reach Account Lv.3

Achievements award small one-time bonuses such as Gold, Cash, XP, or Intel.

Achievement completion is saved permanently.

## Tutorial callout

A persistent tutorial banner now guides the early progression flow.

It advances through practical actions:

1. Recruit 5 troops
2. Switch to World view and defeat Downtown Bank
3. Reach Account Lv.2
4. Upgrade Driver support
5. Continue into higher-tier alliance progression

This gives the prototype a lightweight first-time-user experience without locking the player into modal tutorial screens.

## UI

A new **Rewards** shortcut opens the retention panel.

The panel shows:

- current login streak
- login reward claim button
- daily objective progress
- weekly objective progress
- crate crafting
- achievement status

The tutorial hint remains visible separately so the player's next step is always readable.

## Persistence

Save version 8 now also stores:

- last login claim day
- login streak
- daily objective period/progress
- weekly objective period/progress
- objective reward claim state
- lifetime recruit count
- lifetime raid wins
- achievement unlocks

All previous save data remains part of the same save document.

## Architecture

```text
Main
├── PlayerEconomy
├── LootInventory
├── PlayerProgression
├── MissionTracker
├── RetentionManager
├── AllianceManager
├── AllianceSocial
├── TroopRoster
├── HospitalQueue
├── ConstructionQueue
├── RecruitmentQueue
├── SynergyRaid
├── RaidBattle
├── SaveManager
├── CityMap
├── HUD
├── ProgressionUI
└── RetentionUI
```

New files:

```text
scripts/retention/
└── RetentionManager.gd

scripts/ui/
└── RetentionUI.gd

scenes/ui/
└── RetentionUI.tscn
```

`RetentionManager` listens to recruitment, raid resolution, specialist progression, and account-level events. It does not own those systems.

That separation makes it possible to replace local timers/reward validation with backend-driven live-ops state later.

## Suggested test

1. Open **Rewards** and claim today's login reward.
2. Recruit 3+ troops and check daily/weekly progress.
3. Win Downtown Bank and confirm raid-win objectives advance.
4. Claim the daily reward after both daily goals are complete.
5. Accumulate Parts/Intel and craft a Street Cache.
6. Upgrade a specialist and check the Specialist achievement.
7. Recruit 20 total troops and check Crew Builder.
8. Restart and confirm streak/objectives/achievements persist.

## Security / production note

Daily rewards currently rely on the local system clock and all reward state is client-authoritative.

Before live release, login claims, day/week boundaries, achievements, objective progress, crate crafting, XP, currencies, and loot should be server-authoritative to prevent clock manipulation or save editing.

## Next strong milestone

The next logical feature step is **player identity and deeper content**:

- editable player name/profile;
- portrait/avatar selection;
- player power summary;
- alliance profile page;
- additional data-driven world targets;
- district unlocks;
- achievement/profile badges;
- mail/inbox rewards;
- event-style limited objectives.
