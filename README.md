# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Player progression milestone

The prototype now has a persistent account progression loop tied directly to raids, loot, unlocks, specialist upgrades, and tutorial-style missions.

### Account XP and levels

The player now has:

- Account Level
- current XP
- escalating XP required for the next level

Raid victories grant XP when the local player actually participated in the raid.

Current target progression:

| Target | Required level | XP reward |
| --- | ---: | ---: |
| Downtown Bank | 1 | 80 XP |
| Harbor Bank | 2 | 140 XP |
| Northside Turf HQ | 4 | 220 XP |

Locked targets remain visible in World view but clearly show their required account level.

## Building unlocks

Progression now gates specialist facilities:

- Garage — Account Lv.2
- Intel Office — Account Lv.3

Locked build lots show their level requirement directly on the Build button.

The core Safehouse, Clinic, and Barracks remain available from the beginning.

## Loot utility

Raid loot is no longer display-only.

The persistent loot inventory now supports spending:

- Parts
- Intel
- Contraband

Loot is consumed by specialist upgrades.

## Specialist upgrades

The **Progression** panel lets players upgrade:

- Enforcer
- Driver
- Spy

Driver upgrades increase the Driver raid multiplier.

Base Driver support:
- Lv.1: +15% per Driver slot
- each additional Driver level: +3%

Spy upgrades increase defense-break support.

Base Spy support:
- Lv.1: +18% per Spy slot
- each additional Spy level: +4%

Upgrade costs scale by level and consume different raid loot combinations.

This gives lower-power alliance support players a long-term progression path that improves their strategic value rather than merely increasing raw troop quantity.

## Tutorial / mission objectives

The first mission set now acts as a lightweight first-time-user progression guide:

### Grow the Crew
Recruit 5 troops.

Reward:
- 60 XP
- $1,500 Cash

### First Score
Defeat Downtown Bank.

Reward:
- 80 XP
- $2,500 Cash

### Make a Name
Reach Account Lv.2.

Reward:
- 40 XP
- $2,000 Cash

Mission state and completion are saved.

These objectives deliberately teach the existing gameplay loop:
recruit → raid → level up → unlock new content.

## Progression panel

A new responsive **Progression** shortcut shows the player's current account level.

Opening it displays:

- current level
- XP / next-level requirement
- upcoming unlocks
- mission progress
- Enforcer upgrade
- Driver upgrade
- Spy upgrade
- current loot costs

Upgrade buttons automatically disable when the required loot is unavailable.

## Raid progression UI

Raid panels now show:

- target HP
- difficulty
- Cash reward
- XP reward
- loot reward
- account-level requirement

The raid status clearly distinguishes:

- Ready
- Respawning
- Locked by account level
- Raid in progress

The animated result overlay also shows XP earned.

## Balance correction

The prototype alliance frontline member Vex is now set to **8,000 frontline power**.

With current base specialist bonuses:

- Vex alone cannot clear Downtown Bank.
- Vex + normal Driver/Spy support clears Downtown.
- Harbor benefits from filling the second Driver slot.
- Northside remains a later target requiring account progression and stronger specialist bonuses.

This better matches the intended design: frontline power matters, but coordinated support is required.

## Persistence

Save version 7 now includes:

- Account Level
- XP
- specialist upgrade levels
- mission progress/completion

All previous persistent systems remain intact:

- Cash and Gold
- loot
- troops
- buildings
- construction/recruitment/healing queues
- raid state
- target cooldowns
- alliance roster/slots/social feed
- Base/World view

## Suggested test

1. Open **Progression** and review the three tutorial missions.
2. Recruit 5 troops and confirm **Grow the Crew** completes.
3. Switch to **WORLD** and inspect Harbor Bank; it should show **Lv.2 required**.
4. Raid Downtown Bank with alliance support.
5. Confirm the result overlay grants XP.
6. Reopen **Progression** and watch account XP/mission state update.
7. Reach Lv.2 and confirm Harbor Bank + Garage unlock.
8. Earn Parts/Intel from raids.
9. Spend loot upgrading Driver or Spy.
10. Preview another raid and verify the support percentage increases.
11. Restart and verify level, XP, upgrades, and missions persist.

## Architecture additions

```text
Main
├── PlayerEconomy
├── LootInventory
├── PlayerProgression
├── MissionTracker
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
└── ProgressionUI
```

New scripts:

```text
scripts/progression/
├── PlayerProgression.gd
└── MissionTracker.gd

scripts/ui/
└── ProgressionUI.gd

scenes/ui/
└── ProgressionUI.tscn
```

Raid target data resources now own both `reward_xp` and `required_account_level`, keeping the progression ladder data-driven.

## Production direction

This progression model is still intentionally local/client-authoritative.

Before live multiplayer or real-money monetization, XP, levels, mission completion, loot spending, specialist upgrades, unlock eligibility, and raid rewards should all be validated server-side.

## Next strong milestone

A strong next step is the first **content/retention layer**:

- daily and weekly objectives;
- daily login rewards;
- reward crates that consume Parts/Intel/Contraband;
- player profile/name/avatar;
- achievements;
- tutorial callouts/highlights;
- additional data-driven raid targets and district expansion.
