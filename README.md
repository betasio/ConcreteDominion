# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with Godot 4 and GDScript.

## Faction identity + localization + endgame milestone

This milestone makes rival factions mechanically distinct, adds district-specific encounter patterns, introduces a localization-ready text catalog for new content, and adds persistent achievements plus a non-terminal endgame goal.

## Faction personalities

Rival crews now have data-driven gameplay profiles instead of functioning as names only.

### Dock Rats — Scrappy

- pressure growth: 85% of baseline;
- encounter strength: 92% of baseline;
- encounter Cash: 95% of baseline;
- preferred encounter: Roadblock.

They are intended to be the forgiving early-game rival.

### Iron Serpents — Armored

- pressure growth: 105%;
- encounter strength: 112%;
- encounter Cash: 108%;
- preferred encounter: Convoy Ambush.

They emphasize Driver/transport encounters and stronger defenses.

### Meridian Boys — Watchful

- pressure growth: 95%;
- encounter strength: 105%;
- encounter Cash: baseline;
- preferred encounter: Surveillance Sweep.

They lean toward Spy gameplay.

### Northside Crew — Aggressive

- pressure growth: 118%;
- encounter strength: 108%;
- encounter Cash: 105%;
- preferred encounter: Roadblock.

They pressure owned turf more quickly without ever automatically deleting ownership.

### Velvet Circle — Connected

- pressure growth: baseline;
- encounter strength: 115%;
- encounter Cash: 118%;
- preferred encounter: Surveillance Sweep.

They are higher-risk, higher-reward late-game rivals.

## District-specific encounter rules

Encounter rotation is now configured per district.

Examples:

- Downtown: Roadblock / Convoy Ambush
- Harbor: Convoy Ambush / Roadblock
- Midtown: Surveillance / Roadblock
- Northside: Roadblock / Turf Push
- Casino: Surveillance / Convoy Ambush
- Financial: Surveillance / Roadblock
- Industrial: Convoy Ambush / Roadblock

Faction modifiers are applied after the district's own patrol-power value, so both district tier and rival identity matter.

## Visible faction traits

Territory Command now surfaces each rival faction's trait alongside its name.

Active encounters also display the rival trait.

This makes mechanical differences understandable to the player instead of hiding them in balance tables.

## Localization-ready content layer

A new `LocalizedText` service owns stable string keys for newly added faction and achievement content.

Examples:

- `FACTION_IRON_SERPENTS`
- `TRAIT_ARMORED`
- `ENCOUNTER_SURVEILLANCE`
- `ACH_DOMINION`
- `ACH_DESC_DOMINION`

If Godot has a translation for a key, the service uses it.

If no translation exists, it falls back to the built-in English copy.

This means future language packs can replace strings without changing gameplay code.

The existing older prototype UI still contains hard-coded English copy; migrating all legacy text into localization keys remains a future content-polish task.

## Achievements

A persistent AchievementManager now evaluates long-term milestones.

Current achievements:

### First Territory
Capture any district.

Reward: 5 Gold.

### Citywide
Own every district.

Reward: 20 Gold.

### Trusted Crew
Reach Alliance Level 4.

Reward: 10 Gold.

### Made Boss
Reach Account Level 7.

Reward: 10 Gold.

### Command Center
Upgrade Safehouse to Level 5.

Reward: 10 Gold.

### Supply Network
Build both Scrapyard and Data Hub.

Reward: 8 Gold.

### Specialist Crew
Reach Specialist Level 3 with Enforcer, Driver, and Spy.

Reward: 12 Gold.

### Concrete Dominion
Complete the full prototype endgame requirements.

Reward: 100 Gold.

Achievement rewards are one-time and persist across saves.

## Endgame goal

The game now has a clear long-term completion target without forcing the player to stop playing.

To complete **Concrete Dominion**, the player must:

- own all seven districts;
- reach Account Level 7;
- reach Alliance Level 4;
- upgrade Safehouse to Level 5;
- upgrade Underground Clinic to Level 5;
- upgrade Crew Barracks to Level 5;
- reach at least Garage Level 3;
- reach at least Intel Office Level 3;
- build the Scrapyard;
- build the Data Hub.

Completing the goal unlocks the achievement and grants a one-time 100 Gold completion reward.

The world remains playable afterward.

## Achievement UI

A new **Achievements** shortcut opens an endgame/progression panel.

It shows:

- current Dominion completion requirement;
- all available achievements;
- LOCKED / UNLOCKED state;
- human-readable achievement descriptions.

It participates in the existing:

- safe-area handling;
- large-text setting;
- keyboard/controller focus;
- automatic UI click audio.

## Reward safety

Achievement state is loaded before the manager evaluates a restored city.

This prevents an existing save from receiving duplicate achievement Gold simply because its building/territory state was reconstructed during startup.

## Persistence

Save schema is now **version 17**.

New persistent data:

