# Whole-game functionality review

Scope: estate construction and expansion, troop training and healing, production,
NPC combat, chapter progression, retention rewards, factions, persistence, and
mobile/desktop navigation. The existing terrain and building placement remain
intact. This is a code and automated-runtime review, not a production launch sign-off.

## Findings and changes

| Area | Review outcome | This pass |
| --- | --- | --- |
| Saving and offline progress | Frequent subsystem signals restarted the autosave delay; the primary file was overwritten directly. Loaded offline settlement was not scheduled for saving. | Keep the first pending deadline, retry failed writes at a bounded interval, write and flush a temporary file before replacement, preserve the previous valid backup, and save settled state after initialization. |
| NPC combat | Launch could silently fail when the selected consumable was missing, while the raid panel displayed Ready. | Shared launch validation supplies an actionable blocker; loadout and inventory changes refresh readiness immediately. Preview/navigation never consume the item. |
| Chapters and city navigation | Players could read the next objective but had to find the relevant system themselves. | Mission strip and Tasks action route all 30 objectives across six chapters to training, the exact construction site, raid preparation, discovery, rewards, faction operations, or the existing chapter decision controls. Undiscovered raids route to discovery. |
| Camera and panels | A view transition could continue moving the camera after focusing a site; training opened a second selection panel underneath. | Focus stops the transition at the destination zoom, respects estate bounds, and the training objective opens one panel. |
| Construction, expansion and support buildings | Existing district audit covers chapter locks, build/upgrade transactions, income, hospital beds, training, gate and command effects. | No balance or placement changes. |
| Economy and retention | Production collection, selectable contract rewards, period boundaries and repeat-claim prevention have automated coverage. Earnable premium rewards are budgeted. | No new premium sinks or paid requirements. |
| Factions and multiplayer | Normal gameplay uses local faction simulation. The optional development backend has separate server-owned faction/PvP/rally state and tests. | No claim that local progression is live multiplayer. |
| Store | Billing is intentionally unavailable without a connected purchase backend. | Purchases remain disabled. |

## Verification

Before changes: DataValidation, BalanceAudit, GameplayRegressionAudit,
EstateDistrictAudit, ResourceEconomyAudit and EstateHUDAudit passed; the server
unit-test discovery run passed 31 tests.

After changes: GameFunctionalityAudit, GameplayRegressionAudit, EstateHUDAudit,
EstateCameraAudit and ResourceEconomyAudit passed. The new audit exercises live
Main scene wiring, sustained dirty signals, failed-save retry, backup recovery,
consumable blockers, all 30 chapter destinations, and navigation without spending.
It requires a fresh XDG_DATA_HOME and refuses to overwrite an existing save.
Registered in GitHub QA.

IllustratedEstateScreenshot captured the actual rendered desktop/portrait views,
including Tasks and its training destination. These two panels were visually
inspected; the HUD audit also checks five viewport sizes. Local checks do not
replace device-store export testing or a real multi-device playtest.

## Recommended next work

1. The online faction/rally path now settles a server-owned faction war chest and
   personal Command XP, with earned Rally Hall upgrades (see server/README.md).
   Next, establish verified sign-in and a server-owned estate progression model
   before competitive multiplayer or purchases affect the main estate economy.
   Keep solo NPC progress available.
2. Give city operations and faction wars a clearer strategic overview: ownership,
   pending attacks, preparation time and the consequences of committing troops.
3. Continue simplifying the dense secondary screens and first-session guidance.
   Preserve explicit confirmations for spending and launching actions.
4. Validate retention and monetization with playtest data before adjusting pacing.
   Current deterministic tests establish invariants, not long-term player enjoyment.
