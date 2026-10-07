# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Current scaffold

- Godot 4 project configuration
- Runnable main scene
- Placeholder isometric city grid (no external art required)
- PC camera controls:
  - WASD / arrow-key panning
  - edge panning
  - right/middle mouse drag
  - mouse-wheel zoom
- Mobile camera controls:
  - single-finger drag
  - two-finger pinch zoom
- Responsive Control-based HUD starter
- Starter `HospitalQueue.gd` system
- Starter `SynergyRaid.gd` system
- Compatibility renderer selected for broad desktop/mobile support

## Open in Godot

1. Clone this repository.
2. Open Godot Engine 4.x.
3. Choose **Import**.
4. Select this repository's `project.godot`.
5. Open the project and press **F6/F5** (Run Project).

The project boots directly into `scenes/core/Main.tscn`.

## Project structure

```text
assets/             # Add generated/imported art here
data/               # Balance/config data
scenes/
  core/
  ui/
  world/
scripts/
  camera/
  combat/
  world/
```

Godot creates `.godot/` locally; it is ignored by Git.

## Camera controls

| Platform | Input | Action |
| --- | --- | --- |
| PC | WASD / arrows | Pan |
| PC | Right or middle drag | Pan |
| PC | Mouse wheel | Zoom |
| PC | Screen edge | Pan |
| Mobile | One-finger drag | Pan |
| Mobile | Two-finger pinch | Zoom |

## Next development milestones

1. Replace the procedural placeholder grid with a TileSet/TileMapLayer city.
2. Build Safehouse and Hospital building scenes.
3. Connect the hospital queue to troop battle results and HUD.
4. Add raid lobby UI and alliance roles.
5. Move authoritative multiplayer/economy state to a server backend before implementing purchases.

> Economy note: premium currency is currently local prototype state only. Do not ship real-money purchases with client-authoritative balances.