- achievement unlock state;
- Dominion reward-claimed state.

Older saves receive an empty achievement state, then achievements are evaluated once against the loaded account/city.

Any milestone already satisfied will unlock normally once and persist from that point onward.

## Architecture additions

```text
Main
├── LocalizedText
├── FactionRules
├── AchievementManager
└── AchievementUI

scripts/content/
└── LocalizedText.gd

scripts/world/
└── FactionRules.gd

scripts/progression/
└── AchievementManager.gd

scripts/ui/
└── AchievementUI.gd

scenes/ui/
└── AchievementUI.tscn
```

## Recommended future test path

When final runtime testing begins:

1. Inspect each discovered rival and confirm its faction + trait.
2. Compare pressure growth between Dock Rats and Northside Crew.
3. Compare encounter power/reward differences between factions.
4. Verify district-specific encounter rotations.
5. Unlock First Territory and confirm the Gold reward happens once.
6. Restart and confirm it is not rewarded again.
7. Build Scrapyard + Data Hub and verify Supply Network unlocks.
8. Raise all three specialists to Level 3 and verify Specialist Crew.
9. Reach Account Lv.7 and Alliance Lv.4.
10. Max Safehouse, Clinic, and Barracks.
11. Own all seven districts.
12. Complete the final Dominion requirements and verify the one-time 100 Gold reward.
13. Continue playing after Dominion completion.
14. Switch/add a Godot translation later and confirm text keys can be replaced without touching gameplay scripts.
15. Run the smoke-test scene.

## Next development direction

The project is now close to the point where adding more systems has diminishing returns.

The strongest next phase is **balance simulation + final QA infrastructure**:

- simulate progression/economy pacing;
- check Cash/Gold sinks against income;
- check raid power curves;
- check healing/recruitment/build timing;
- validate F2P specialist usefulness at every district tier;
- add automated data validation;
- add CI smoke-test workflow;
- migrate remaining UI text to localization keys;
- replace procedural placeholder audio/art;
- then perform the first full Godot runtime/device playthrough.


## Automated balance + QA infrastructure

The repository now includes deterministic headless QA for the current prototype balance.

### Test scenes

```bash
godot --headless --path . res://scenes/tests/DataValidation.tscn
godot --headless --path . res://scenes/tests/BalanceAudit.tscn
godot --headless --path . res://scenes/tests/SmokeTest.tscn
```

### DataValidation

Hard-fails on issues such as:

- missing or duplicate raid IDs;
- raid tiers with non-increasing level gates or effective HP;
- invalid Cash/XP/cooldown values;
- unknown/non-positive loot entries;
- invalid building/facility cost data;
- missing required QA/game resources;
- unexpected save-schema regression.

### BalanceAudit

Simulates the major deterministic pacing assumptions without needing a manual playthrough.

Current baseline:

- Account Lv.1 -> Lv.7: 1,725 XP;
- one first-clear of all seven raid tiers: 1,910 raw raid XP;
- max core-building Cash sink: about $215,000;
- build + max facility Cash sink: about $447,000;
- combined city-development sink: about $662,000;
- full-city passive turf income: $11,000/hour;
- combined city sink equals about 60 hours of full-city passive production.

Reference raid viability:

| Target | Reference profile | Damage / effective HP |
| --- | --- | ---: |
| Downtown Bank | Balanced coordinated | 1.46x |
| Harbor Bank | Balanced coordinated | 1.21x |
| Midtown Exchange | Balanced coordinated | 1.23x |
| Northside Turf HQ | Balanced coordinated | 1.28x |
| Casino Vault | Balanced coordinated | 1.10x |
| Financial Tower | Tactical F2P (Blitz + Intel Burst) | 1.16x |
| Industrial Depot | Tactical F2P (Blitz + Intel Burst) | 1.03x |

The final Industrial tier is intentionally the tightest reference clear. Falling below 1.00 is treated as a hard regression.

Early local specialist contribution also has a CI floor:

- Driver contribution must add at least 10% damage;
- Spy contribution must add at least 10% damage.

This protects the game's core design goal that lower-power F2P specialists remain materially useful in Alliance Raids.

### Tuning warnings

Warnings do not fail CI.

The current expected warning is that recruitment/build/healing timers remain heavily prototype-compressed while the account starts with 250 Gold. The current economy therefore validates progression structure, but it does **not** yet represent final live-service monetization timing.

### GitHub Actions

`.github/workflows/godot-qa.yml` runs on pushes and pull requests to `main` using Godot 4.7.2 stable.

The pipeline runs:

1. Godot project import;
2. DataValidation;
3. deterministic BalanceAudit;
4. full Main-scene SmokeTest.

A hard failure in any stage blocks the QA job.


## Production economy tuning pass

The seconds-long prototype queue timings have now been replaced with an initial production-oriented pacing profile.

### Recruitment

Base time per troop:

