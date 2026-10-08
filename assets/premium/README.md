# ConcreteDominion premium building sprites

This is the first integration step for the high-detail isometric art style chosen for the game.

The game now looks for these **optional** individual textures:
`res://assets/premium/buildings/safehouse.png`,
`hospital.png`, `barracks.png`, `garage.png`,
`intel_office.png`, `scrapyard.png`, and `data_hub.png`.
A future `vault.png` is prepared for a future vault building; it is **not** gameplay-enabled.

The user-supplied building references can be turned into individual PNGs with
`python tools/build_premium_assets.py SOURCE_DIR assets/premium/buildings`
(requires Pillow). The command expects eight files named as above.

The playable Building and BuildLot scripts look for these textures at runtime.
When not present, original vector/SVG artwork remains available and the game
loads normally. Constructible facilities retain their empty-lot and construction
graphics until built. All economy, unlock, construction, selection and save
logic is unchanged.

## Art rules

- Same fixed isometric viewing angle, camera elevation and lighting direction.
- Deep charcoal stone, gunmetal, muted gold; warm window lights.
- Red beacons for security, blue only for technology/intelligence.
- No baked names, levels or UI badges into building pixels; draw these in Godot.
- Separate 768×768 RGBA sprites; transparent exterior and centered footprints.
- Avoid large shadows and oversized compound walls blocking adjacent buildings.
- Review edges after automated matte extraction; small black artefacts may need
  manual refinement, especially around gates and cables.
- Full-size render previews are not equal to an in-engine art/performance review.

The premium PNG pack is a generated binary deliverable and is not committed by
this text-only GitHub integration workflow. Place the generated `assets/premium`
directory inside the project to enable the high-detail textures. The CI build
therefore verifies the optional loader and existing fallback scenes, but does
**not** validate how these new PNGs look on real devices until they are added.
