# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Current playable progression loops

### City construction
- Select the Safehouse and upgrade it through increasing levels.
- Upgrades spend shared Cash and run on a real countdown.
- Only one construction job runs at once in this prototype.
- Spend Gold on **Finish Now** to complete the active construction timer.
- Two selectable empty lots can build a **Garage** or **Intel Office**.
- Construction is visually represented directly on the map.

### Underground Clinic
- Simulate battle wounds.
- Defeated troops enter a healing queue rather than dying permanently.
- Healing runs on timers.
- Spend the same shared Gold balance to heal instantly.

### Controls
- PC: WASD/arrows, edge pan, right/middle drag, mouse-wheel zoom.
- Mobile: one-finger pan and two-finger pinch zoom.

## Run it

1. Clone/pull this repository.
2. Import `project.godot` into Godot Engine 4.x.
3. Press **F6/F5**.

Try this sequence:
1. Click **Safehouse** → **Upgrade to Lv.2**.
2. Watch the construction bar and scaffold.
3. Either wait or use **Finish Now**.
4. Click an **Empty Build Lot** and construct the Garage or Intel Office.
5. Open the Clinic and confirm Gold is shared across both systems.

## Architecture

```text
Main
├── PlayerEconomy          # Shared Cash + Gold
├── HospitalQueue          # Wounded troop timers
├── ConstructionQueue      # Building/upgrade timer
├── CityMap
│   ├── Safehouse
│   ├── Hospital
│   ├── BuildLotA
│   └── BuildLotB
└── HUD
```

The prototype remains client-side for fast development. Before real multiplayer or purchases, currency, timers, construction completion, healing, and raid outcomes should become server-authoritative.

## Next milestone

The next major loop is **troop recruitment + Barracks**, followed by wiring those troops into the **Synergy Raid lobby** with Driver and Spy support roles.