- Enforcer — 20 seconds
- Driver — 30 seconds
- Spy — 36 seconds

Barracks, Garage, and Intel Office bonuses still reduce these values normally.

### Clinic

Base recovery time is now 45 seconds per wounded troop before severity and Clinic-level modifiers.

The no-permanent-death pillar is unchanged.

### Construction

Current starting build durations:

- Garage — 6 minutes
- Intel Office — 8 minutes
- Scrapyard — 10 minutes
- Data Hub — 12 minutes

Core-building upgrade durations begin around 4–5 minutes per level step and scale with current building level, while Safehouse construction-speed bonuses continue to apply.

### Gold speed-ups

Gold no longer charges per minute.

All queues now use a shared **5-minute speed-up chunk**:

- Recruitment — 1 Gold per chunk
- Construction — 2 Gold per chunk
- Clinic — 1 Gold per chunk

This keeps small convenience skips inexpensive without making a longer timer cost explode linearly every minute.

New accounts now begin with **75 Gold** instead of 250.

Existing saves are not reduced; saved Gold balances remain intact.

Prototype Store example Gold quantities were reduced to match the smaller production-scale Gold economy. Real purchases remain disabled.

### Localization cleanup

The most visible Progression, Territory Command, and Store interface labels/buttons now use the existing LocalizedText key/fallback system.

This is still not the full legacy-text migration, but it moves the highest-frequency UI surfaces onto translation-ready strings.

### QA changes

BalanceAudit now hard-checks:

- production recruitment timing envelope;
- 75-Gold onboarding range;
- 5-minute chunk pricing;
- early recruitment speed-up affordability;
- early Clinic recovery affordability.

DataValidation now rejects core/facility construction timers that fall back into the old prototype-compressed range.


## Release-readiness milestone

The first full headless QA run on Godot 4.7.2 passed project import, DataValidation, BalanceAudit, and SmokeTest before this milestone was started.

### Persistent onboarding

New saves now begin with a lightweight six-step tutorial:

1. understand the core city loop;
2. complete a recruitment job;
3. upgrade the Safehouse;
4. enter World view;
5. occupy a Driver or Spy Alliance support slot;
6. win the first raid.

Progress is persistent through save schema **18**.

Players can skip the tutorial at any time.

The onboarding is event-driven rather than modal: normal gameplay remains available while the current objective is displayed.

### Localization source

`localization/ui.csv` is now the translation-source spreadsheet for the keyed UI/faction/tutorial copy.

The project registers the generated English translation resource in `project.godot`.

LocalizedText still retains English fallbacks, so a missing/import-failed translation resource never leaves raw keys on screen.

High-frequency surfaces now use localization keys:

- Store
- Territory Command
- Progression
- Achievements
- Rewards
- Events
- Profile/mailbox
- Combat tactics
- Tutorial

Legacy content strings such as individual mission descriptions and raid data can continue moving into the same catalog without changing the architecture.

### Presentation asset replacement hooks

Procedural visuals and generated audio remain safe fallbacks, but PresentationCatalog now checks documented replacement paths.

See `assets/README.md`.

If replacement PNG/OGG files are present, they are used automatically for:

- Safehouse
- Clinic
- Barracks
- Garage
- Intel Office
- Scrapyard
- Data Hub
- raid-target art
- UI click
- reward sound
- raid victory/defeat sound

This allows real art/audio to be integrated incrementally without rewriting gameplay systems.

### Windows + Android export presets

`export_presets.cfg` now defines:

- **Windows Desktop** debug/release packaging;
- **Android** ARM64 APK packaging using package ID `com.betasio.concretedominion`.

Godot requires export templates for command-line packaging, and Android requires JDK/SDK tooling. The CI workflow now installs Godot export templates, JDK 17, Android platform/build-tools 35, then attempts both exports.

CI artifacts:

- `concrete-dominion-windows-debug`
- `concrete-dominion-android-debug`

The Android artifact is an unsigned-store-development/debug-style build path for QA, not a Google Play release package. Production publishing still requires secure release signing/credentials outside version control.


## Approved visual-art integration

The approved Concrete Dominion city-building art direction is now active in gameplay.

A compact generated sprite atlas supplies:

- Safehouse
- Underground Clinic
- Crew Barracks
- Garage
- Intel Office
- Scrapyard
- Data Hub
- raid-target visual

The atlas is decoded at runtime by `PresentationCatalog`, cached once, and exposed as named `AtlasTexture` slices. This keeps the project lightweight while giving all major city structures a consistent dark-concrete / warm-gold / selective-neon style.

The map renderer still retains procedural fallback art, so a corrupt or missing visual pack cannot make the game unplayable.

CI now verifies:

- all three embedded atlas payload parts exist;
- the WebP payload decodes successfully;
- the decoded atlas is exactly 320×160;
- all eight named art slices resolve to valid textures.

Individual loose PNGs can override atlas entries later without changing gameplay code.
