# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Current playable loops

### Persistent progression
The prototype now saves to Godot's per-user `user://` storage automatically.

Saved state includes:
- Cash and Gold
- Enforcer, Driver, and Spy counts
- Safehouse, Clinic, and Barracks levels
- Garage and Intel Office construction state
- Active building upgrade/construction timer
- Active troop recruitment timer
- Hospital healing queue

The save file records a real-world timestamp. When the game reopens, elapsed offline time is applied to construction, recruitment, and healing. Jobs that should have completed while the game was closed complete during loading.

Autosaves are debounced so timer updates do not write to disk every frame.

### City progression
- Upgrade the Safehouse, Clinic, and Crew Barracks.
- Build the Garage and Intel Office on empty lots.
- Spend Cash to construct and Gold to finish timers early.

### Crew recruitment
- Recruit Enforcers, Drivers, and Spies.
- Recruitment uses a timed queue.
- Spend Gold to finish training immediately.
- Recruited units persist across restarts.

### Underground Clinic
- Wounded crew recover instead of being permanently lost.
- Healing timers persist and continue while offline.

### Synergy Raid prototype
- A high-level alliance member provides frontline power.
- Drivers and Spies provide multiplicative support bonuses.
- Support availability is limited by the specialists you own.

## Persistence test

1. Run the game.
2. Spend some Cash, recruit troops, start a building upgrade, or add wounded troops.
3. Close the game before the timers finish.
4. Reopen it.
5. Your currency, roster, buildings, and queues should restore.
6. Leave it closed longer than a timer and reopen it; that job should be completed.

The local save lives under Godot's `user://` path, which maps to the platform's normal application-data location.

## Architecture

```text
Main
├── PlayerEconomy
├── TroopRoster
├── HospitalQueue
├── ConstructionQueue
├── RecruitmentQueue
├── SynergyRaid
├── SaveManager
├── CityMap
│   ├── Safehouse
│   ├── Hospital
│   ├── Barracks
│   ├── BuildLotA
│   └── BuildLotB
└── HUD
```

Each gameplay system exposes explicit save/load data instead of serializing Godot Nodes. This keeps save files versionable and prepares the project for eventually replacing local persistence with server-authoritative player state.

## Important production note

The current save is deliberately local for prototyping. It is not secure against editing or clock manipulation. Before multiplayer, competitive raids, premium purchases, or a real economy, currency, timers, troop inventories, healing, and raid results must be validated by the server.

## Next milestone

The next strong gameplay step is a real raid target:
- target HP and difficulty;
- raid countdown and resolution;
- Cash/reward payout;
- troop wounds generated from the result;
- Clinic integration;
- victory/defeat feedback.
