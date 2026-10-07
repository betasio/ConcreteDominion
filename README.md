# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Strategic raid loadout milestone

Raids now have a real pre-battle strategy layer instead of only choosing alliance support slots.

### Tactics panel

A new **TACTICS** shortcut opens the pre-raid loadout panel.

Players can configure:

- risk plan;
- specialist equipment;
- equipment/perk upgrades;
- one-raid consumables;
- target counter-role planning.

The selected setup is persistent.

## Risk plans

Three raid plans are available.

### Balanced
- normal damage;
- normal rewards;
- normal injury severity.

### Blitz
- +12% final damage;
- +10% Cash and XP rewards;
- +35% injury severity.

### Cautious
- -6% final damage;
- -5% Cash and XP rewards;
- -35% injury severity.

This creates a real risk/reward choice without introducing permanent troop loss.

## Specialist equipment and perks

The player can equip one specialist kit.

### Turbo Kit — Driver
Improves raid effectiveness when Driver support is present.

### Signal Jammer — Spy
Improves raid effectiveness when Spy support is present.

### Ballistic Rig — Enforcer
Improves raid effectiveness when frontline power is present.

Each equipment role has its own persistent perk level.

Upgrades consume existing raid loot:

- Parts;
- Intel.

Each perk level adds another 3% matched-role damage multiplier.

## Consumable boosts

Two optional consumables can be selected.

### Intel Burst
- costs Intel x1 at raid launch;
- +10% final raid damage.

### Armor Plates
- costs Parts x1 at raid launch;
- reduces injury severity by 35%.

Choosing **None** has no cost.

Consumables are charged only when a valid raid actually launches.

## Target weaknesses

Every world target now has a recommended counter-role.

| Target | Weakness | Bonus |
| --- | --- | ---: |
| Downtown Bank | Driver | +8% |
| Harbor Bank | Spy | +12% |
| Northside Turf HQ | Driver | +12% |
| Casino Vault | Spy | +15% |
| Financial Tower | Enforcer/frontline | +15% |

The raid lobby displays the target weakness before launch.

If the alliance composition contains the matching role, the bonus is included in final raid damage.

## Full tactical preview

**Preview Alliance Damage** now uses the same calculation that will be frozen at launch.

The preview shows:

- projected battle grade;
- final damage versus effective target HP;
- alliance support multiplier;
- whether the target counter was matched;
- selected risk plan;
- equipment match;
- selected consumable;
- reward multiplier;
- injury-risk multiplier;
- named member contribution values.

This makes the battle calculation understandable before committing.

## Frozen battle snapshots

When a raid launches, the following values are frozen into the active battle:

- participant roster;
- calculated final damage;
- contribution scores;
- support bonus;
- target counter status;
- equipment status;
- risk plan;
- consumable;
- reward multiplier;
- injury multiplier;
- projected grade.

Changing the Tactics panel while the convoy is traveling therefore cannot alter an already-launched battle.

This also keeps offline save/load deterministic.

## Performance grades

Raid results now receive a grade based on final damage compared with target HP:

- **S** — 135%+ of target HP
- **A** — 115%+
- **B** — successful clear
- **C** — near miss
- **D** — significant miss

The animated result overlay and raid lobby both display the grade.

## Injury severity

Troops still **never die permanently**.

Instead, difficult battles can produce different injury severity:

- Minor
- Standard
- Serious
- Critical

Severity changes Clinic healing duration.

Risk plan, Armor Plates, victory/defeat, and target difficulty all contribute to the severity multiplier.

For example:

- Cautious + Armor Plates can significantly reduce recovery time;
- Blitz against Boss/Mythic targets can lead to Serious or Critical recovery;
- losing increases injury severity.

The Clinic queue now displays severity next to each wounded entry.

## Reward risk

Risk plans also affect successful raid Cash and XP:

- Blitz: x1.10
- Balanced: x1.00
- Cautious: x0.95

Loot drops remain target-defined and are not multiplied.

This avoids turning the aggressive option into an unlimited material multiplier.

## Persistence

Save version 11 now also stores:

- selected raid plan;
- equipped specialist role;
- selected consumable;
- equipment/perk levels.

Active raids already preserve the frozen tactical snapshot.

Clinic save data now includes:

- injury severity label;
- severity multiplier;
- remaining healing time.

## Architecture additions

```text
Main
├── CombatLoadout
├── RaidBattle
├── HospitalQueue
└── CombatStrategyUI

scripts/combat/
├── CombatLoadout.gd
├── RaidBattle.gd
└── HospitalQueue.gd

scripts/ui/
└── CombatStrategyUI.gd

scenes/ui/
└── CombatStrategyUI.tscn
```

`CombatLoadout` owns persistent player choices and perk levels.

`RaidBattle` owns the authoritative local prototype calculation and freezes the launch snapshot.

`RaidTargetData` owns each target's weakness role and counter bonus.

`HospitalQueue` translates injury severity into recovery duration.

## Suggested future test path

When the game reaches the final testing phase:

1. Select Downtown Bank.
2. Open TACTICS.
3. Compare Balanced, Blitz, and Cautious previews.
4. Match Downtown's Driver weakness.
5. Equip/upgrade Turbo Kit.
6. Select Intel Burst and confirm final damage increases.
7. Launch and verify the consumable is spent once.
8. Compare the projected grade with the final grade.
9. Try a higher-tier Boss/Mythic target with Blitz.
10. Check Clinic injury severity and healing time.
11. Repeat with Cautious + Armor Plates and compare recovery.
12. Restart during an active convoy and confirm the frozen result remains unchanged.

## Production note

The combat/loadout system is still client-authoritative in this prototype.

Before live multiplayer, the server must validate:

- loadout ownership;
- consumable spending;
- target weaknesses;
- participant snapshots;
- damage calculations;
- reward multipliers;
- grades;
- injuries;
- Clinic timers.

## Next strong milestone

The next major step should be **economy/balance hardening and production readiness**:

- central data tables for troop/building costs and timers;
- account progression tuning;
- Gold economy and speed-up pricing review;
- analytics/event hooks;
- settings/audio/haptics;
- accessibility options;
- mobile safe-area handling;
- error/debug panel;
- automated save migrations;
- final Godot runtime validation and bug-fix pass.
