# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Current playable loops

### City progression
- Upgrade the Safehouse through timed levels.
- Build the Garage and Intel Office on empty lots.
- Spend shared Cash to construct and shared Gold to finish timers early.

### Crew recruitment
- Open the **Crew Barracks** from the map or the **Crew** shortcut.
- Recruit Enforcers, Drivers, and Spies.
- Recruitment has its own timed queue.
- Spend Gold to finish training immediately.
- Your troop roster updates when training completes.

### Underground Clinic
- Simulate wounded troops after battle.
- Wounded crew recover instead of being permanently lost.
- Healing runs on timers or can be completed instantly with Gold.

### Synergy Raid prototype
- Open **Alliance Raid**.
- A high-level alliance boss provides 6,000 frontline power.
- Your Drivers add +10% raid support each.
- Your Spies add +12% raid support each.
- Support bonuses multiply the frontline contribution instead of trying to replace it.
- The raid panel limits support slots to specialists you actually own.

This is the first playable proof of the game's core anti-solo-stomp idea: raw power matters, but specialist support has direct multiplicative value.

## Controls

- PC: WASD/arrows, edge pan, right/middle drag, mouse-wheel zoom.
- Mobile: one-finger pan and two-finger pinch zoom.

## Suggested test sequence

1. Open **Crew**.
2. Recruit Drivers or Spies and watch the training timer.
3. Use **Finish Training** to test premium acceleration.
4. Open **Alliance Raid**.
5. Add Driver and Spy support.
6. Calculate the raid and compare the result before/after adding specialists.
7. Upgrade the Safehouse or build one of the empty lots.
8. Open the Clinic and confirm Cash/Gold remain shared across all progression systems.

## Architecture

```text
Main
├── PlayerEconomy
├── TroopRoster
├── HospitalQueue
├── ConstructionQueue
├── RecruitmentQueue
├── SynergyRaid
├── CityMap
│   ├── Safehouse
│   ├── Hospital
│   ├── Barracks
│   ├── BuildLotA
│   └── BuildLotB
└── HUD
```

The prototype is still intentionally client-side for fast iteration. Before multiplayer or real-money purchases, currency balances, construction, healing, recruitment, raid participants, and raid outcomes must become server-authoritative.

## Next milestone

The next strong step is **persistence + progression data**:
- save/load player Cash, Gold, troop counts, building levels, and active queues;
- move balance numbers into data resources rather than hard-coding them;
- then add a proper Alliance Raid target with HP, rewards, and wounded troop results.
