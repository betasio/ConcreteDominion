# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Alliance raid milestone

Raids now use an explicit alliance roster and role-slot lobby instead of anonymous support counters.

### Prototype alliance roster

The local prototype includes simulated alliance members:

- **Vex** — Lv.45 — Frontline — 8,500 power — online
- **Mia** — Lv.17 — Driver — online
- **Noah** — Lv.14 — Spy — online
- **Kira** — Lv.12 — Driver — starts offline
- **You** — Lv.12 — selectable Driver or Spy support

The lobby shows each member's online/offline state.

A prototype **Toggle Kira Online / Offline** button lets you test how member availability changes slot filling and expected raid damage.

## Raid slots

Each alliance raid currently has four slots:

1. Frontline
2. Driver
3. Spy
4. Driver

Online simulated allies auto-fill compatible empty slots.

The local player can take a Driver or Spy slot if they own at least one matching specialist troop.

Raid participants are frozen when the raid launches. Going online/offline after launch does not rewrite who participated or who earned rewards.

## Contribution scores

Each participant now receives a contribution score.

- Frontline contribution is based on the strongest frontline power.
- Each Driver contributes the damage value created by the Driver support multiplier.
- Each Spy contributes the damage value created by the Spy defense-break multiplier.

Current prototype support values:

- Driver: **+15%**
- Spy: **+18%**

The raid preview shows named member contribution scores.

## Shared rewards

Cash rewards are now an **alliance reward pool**, not a single-player payout.

The prototype split uses:

- 50% of the reward pool divided equally among participating members
- 50% divided proportionally by contribution score

This intentionally gives support players a meaningful baseline reward while still rewarding the member supplying frontline power.

Only the local player's share is added to the local Cash balance. Simulated allies' shares are shown in the result panel.

Target loot drops such as Parts, Intel, and Contraband are granted to the local player only when the local player actually occupied a raid slot.

## Balance progression

Current frontline/support tuning creates this progression:

- Vex alone: 8,500 damage — cannot beat Downtown Bank
- Vex + online alliance support: enough coordination for early targets
- Harbor Bank benefits from filling the extra Driver slot with the local player or Kira
- Northside Turf HQ remains a later progression target requiring stronger future alliance upgrades

This preserves the game's intended design: powerful players matter, but they cannot simply solo the progression ladder.

## Persistence

The save file now also stores:

- simulated alliance member online/offline states
- current raid-slot assignments
- frozen participants in an active raid
- contribution/reward data in the most recent raid result

Existing persistence for currencies, loot, troops, buildings, healing, recruitment, raid timers, convoys, and target cooldowns remains intact.

## Suggested test

1. Open **Downtown Bank**.
2. Review the alliance roster and raid slots.
3. Preview damage.
4. Join a Driver or Spy slot.
5. Preview again and compare contribution scores.
6. Toggle Kira online/offline and watch the slot roster react.
7. Launch the raid.
8. Review the result panel for each named member's reward share.
9. Confirm only your share is added to your Cash balance.
10. Try Harbor Bank and compare the effect of a full support roster.

## Architecture

```text
Main
├── PlayerEconomy
├── LootInventory
├── AllianceManager
├── TroopRoster
├── HospitalQueue
├── ConstructionQueue
├── RecruitmentQueue
├── SynergyRaid
├── RaidBattle
├── SaveManager
└── CityMap
```

`AllianceManager.gd`
- owns alliance member state
- tracks online/offline status
- owns role-slot assignments
- produces frozen participant snapshots

`SynergyRaid.gd`
- calculates frontline + support damage
- calculates per-member contribution values

`RaidBattle.gd`
- freezes participants at launch
- resolves targets
- calculates reward sharing
- grants the local player's share and loot
- handles local support wounds

## Production direction

The simulated alliance model is deliberately shaped like a future network model. Real server data can later replace the local member dictionaries while keeping the same concepts: member IDs, presence, roles, slot assignments, participant snapshots, contribution scores, and reward splits.

Before live multiplayer or monetization, all of that state and all battle/reward decisions must be server-authoritative.

## Next strong milestone

The best next step is a **separate world-map screen and alliance social layer**:

- city/base view versus world-map view;
- alliance panel with member profiles and activity;
- join/leave/invite prototype flow;
- alliance chat/message feed mockup;
- route-based convoy movement;
- raid invitations and join countdown;
- polished raid result overlay and combat effects.
