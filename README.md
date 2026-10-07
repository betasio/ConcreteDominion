# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## End-to-end playable loop

The project now has a complete prototype progression/combat loop:

1. Earn/spend shared Cash and Gold.
2. Upgrade buildings or construct the Garage/Intel Office.
3. Recruit Enforcers, Drivers, and Spies.
4. Open **Alliance Raid** and configure support.
5. Preview expected raid damage.
6. Launch against the **Downtown Bank**.
7. Wait through the raid launch countdown.
8. Resolve victory or defeat automatically.
9. Receive Cash on victory.
10. Wounded crew are removed from the active roster and sent to the Clinic.
11. Heal them over time or spend Gold for instant recovery.
12. Progress and active timers persist across restarts.

## Downtown Bank raid

Current prototype target:

- Target: Downtown Bank
- HP: 9,000
- Difficulty: Medium
- Reward: $7,500 Cash
- Frontline ally: AllianceBoss, 6,000 power
- Driver support: +10% each
- Spy support: +12% each

This intentionally makes support meaningful. A powerful frontline account alone does not clear the target; alliance support must multiply its contribution.

### Battle wounds

There is still **no permanent troop death**.

After raid resolution:
- some Enforcers may be wounded;
- a defeat can also wound participating Drivers and Spies;
- wounded units immediately leave the active troop roster;
- the Underground Clinic restores them after treatment.

## Persistence

The local save tracks:

- Cash and Gold
- troop roster
- building levels and built lots
- construction timer
- recruitment timer
- Clinic queue
- active raid countdown
- most recent raid result

Offline time advances construction, recruitment, healing, and an active raid countdown.

The save is stored under Godot's `user://` application-data folder.

## Suggested test

1. Pull the latest `main` and run the game.
2. Open **Alliance Raid**.
3. Preview with no support.
4. Add Drivers and Spies and preview again.
5. Recruit more specialists if you need more support.
6. Launch the raid.
7. Watch the countdown resolve into victory/defeat.
8. Check Cash after a victory.
9. Open **Crew** and notice wounded units are absent.
10. Open **Clinic** and heal them.
11. Close/reopen the game during a raid or healing timer to test persistence.

## Architecture

```text
Main
├── PlayerEconomy
├── TroopRoster
├── HospitalQueue
├── ConstructionQueue
├── RecruitmentQueue
├── SynergyRaid        # contribution math
├── RaidBattle         # target/countdown/outcome/rewards/wounds
├── SaveManager
├── CityMap
└── HUD
```

`SynergyRaid` only calculates alliance contribution math. `RaidBattle` owns encounter state and resolution. That separation lets us add multiple target types later without duplicating alliance-support logic.

## Production security note

This remains a client-side prototype. Local saves and the system clock can be manipulated. Before a real F2P economy or multiplayer launch, currency, inventories, timers, raid rosters, battle resolution, and rewards must become server-authoritative.

## Next milestone

Strong next additions are:
- multiple world-map raid targets with different HP/rewards;
- target cooldowns and respawns;
- alliance lobby/player list rather than simulated members;
- combat animations and result presentation;
- data-driven balance resources for troops/buildings/targets.
