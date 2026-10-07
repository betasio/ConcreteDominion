# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Playable prototype slice

The current build includes:

- Godot 4 project configuration and runnable main scene
- Procedural isometric city grid (no external art required)
- Selectable **Safehouse** and **Underground Clinic**
- Responsive building information panel
- Hospital/wounded troop queue with live countdowns
- Prototype battle-wound simulator
- Gold-based instant healing
- PC strategy camera:
  - WASD / arrow-key panning
  - edge panning
  - right/middle mouse drag
  - mouse-wheel zoom
- Mobile strategy camera:
  - single-finger drag
  - two-finger pinch zoom
- Starter `SynergyRaid.gd` framework

## Run it

1. Clone this repository.
2. Open Godot Engine 4.x.
3. Choose **Import** and select `project.godot`.
4. Press **F6/F5**.

### Try the gameplay loop

1. Click the green-accented **Underground Clinic**, or press the **Clinic** shortcut.
2. Press **Simulate Battle Wounds**.
3. Watch injured Enforcers and Drivers recover instead of dying permanently.
4. Press **Instant Heal** to spend Gold and clear the queue.

This is intentionally a local prototype. Premium currency and timers are **not secure yet** and must become server-authoritative before any real-money economy ships.

## Architecture

```text
Main
├── HospitalQueue          # Gameplay state
├── CityMap
│   ├── Buildings
│   │   ├── Safehouse
│   │   └── Hospital
│   └── StrategyCamera
└── HUD                    # Presentation + user actions
```

The UI does not own the hospital state. `Main.gd` wires shared systems together, which makes it easier to move authoritative state to a backend later.

## Next milestones

1. Building upgrade timers and construction queue.
2. Troop recruitment and barracks.
3. Resource production.
4. Raid lobby UI wired to `SynergyRaid.gd`.
5. Alliance support roles (Driver / Spy).
6. Server-authoritative persistence and economy.
