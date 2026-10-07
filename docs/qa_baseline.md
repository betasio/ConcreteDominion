# Concrete Dominion QA Baseline

This file records the deterministic balance assumptions enforced by the headless QA suite.

## Progression

- XP required from Account Lv.1 to Lv.7: **1,725**
- Sum of raw XP from one clear of all seven raid tiers: **1,910**
- Starter Cash: **$25,000**
- Starter Gold: **250**

## City economy

- Core buildings Lv.1 -> Lv.5 total: **$215,000**
- Four buildable facilities including construction + Lv.5 upgrades: **$447,000**
- Combined current city-development sink: **$662,000**
- Full captured-city passive income: **$11,000/hour**
- Sink / full-city income: **~60.2 hours**

These figures do not include troop recruitment, specialist upgrades, consumables, or repeated combat costs.

## Reference raid curve

The reference profile is deliberately alliance-oriented rather than a solo-player model.

Balanced reference tiers use:
- Vex baseline frontline power;
- level-appropriate Alliance progression;
- level-appropriate specialist progression;
- level-appropriate Garage/Intel Office progression;
- matching weakness role;
- matching level-1 equipment perk;
- no paid power.

Financial and Industrial additionally use the earnable **Blitz** preset and **Intel Burst** consumable.

| Target | Effective HP | Reference damage | Ratio |
| --- | ---: | ---: | ---: |
| Downtown Bank | 9,000 | 13,171 | 1.46 |
| Harbor Bank | 11,550 | 14,028 | 1.21 |
| Midtown Exchange | 13,176 | 16,179 | 1.23 |
| Northside Turf HQ | 14,520 | 18,638 | 1.28 |
| Casino Vault | 18,515 | 20,400 | 1.10 |
| Financial Tower | 24,000 | 27,844 | 1.16 |
| Industrial Depot | 27,140 | 28,086 | 1.03 |

## Specialist usefulness guardrail

At the early reference baseline:

- adding a local Driver increases raid damage by roughly **11.3%**;
- adding a local Spy increases raid damage by roughly **13.5%**.

The automated floor is **10%** for each role.

## Known prototype warning

Current timers are intentionally seconds/minutes rather than production live-service durations. With 250 starter Gold, speed-ups are consequently much more affordable than they should be in a final economy.

This is a **warning**, not a CI failure, until production-scale timing is selected.

## Hard-failure philosophy

CI should fail for structural regressions:
- invalid/missing data;
- broken scene/resource loading;
- duplicate IDs;
- reversed progression tiers;
- impossible reference raids;
- specialist usefulness below design floor;
- save-schema regression.

CI should warn, not fail, for deliberate tuning choices still under iteration.
