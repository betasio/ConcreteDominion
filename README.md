# Concrete Dominion

A cross-platform 2.5D isometric RTS prototype built with **Godot 4** and GDScript.

## Base / World / Alliance milestone

The prototype now has three distinct layers of play:

### Base view

Use **BASE** to return to the player's district.

Base view focuses on:

- Safehouse
- Underground Clinic
- Crew Barracks
- build lots
- upgrades
- recruitment
- healing

Raid targets are hidden so the base screen feels like a management space instead of a crowded world map.

### World view

Use **WORLD** to switch to the raid district.

World view:

- hides base-building interactions
- zooms the strategy camera outward
- shows Banks and Turf HQ raid targets
- displays raid convoys
- allows target selection and raid preparation

The current view is persisted in the local save.

## Alliance Hub

The new **Alliance** button opens a persistent social/activity panel.

The Alliance Hub currently includes:

- activity/message feed
- active raid invite status
- invite countdown
- joined-member list
- create raid invite action
- join invite as Driver
- join invite as Spy
- prototype message posting

The message feed and active invite are saved locally.

## Raid invitations

Select a world target and press:

**Invite Alliance to Selected Target**

A 15-second invite opens.

Simulated alliance members respond over time:

- Mia can respond as Driver
- Noah can respond as Spy
- Kira can respond if she is currently online

The joined-member list updates while the invite is active.

The local player can join as Driver or Spy if the required specialist troop is available.

Joining an invite focuses the invited target in **World view**, preserving the existing raid-slot and contribution system.

## Alliance simulation

Current prototype members:

- Vex — frontline
- Mia — Driver
- Noah — Spy
- Kira — Driver
- You — Driver or Spy

The raid lobby still handles:

- explicit role slots
- online/offline members
- named contribution scores
- frozen participant snapshots
- shared Cash reward pools
- local loot eligibility

The social system sits above that combat model rather than duplicating it.

## Persistence

Save version 6 now tracks:

- Cash and Gold
- loot inventory
- troop roster
- buildings and build lots
- healing
- recruitment
- construction
- active raids
- target cooldowns
- alliance presence and raid slots
- alliance activity feed
- active raid invite
- Base / World view selection

Offline time is applied to gameplay timers and raid invitations.

## Suggested test

1. Start in **BASE**.
2. Open the Clinic or Barracks to verify base interactions.
3. Press **WORLD**.
4. Select Downtown Bank or Harbor Bank.
5. Open **Alliance**.
6. Create an alliance raid invite.
7. Watch Mia/Noah respond during the invite countdown.
8. Join the invite as Driver or Spy.
9. Confirm the invited target is focused in World view.
10. Open/preview the raid and inspect the named alliance slots.
11. Launch the raid and review contribution/reward sharing.
12. Restart the game and confirm the selected view and social feed persist.

## Architecture

```text
Main
├── PlayerEconomy
├── LootInventory
├── AllianceManager
├── AllianceSocial
├── TroopRoster
├── HospitalQueue
├── ConstructionQueue
├── RecruitmentQueue
├── SynergyRaid
├── RaidBattle
├── SaveManager
├── CityMap
└── HUD
```

### AllianceManager

Owns durable alliance gameplay state:

- members
- presence
- role preferences
- raid slot assignments

### AllianceSocial

Owns prototype social state:

- activity feed
- raid invites
- invite countdown
- simulated invite responses

### CityMap

Now owns the presentation mode:

- `base`
- `world`

This keeps the world/base distinction separate from HUD button implementation.

## Production direction

The current alliance feed and invitation responses are local simulations.

A future backend can replace them with:

- real alliance membership
- presence events
- chat messages
- push notifications
- raid invitation events
- server countdown timestamps
- authoritative slot reservation

The game-facing interfaces can remain largely the same.

## Next strong milestone

Good next additions are:

- route-based convoy movement along streets instead of straight lines
- alliance profile/member detail cards
- join/leave/invite-to-alliance flow
- unread alliance notifications
- a polished raid result overlay
- simple impact/explosion/combat VFX
- target reward crates and inventory-use mechanics
