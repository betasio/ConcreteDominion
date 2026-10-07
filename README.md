# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Visual polish milestone

The current build adds a first presentation pass to the existing Base / World / Alliance raid loop without requiring external art assets.

### Street-following raid convoys

Raid convoys no longer move in a straight line from the Safehouse to a target.

Each current target has a district route made from world-map waypoints. The convoy:

- follows multiple street turns;
- rotates to face its current route segment;
- uses the raid launch countdown as total travel time;
- restores along the route after reopening during an active raid.

The routing system is still lightweight and deterministic, making it suitable for replacement with proper pathfinding later.

### Raid target status bars

World-map targets now display a compact status bar.

When available, the bar shows:

- target HP;
- difficulty tier;
- ready state.

After defeat, the same area changes into a recovery/respawn progress bar and the existing countdown remains visible.

### Raid impact effects

Raid resolution now spawns a procedural impact effect over the attacked target.

- victories use a bright impact/explosion burst;
- defeats use a harsher red impact;
- the effect expands and fades automatically.

This uses Godot drawing code only, so there are no new texture dependencies.

### Animated raid result overlay

Battle results now appear in a dedicated center-screen overlay with a short fade/scale animation.

The overlay shows:

- victory or defeat;
- target name;
- damage versus target HP;
- the local player's Cash share;
- local loot;
- total support bonus;
- named alliance reward shares.

The original detailed raid-lobby result remains available underneath.

### Alliance member profile cards

The Alliance Hub now renders the alliance roster as responsive member cards.

Each card shows:

- member name;
- level;
- preferred role;
- power;
- online/offline state.

Cards use an `HFlowContainer` so they wrap on narrower screens rather than assuming desktop width.

## Current player flow

1. Manage buildings and crew in **BASE**.
2. Switch to **WORLD**.
3. Review target HP/difficulty bars.
4. Select a Bank or Turf HQ.
5. Open **Alliance** and review member cards/activity.
6. Send a raid invite or configure the raid lobby.
7. Launch the raid.
8. Watch the convoy travel through district waypoints.
9. See the target impact effect at resolution.
10. Review the animated result overlay.
11. Heal wounded specialists and continue progression.

## Architecture additions

```text
scenes/effects/
└── RaidImpactVFX.tscn

scripts/effects/
└── RaidImpactVFX.gd

CityMap
├── Buildings
├── RaidTargets
├── Convoys
├── Effects
└── StrategyCamera
```

`ConvoyVisual.gd` now accepts a `PackedVector2Array` route instead of requiring only a start/end point.

`CityMap.gd` owns prototype district routes and spawns impact effects on battle resolution.

`RaidTarget.gd` draws target HP/difficulty and recovery status directly in world space.

`HUD.gd` builds responsive alliance profile cards and animates the result overlay.

## Production direction

This is intentionally a procedural prototype presentation layer.

Later art passes can replace the procedural shapes with:

- vehicle sprites;
- road/path navigation;
- particles;
- screen shake;
- target hit animations;
- portrait art;
- polished panel textures;
- sound and haptics;

without changing the underlying raid/economy/alliance models.

## Suggested test

1. Switch to **WORLD**.
2. Observe HP/difficulty above each target.
3. Select a target and launch a raid.
4. Watch the convoy turn through multiple route waypoints.
5. Wait for resolution and observe the impact VFX.
6. Confirm the animated result overlay opens.
7. Open **Alliance** and resize the window to verify profile cards wrap.
8. Defeat a target and verify its HP bar changes to respawn/recovery progress.

## Next strong milestone

The strongest next feature step is to add actual **player progression and inventory utility**:

- player/account level and XP;
- building unlock requirements;
- Parts/Intel/Contraband uses;
- specialist upgrades;
- target tier unlocking;
- daily/mission objectives;
- first-time-user tutorial flow.
