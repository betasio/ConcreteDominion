# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Production-readiness foundation

This milestone moves several prototype-wide concerns out of individual gameplay scripts and into dedicated infrastructure.

## Central balance configuration

A new `GameBalance` node owns shared tuning values for:

- troop recruitment Cash cost;
- troop recruitment time;
- recruitment Gold speed-up rate;
- construction Gold speed-up rate;
- Clinic Gold speed-up rate;
- account XP curve;
- Driver support progression;
- Spy support progression;
- Enforcer power progression.

Recruitment, construction, Clinic healing, and player progression now read these values from the same source.

This makes future economy passes substantially safer because core tuning no longer requires searching multiple unrelated scripts.

## Player settings

Settings are stored separately in:

`user://settings.cfg`

They do not belong to the gameplay save and can therefore survive save resets independently.

Current settings:

- Master Volume
- Haptics on/off
- Haptics strength
- Reduced Motion
- Larger UI Text
- PC Edge Pan

Master volume is applied through Godot's Master audio bus.

Haptics use `Input.vibrate_handheld()` only when touchscreen hardware is available.

Raid resolution provides short victory/defeat haptic feedback when enabled.

Reduced Motion disables the raid result tween and raid impact burst.

## Mobile safe areas

The project now uses:

`DisplayServer.get_display_safe_area()`

on touchscreen devices.

A `SafeAreaManager` converts the physical safe-area rectangle into the game's stretched viewport space and applies the resulting insets to the major UI roots.

This protects interface controls from:

- phone notches;
- camera cutouts;
- rounded display corners;
- system UI safe regions.

Desktop windows receive zero safe-area padding.

The project stretch aspect is now `expand` so extra PC/mobile aspect-ratio space can be used responsively.

## Diagnostics panel

The Settings screen includes live diagnostics:

- FPS;
- operating system;
- active Godot renderer;
- viewport size;
- touchscreen detection;
- current gameplay save schema;
- central recruitment costs/times;
- Gold-per-minute speed-up values.

This provides a basic in-game inspection surface for later balancing and device testing.

## Save migrations

Gameplay save schema is now **version 12**.

Older saves are explicitly migrated before loading.

Current migration guards cover the historical additions for:

- progression/missions;
- retention;
- profile/mailbox;
- live events;
- combat loadouts.

Missing systems are initialized with empty/default data rather than breaking older saves.

The migration result is marked with schema metadata and then loaded through the normal subsystem loaders.

## Mobile lifecycle saving

Desktop close requests still trigger a save.

The game now also saves on:

`NOTIFICATION_APPLICATION_PAUSED`

This is important for Android/iOS because a suspended application can be terminated by the operating system without receiving a normal desktop-style close event.

## Accessibility

The current accessibility foundation contains:

- reduced motion;
- larger UI text;
- adjustable haptic strength;
- complete haptic disable;
- master-volume control.

The larger-text option applies a shared font-size override to the major UI roots so the feature affects the whole interface rather than one panel.

## Architecture additions

```text
Main
├── GameBalance
├── SettingsManager
├── SafeAreaManager
├── SaveManager
└── SettingsDiagnosticsUI

scripts/core/
├── GameBalance.gd
├── SettingsManager.gd
└── SaveManager.gd

scripts/ui/
├── SafeAreaManager.gd
└── SettingsDiagnosticsUI.gd

scenes/ui/
└── SettingsDiagnosticsUI.tscn
```

## Current shared balance defaults

### Recruitment

| Unit | Cash each | Seconds each |
| --- | ---: | ---: |
| Enforcer | $250 | 1.4 |
| Driver | $400 | 2.0 |
| Spy | $500 | 2.4 |

### Gold speed-ups

| Queue | Gold/minute |
| --- | ---: |
| Recruitment | 2 |
| Construction | 3 |
| Clinic | 2 |

### Progression

- Base XP required: 100
- Extra XP per account level: 75
- Driver support starts at +15%, +3% per specialist level
- Spy support starts at +18%, +4% per specialist level
- Enforcer power starts at 100 each, +15 per specialist level

These are prototype defaults and are intentionally centralized for the later full balance pass.

## Production notes

Haptic vibration is platform-dependent. Android exports must enable the appropriate vibration permission for handheld vibration to work.

Gameplay saves, rewards, timers, progression, currencies, battles, and event state remain client-authoritative in this prototype. A live multiplayer release still requires server validation.

## Next strong milestone

The project is now ready for a broader **quality and release-preparation pass**:

- real audio/SFX hooks;
- UI navigation/focus for keyboard/controller;
- loading/title screen;
- pause/system menu;
- export presets for Windows/Android;
- crash-safe backup save;
- data validation tools;
- automated smoke-test scene;
- runtime parser/error cleanup;
- performance budget checks;
- final economy/balance spreadsheet.
