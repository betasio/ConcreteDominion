# Concrete Dominion QA Baseline

This file records the deterministic balance assumptions enforced by the headless QA suite.

## Progression

- XP required from Account Lv.1 to Lv.7: **1,725**
- Sum of raw XP from one clear of all seven raid tiers: **1,910**
- Starter Cash: **$25,000**
- Starter Gold: **75**

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

## Production timing baseline

The project now uses an initial production-scale timing pass rather than second-long prototype queues.

Base recruitment:
- Enforcer: **20s/troop**
- Driver: **30s/troop**
- Spy: **36s/troop**

Clinic:
- **45s per wounded troop** before Clinic-level reductions.

Construction examples:
- core-building base upgrade steps: roughly **4–5 minutes x current level**
- Garage build: **6 minutes**
- Intel Office build: **8 minutes**
- Scrapyard build: **10 minutes**
- Data Hub build: **12 minutes**

Gold speed-ups are charged in **5-minute chunks**:
- recruitment: **1 Gold/chunk**
- construction: **2 Gold/chunk**
- Clinic: **1 Gold/chunk**

Reference onboarding examples:
- recruit 5 Enforcers instantly: **1 Gold**
- finish a 10-minute construction timer: **4 Gold**
- instantly recover 5 standard wounded troops: **1 Gold**

Existing saves retain their current Gold and in-progress timer values; the new defaults apply to new jobs/new saves.

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
