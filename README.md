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
