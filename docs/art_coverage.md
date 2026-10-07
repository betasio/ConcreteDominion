# Art coverage and next visual wave

This document is the source of truth for Concrete Dominion's presentation coverage.

## Runtime art that is integrated now

The current build ships with and actively wires:

- branded application icon;
- Safehouse;
- Underground Clinic;
- Crew Barracks;
- Garage;
- Intel Office;
- Scrapyard;
- Data Hub;
- generic fortified raid target;
- dark-gold panel frame;
- compact status/top bar;
- dark button state;
- gold/highlight button state;
- street intersection art;
- straight street art.

The city assets use the approved charcoal-concrete, matte-black, warm-gold visual language, with selective red security accents and cyan intelligence/data accents.

The logical city grid, hit targets, routing and responsive UI containers remain independent of the replacement art. Procedural rendering remains available as a fail-safe so presentation changes cannot make the game unplayable.

## Automated coverage

`ArtCoverageAudit.tscn` now verifies in headless CI that:

- the configured application icon exists;
- the embedded city atlas decodes and has the expected dimensions;
- all eight required city slices resolve;
- core buildings receive art textures at runtime;
- all four buildable facilities receive art textures at runtime;
- all raid targets receive an art texture at runtime;
- the UI/street atlas loads and has the expected dimensions;
- all six required UI/street slices resolve.

This is separate from the general smoke test so future art changes have a clear failure signal.

## Visuals that are intentionally still in the next art wave

These are not blockers for the current playable build, but they are the strongest next presentation upgrades:

1. Named character portraits: Vex, Mia, Noah, Kira, rival bosses and story NPCs.
2. Unit portraits: Enforcer, Driver and Spy variants.
3. Faction identity: emblems, color accents and boss portraits for Dock Rats, Iron Serpents, Meridian Boys, Northside Crew and Velvet Circle.
4. District identity: unique environment/target art for Downtown, Harbor, Midtown, Northside, Casino, Financial and Industrial.
5. Vehicle and convoy variants.
6. Story/event chapter banners and result illustrations.
7. Achievement badge art.
8. Seasonal/event skins.
9. Final authored audio replacing the current generated/fallback tones.

## Consistency rules for future generated art

New art should preserve:

- premium 2.5D/isometric crime-strategy presentation;
- dark graphite/charcoal concrete and matte black;
- restrained warm gold as the main prestige/accent color;
- red only for threat/security/medical urgency;
- cyan only for intelligence/data/advanced technology;
- strong silhouettes readable on mobile;
- realistic material wear without muddying small-scale readability;
- no unrelated fantasy, neon-cyberpunk or cartoon language.

Character and faction art should feel like it belongs to the same city as the current buildings and UI rather than becoming a separate visual style.
