# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## World raid targets

Raids are now launched from clickable targets placed directly on the isometric city map.

Current targets:

| Target | Difficulty | HP | Cash reward | Respawn |
| --- | --- | ---: | ---: | ---: |
| Downtown Bank | Medium | 9,000 | $7,500 | 30 sec |
| Harbor Bank | Hard | 11,500 | $10,500 | 45 sec |
| Northside Turf HQ | Elite | 14,500 | $15,000 | 60 sec |

Click a target to open its raid lobby. Each location carries its own HP, difficulty, reward, availability, and cooldown.

A defeated target enters a visible respawn cooldown. Other targets remain available, so the player can move around the city instead of waiting on one global encounter.

## Full prototype loop

1. Upgrade city buildings and construct specialist facilities.
2. Recruit Enforcers, Drivers, and Spies.
3. Pan around the city and click a Bank or Turf HQ.
4. Inspect its HP, difficulty, reward, and respawn status.
5. Add Driver and Spy support.
6. Preview the alliance damage.
7. Launch the raid.
8. Resolve victory or defeat after the launch countdown.
9. Earn Cash on victory.
10. The defeated target enters cooldown.
11. Wounded crew move from the active roster into the Underground Clinic.
12. Heal them over time or spend Gold.
13. Continue raiding other available targets.

## Alliance synergy

The prototype alliance boss contributes 6,000 frontline power.

- Driver support: +10% each
- Spy support: +12% each
- Support bonuses multiply the frontline contribution

This is the core anti-solo-stomp loop: raw power is valuable, but high-power players need specialist support to clear tougher targets.

For example, the Downtown Bank can be cleared with enough support, while Harbor Bank and Northside Turf HQ require progressively stronger alliance coordination.

## Persistence

The local save now tracks:

- Cash and Gold
- troop roster
- building levels
- constructed lots
- construction queue
- recruitment queue
- Clinic queue
- active raid
- last raid result
- per-target respawn cooldowns

Offline time advances construction, recruitment, healing, raid countdowns, and target respawn cooldowns.

## Suggested test

1. Pull the latest `main`.
2. Run the project.
3. Pan around the city until you see the labeled raid targets.
4. Click **Downtown Bank**.
5. Preview damage without support.
6. Add Drivers and Spies until the preview exceeds 9,000.
7. Launch and win the raid.
8. Close the raid panel and see the Bank display its respawn countdown on the map.
9. Click **Harbor Bank** or **Northside Turf HQ** while Downtown Bank is unavailable.
10. Close/reopen the game and confirm target cooldowns persist.

## Architecture

```text
Main
├── PlayerEconomy
├── TroopRoster
├── HospitalQueue
├── ConstructionQueue
├── RecruitmentQueue
├── SynergyRaid
├── RaidBattle
├── SaveManager
├── CityMap
│   ├── Buildings
│   └── RaidTargets
│       ├── DowntownBank
│       ├── HarborBank
│       └── NorthsideHQ
└── HUD
```

`RaidTarget.gd` owns target-specific map state and cooldowns. `SynergyRaid.gd` owns alliance contribution math. `RaidBattle.gd` owns encounter launch and resolution.

## Production note

This is still a local prototype. Before live multiplayer or monetization, raid availability, timers, participants, battle results, rewards, currency, and troop state must become server-authoritative.

## Next milestone

Good next steps are:

- a dedicated world-map mode with a larger district;
- target tiers generated from data instead of scene constants;
- alliance member slots instead of simulated support IDs;
- visible convoy/unit movement toward raid targets;
- reward crates and target drop tables;
- polished raid result presentation and combat VFX.
