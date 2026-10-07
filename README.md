# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with Godot 4 and GDScript.

## Territory control + world endgame milestone

The World map now has a persistent territory-control loop instead of functioning only as a raid-target selector.

## District discovery and fog

Only Downtown Core is discovered by default on a fresh save.

Higher districts are hidden by fog until they are discovered.

Districts can be revealed in two ways:

- spend Intel through Territory Command;
- use the Safehouse Command Scan when its cooldown is ready.

A district still respects its Account Level requirement before it can be discovered.

Current Intel reveal costs:

- Downtown Core: free/default
- Harbor District: Intel x1
- Midtown: Intel x1
- Northside: Intel x2
- High Roller Strip: Intel x2
- Financial District: Intel x3
- Industrial Belt: Intel x3

Fogged targets are not selectable, focusable, or eligible for automatic Alliance raid invites.

### Schema-14 migration

Existing players are protected from losing access when upgrading to the fog system.

When a pre-schema-15 save is migrated, districts up to the player's saved Account Level are marked discovered automatically.

Ownership is not granted by migration; turf still has to be captured through gameplay.

## Turf ownership

Winning a district's main raid for the first time captures that district.

Captured turf is persistent and begins generating passive Cash.

Ownership is not lost on patrol failure. This keeps territory progression meaningful without creating rage-quit losses.

## Passive district income

Owned districts generate Cash continuously.

Current base rates:

- Downtown Core — $600/hour
- Harbor District — $850/hour
- Midtown — $1,100/hour
- Northside — $1,450/hour
- High Roller Strip — $1,800/hour
- Financial District — $2,300/hour
- Industrial Belt — $2,900/hour

Income is capped at eight hours of production.

Offline time contributes to the bank up to the same cap.

The Territory panel shows:

- current Cash/hour;
- banked Cash;
- district ownership/discovery state;
- collect action.

Collecting income contributes to Alliance tasks.

## Safehouse Command Scan

Safehouse now has an active command function in addition to its passive construction/reward bonuses.

Command Scan reveals the next Account-Level-eligible fogged district without spending Intel.

Base cooldown:

10 minutes.

Each Safehouse level above Lv.1 shortens the cooldown by one minute, with a minimum of three minutes.

This gives Safehouse progression a visible strategic map function instead of only background percentages.

## PvE patrol encounters

Owned territory periodically generates a patrol threat.

Prototype patrol interval:

90 seconds while the game is active.

Each patrol has district-scaled Enforcer power requirements.

The player can resolve it from Territory Command.

If player Enforcer power meets the threat:

- the patrol is cleared;
- Cash is awarded;
- higher-tier patrols can drop Intel;
- Alliance task progress is awarded.

If the patrol is stronger:

- ownership is retained;
- no troops die permanently;
- at most one Enforcer is sent to the Clinic.

This creates lightweight map maintenance without undermining the project's no-permanent-death pillar.

## Alliance tasks

Territory Command now contains shared Alliance objectives.

Current prototype tasks:

### Hit the Streets
Win 3 raids.

Reward:
- 70 Alliance XP
- $4,000 Cash

### Keep It Moving
Collect turf income twice.

Reward:
- 55 Alliance XP
- $3,000 Cash

### Clean the Block
Clear 2 patrols.

Reward:
- 85 Alliance XP
- $5,000 Cash

Alliance task rewards feed the same persistent Alliance Level/XP system introduced previously.

## Territory UI

A new **Territory** shortcut opens Territory Command.

The panel includes:

- passive-income rate and bank;
- district fog/discovery/ownership state;
- next eligible Intel reveal;
- Safehouse Command Scan timer;
- active patrol threat;
- Alliance task progress.

The UI participates in the existing safe-area and large-text systems.

## Save system

Save schema is now **version 15**.

New persistent state:

- discovered districts;
- owned districts;
- passive-income bank;
- production timing;
- patrol timing;
- active patrol;
- Safehouse Command Scan cooldown;
- Alliance task progress.

Offline time advances passive income and Command Scan cooldown.

The crash-safe backup path is also restored in the active save flow: before the primary save is overwritten, the last valid primary document is copied to the backup slot.

## Architecture additions

```text
Main
├── WorldControlManager
└── WorldControlUI

scripts/world/
└── WorldControlManager.gd

scripts/ui/
└── WorldControlUI.gd

scenes/ui/
└── WorldControlUI.tscn
```

WorldControlManager owns world-economy/discovery state.

CityMap remains responsible for visual map presentation and target positioning.

RaidBattle remains responsible for raid resolution.

AllianceManager remains responsible for persistent Alliance progression.

## Recommended eventual test path

When final testing starts:

1. Start a new game and enter World view.
2. Confirm only Downtown is visible.
3. Defeat Downtown and verify it becomes OWNED.
4. Wait or simulate time and collect Downtown passive Cash.
5. Reach Lv.2 and use Safehouse Command Scan to reveal Harbor.
6. Defeat Harbor and confirm total Cash/hour increases.
7. Use Intel to reveal Midtown.
8. Confirm a fogged target cannot be selected through Alliance shortcuts.
9. Allow a patrol to spawn.
10. Clear it with sufficient Enforcer power.
11. Try a stronger patrol with insufficient power and confirm only Clinic recovery occurs.
12. Complete all three Alliance tasks.
13. Restart and confirm discovery, ownership, income, patrol, Command Scan, and task state persist.
14. Test an older schema-14 save and confirm level-eligible districts remain discovered.
15. Run the smoke-test scene.

## Next development direction

The strongest next milestone is now content breadth and final-system depth:

- resource-production buildings and collection visuals;
- additional build lots;
- district ownership visual overlays;
- NPC factions and rival turf pressure;
- richer patrol encounter types;
- alliance task refresh cycles;
- localization-ready text resources;
- economy simulation/balance spreadsheet;
- real art/audio integration;
- final runtime/device QA.
