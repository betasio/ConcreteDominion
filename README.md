# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Release-quality shell milestone

The project now has a real application shell around the gameplay scene instead of booting directly into the city.

## Boot / title screen

`project.godot` now starts:

`res://scenes/core/Boot.tscn`

The title flow includes:

- Continue
- New Game
- Quit
- asynchronous loading screen
- loading progress indicator
- initial keyboard/controller focus

Continue is enabled when either the primary save or backup save exists.

New Game removes both gameplay save files while leaving player settings intact.

The game scene is loaded with Godot's threaded resource loader and then becomes the active scene, preserving the existing `/root/Main` paths used by the prototype.

## Pause / system menu

Press the built-in `ui_cancel` action, normally Escape or the controller cancel/back action, to open the system menu.

Current actions:

- Resume
- Save Now
- Return to Title
- Quit Game

The menu runs while the SceneTree is paused and explicitly focuses Resume for keyboard/controller navigation.

Returning to the title or quitting saves first.

## Keyboard and controller UI navigation

A new `UIFocusManager` provides a fallback initial focus when the player starts navigating with:

- Tab / Shift+Tab
- keyboard arrows
- controller D-pad
- UI accept/cancel actions

Existing Godot Button controls then use the engine's normal focus navigation.

The strategy camera now stops keyboard and edge-panning whenever a GUI control owns focus. This prevents arrow/D-pad UI navigation from also moving the world camera.

## Audio / SFX hooks

A new `AudioManager` provides a lightweight sound layer.

Because final audio assets do not exist yet, the current build generates short procedural tones for:

- UI button clicks
- reward/milestone completion
- raid victory/defeat

All tones pass through the Master audio bus, so the existing Master Volume setting affects them automatically.

The audio manager listens for dynamically-created buttons as well as controls already present when Main loads, so future UI panels inherit click feedback without manually wiring every button.

This procedural implementation is intentionally replaceable: production WAV/OGG assets can later be dropped behind the same public audio methods.

## Crash-safe backup saves

Gameplay persistence now uses two files:

- `user://concrete_dominion_save.json`
- `user://concrete_dominion_save.backup.json`

Before overwriting the primary save, the previous valid primary document is copied into the backup slot.

Loading behavior:

1. Try the primary save.
2. If missing or invalid, try the backup.
3. Run the normal version migrations.
4. Continue loading gameplay state.

New Game deletes both files.

This protects the prototype from a partially-written or corrupted latest save while keeping the existing schema at version 12.

## Windows export preset

A version-controlled **Windows Desktop** export preset is included.

Default output:

`build/windows/ConcreteDominion.exe`

Command-line release export:

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/ConcreteDominion.exe
```

The `build/` folder is ignored by Git.

## Android export preset

A version-controlled **Android** export preset is included.

Default output:

`build/android/ConcreteDominion.apk`

Current prototype package identifier:

`com.betasio.concretedominion`

The preset targets arm64 and enables Android vibration permission so the existing haptic setting can work on supported devices.

Command-line debug/release examples:

```bash
godot --headless --path . --export-debug "Android" build/android/ConcreteDominion-debug.apk
godot --headless --path . --export-release "Android" build/android/ConcreteDominion.apk
```

Signing credentials are intentionally **not** committed.

Before a store release, configure the Android SDK/JDK and release keystore on the build machine.

## Automated smoke-test scene

A lightweight headless validation scene now exists:

`res://scenes/tests/SmokeTest.tscn`

It verifies that critical scenes/resources exist, instantiates Main, and checks for key production nodes including:

- GameBalance
- SettingsManager
- SaveManager
- CityMap
- HUD
- PauseMenu
- AudioManager
- UIFocusManager

It also checks the central Driver recruitment definition and save schema.

Run it with:

```bash
godot --headless --path . res://scenes/tests/SmokeTest.tscn
```

Exit code:

- 0 = pass
- 1 = failure

This is intended to become the first CI gate once the repository has an automated build workflow.

## Current application structure

```text
Boot
└── threaded load → Main

Main
├── GameBalance
├── SettingsManager
├── PlayerEconomy
├── LootInventory
├── PlayerProgression
├── MissionTracker
├── RetentionManager
├── EventManager
├── PlayerProfile
├── MailboxManager
├── AllianceManager
├── AllianceSocial
├── TroopRoster
├── HospitalQueue
├── ConstructionQueue
├── RecruitmentQueue
├── SynergyRaid
├── CombatLoadout
├── RaidBattle
├── SaveManager
├── SafeAreaManager
├── AudioManager
├── UIFocusManager
├── CityMap
├── HUD
├── ProgressionUI
├── RetentionUI
├── ProfileUI
├── EventUI
├── CombatStrategyUI
├── SettingsDiagnosticsUI
└── PauseMenu
```

## New files

```text
scenes/core/Boot.tscn
scripts/core/BootFlow.gd

scenes/ui/PauseMenu.tscn
scripts/ui/PauseMenu.gd

scripts/ui/UIFocusManager.gd

scripts/audio/AudioManager.gd

scenes/tests/SmokeTest.tscn
scripts/tests/SmokeTest.gd

export_presets.cfg
```

## Current testing limitation

The repository now contains the smoke-test harness, but this coding environment does not currently have a Godot editor executable installed, so the new scene could not be executed here.

The repository-level wiring and file references were statically checked before commit. The first final-game test should run the smoke-test command above before any manual gameplay testing.

## Next strong milestone

The project is now structurally ready for a broader **content-completion and final QA phase**:

- more building functions and district content;
- real art/audio asset replacement;
- monetization/store prototype screens without real purchases;
- economy/balance simulation;
- automated CI smoke test;
- Android/Windows device testing;
- UI overflow and localization checks;
- full new-player-to-endgame playthrough;
- bug triage and release checklist.
