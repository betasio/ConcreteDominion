# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## District-map milestone

The city has been expanded into a larger raid district and the raid system is now data-driven.

### Data-driven targets

Raid balance lives in reusable Godot resources under:

`data/raids/`

Each target resource defines:
- target ID and display name
- difficulty tier
- HP
- Cash reward
- respawn cooldown
- visual accent
- guaranteed loot drops

Current targets:

| Target | Tier | HP | Cash | Loot | Respawn |
| --- | --- | ---: | ---: | --- | ---: |
| Downtown Bank | Medium | 9,000 | $7,500 | Parts x2 | 30s |
| Harbor Bank | Hard | 11,500 | $10,500 | Parts x3, Intel x1 | 45s |
| Northside Turf HQ | Elite | 14,500 | $15,000 | Parts x4, Intel x2, Contraband x1 | 60s |

Adding another target now means creating a new `.tres` data resource and assigning it to a `RaidTarget` scene instance rather than rewriting combat logic.

## Visible raid convoys

Launching a raid spawns a convoy at the Safehouse and visibly moves it across the isometric district toward the selected Bank or Turf HQ.

The convoy travel time matches the raid launch countdown. If the game closes mid-raid, reopening restores the active raid and recreates the convoy for the remaining travel time.

## Persistent loot inventory

Victory rewards now include persistent loot:

- **Parts**
- **Intel**
- **Contraband**

The top HUD shows compact loot totals as `P / I / C`.

Cash and loot are both granted by the target's data resource. The raid result screen lists the drops earned.

## Offline behavior

Offline time now applies consistently to:
- construction
- recruitment
- Clinic healing
- raid travel/countdown
- target respawn cooldowns

If a raid finishes while the game is closed, any extra offline time after the battle also reduces the defeated target's respawn cooldown.

## Core gameplay loop

1. Develop the Safehouse district.
2. Recruit Enforcers, Drivers, and Spies.
3. Pan across the larger city district.
4. Click a data-driven Bank or Turf HQ.
5. Add specialist alliance support.
6. Preview damage.
7. Launch the raid.
8. Watch the convoy travel from the Safehouse.
9. Resolve victory/defeat.
10. Collect Cash and loot.
11. Send wounded crew through the Clinic recovery loop.
12. Move to another target while the defeated location respawns.

## Architecture

```text
data/raids/
├── downtown_bank.tres
├── harbor_bank.tres
└── northside_hq.tres

Main
├── PlayerEconomy
├── LootInventory
├── TroopRoster
├── HospitalQueue
├── ConstructionQueue
├── RecruitmentQueue
├── SynergyRaid
├── RaidBattle
├── SaveManager
└── CityMap
    ├── Buildings
    ├── RaidTargets
    ├── Convoys
    └── StrategyCamera
```

`RaidTargetData.gd` defines balance/configuration.  
`RaidTarget.gd` owns map availability and cooldown state.  
`RaidBattle.gd` resolves the selected target.  
`ConvoyVisual.gd` handles the current prototype travel visualization.

## Production note

The current prototype remains client-authoritative for development speed. Before live multiplayer or monetization, currencies, loot, timers, raid participants, target state, battle resolution, and rewards should move to server authority.

## Next strong milestone

The next step should focus on presentation and real alliance structure:
- alliance member roster and raid slots;
- simulated online/offline members for prototype testing;
- player contribution scores and reward sharing;
- convoy paths instead of straight-line travel;
- combat impact/VFX and a polished result overlay;
- separate city/base view and larger world-map view.
