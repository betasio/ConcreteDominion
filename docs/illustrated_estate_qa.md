# Illustrated estate alignment

This pass aligns the playable facilities to the illustrated estate and gives
Data Hub a dedicated seventh terrace. It preserves the existing `CityMap`
nodes, save IDs, construction queue, premium building art, hybrid 3D HQ and
4K HQ textures.

The original terrain has six pads. `data_hub_terrace.png` is a new transparent
terrain sprite generated to match that artwork, with an empty courtyard and
an entrance bridge. It is drawn after the original terrain so the bridge joins
the eastern drive. No interactive building is painted into either terrain layer.

## Layout and interaction

`IllustratedEstateLayout.gd` owns the shared texture-to-world transform and pad
coordinates. The original PNG remains 941 × 1672. Its centers are:

| Site | Artwork coordinate |
| --- | --- |
| HQ | 721, 375 |
| Clinic | 414, 545 |
| Barracks | 215, 711 |
| Garage | 284, 963 |
| Intel Office | 773, 800 |
| Scrapyard | 675, 1130 |
| Data Hub annex | 955, 1020 |

The annex's gold-diamond anchor is at pixel (754, 586) of its own 1254 × 1254
texture. Moving its layout coordinate moves its art and interactive lot together.

Empty and constructing lots use compact plus/hammer markers. Construction never
falls back to an opaque foundation slab on illustrated terrain. Built facilities
retain their premium art, level and upgrade state. Contrast-backed labels replace
bare text over the roads and planting. Each lot has its own diamond collision
shape covering its pad; changing one does not mutate the shared scene resource.

The estate camera fits the viewport aspect, including portrait, and the coastal
panorama covers the visible area during zoom and pan. World mode keeps its
separate camera behavior. Setting `concrete_dominion/preview_illustrated_terrain`
to `false` before instantiating the map retains the previous procedural layout.

## Validation

Validated locally with Godot 4.7.2 and Python 3.12.14:

- Project import and resource audit (153 scripts/scenes/data resources).
- DataValidation, BalanceAudit, SmokeTest, ArtCoverageAudit and GameplayRegressionAudit.
- EstateCameraAudit: 1280 × 720, 720 × 1280 and 1080 × 2340; all seven sites
  framed; pinch input, zoom limits, camera bounds and world-mode restoration.
- IllustratedEstateAudit: pad-center and pad-edge physics hits, touch selection,
  real construction/upgrade transactions, pending-job restoration, built-state
  save restoration, annex alignment/visibility and procedural fallback.
- 27 Python API, concurrency, security and asset tests.
- Actual OpenGL renders with Mesa software rendering: empty, constructing, built,
  portrait, and portrait close-up. These are game captures, not concept images.

Run the added interaction audit from the repository root:

```sh
godot --headless --path . res://scenes/tests/IllustratedEstateAudit.tscn
godot --headless --path . res://scenes/tests/EstateCameraAudit.tscn
```

The interaction audit is included in `.github/workflows/godot-qa.yml`.
The existing illustrated screenshot scene now produces state/aspect variants,
all covered by the workflow's `turf_illustrated_*.png` artifact glob:

```sh
# Requires a graphical display, e.g. the workflow's Xvfb.
# Use a fresh data directory to isolate captures from personal saves.
XDG_DATA_HOME="$(mktemp -d)" godot --path . --audio-driver Dummy \
  --rendering-driver opengl3 res://scenes/tests/IllustratedEstateScreenshot.tscn
```

Images are written to `build/previews/`. The capture disables edge panning and
autosave so pointer position and visual test states do not affect saved progress.

GitHub run 38079558699 could not be inspected: the environment's GitHub API proxy
returned HTTP 403. Local inspection began at its commit, `24cc54f`, also the
remote `main` tip when checked. Windows/Android exports and physical-device GPU,
touch and texture-memory performance were not tested in this pass. Desktop
portrait captures do not establish Android device compatibility or certification.
The software-rendered capture exits successfully but reports unsupported V-Sync
and one `AudioStreamGeneratorPlayback` object remaining at shutdown. The audio
shutdown warning remains unresolved; no audio-system changes are included here.

## Responsive estate interface

The follow-up UI pass uses the supplied reference's portrait hierarchy: original
boss portrait, black/gold resources and power header, side action rails, a chapter
bar, and six bottom destinations. Cash, Gold, Parts, Intel, power, chapter progress,
and unclaimed-mail counts come from the existing game systems. No VIP or offer
status is invented. Mail opens the existing profile/inbox panel; Crew opens the
existing recruitment panel. More retains all nine secondary destinations.

`EstateHUD.gd` owns the new chrome; `EstatePanelLayout.gd` makes the existing dialogs
readable and scrollable without replacing their action buttons or signal handlers.
The tutorial stays above the navigation and hides while a dialog is open.
Construction retains its live finish-now bar in the chapter bar's space.
UI fonts use distance fields to stay sharp when scaled. The large-text setting
updates both chrome and dialog text. The added `assets/ui/boss_portrait.png` is an
original generated portrait, separate from the existing character atlas.

The new EstateHUDAudit passes at 1280 × 720, 720 × 1280, 360 × 640,
640 × 360 and 1080 × 2340. It checks actual resource/mail updates, navigation,
dialog bounds, scrolling availability, all nine More actions, build selection,
world/estate switching, construction/chapter bar transitions, tutorial bounds,
large-text settings, at least 44-pixel navigation/rail
hit areas, and GUI-routed touch taps and outside-tap dismissal. It runs in CI.

```sh
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . res://scenes/tests/EstateHUDAudit.tscn
```

Fresh actual renders include `turf_illustrated_portrait_hud.png`,
`turf_illustrated_portrait_tasks.png`, `turf_illustrated_portrait_training.png`,
`turf_illustrated_portrait_more.png`, `turf_illustrated_landscape_phone.png`, and
`turf_illustrated_portrait_tutorial.png`, and
`turf_illustrated_portrait_construction_hud.png`. These supplement the map/state captures.

This is a first playable step toward the reference's composition, not visual
parity with a finished commercial game. Existing building textures, character
atlas portraits, terrain seams, and world-space map labels still have different
levels of detail. Physical Android rendering, safe-area cutouts, touch scrolling,
and memory/performance need device testing. Headless touch injection verifies
routing but does not substitute for that testing. The GitHub QA API retry still
returned Forbidden; all results reported here are local.

## Footprint, camera and atmosphere refinement

Keep the current 2.5D pipeline: transparent PNG facilities plus the existing
single-render 3D HQ. For a fixed isometric camera this avoids rebuilding the game
in 3D. Future buildings can be authored in 3D and rendered to PNG using a shared
camera/light rig; runtime 3D is useful if camera rotation or animated structures
become an actual requirement.

`PAD_HALF_SIZES` now records each courtyard's usable footprint. PNG width fits
94% of that footprint and a normalized ground anchor (0.5, 0.74) places the base
on its site, preserving the source aspect ratio and exposed access stairs.
The HQ render has a separate calibrated scale. Core buildings now use matching
courtyard collision diamonds rather than the old oversized selection boxes.
Map badges use distance-field text; mipmaps and linear filtering remove the
sparkling high-frequency edges on downscaled buildings and terrain. Mipmaps add
texture memory, so physical-device profiling remains necessary.

The live Golden Bay shader now uses cooler distance grading, horizon haze,
open-water/reflection motion and high-cloud drift in one pass. Its animation
clock stops with Reduced Motion. The backdrop's parallax and higher horizon
reinforce the separation between the estate and distant city. It remains an
illustrated panorama, not a 3D environment or a simulated ocean.

The camera ignores menu interactions, stops stale gestures when a release lands
over UI, and zooms around the cursor or pinch midpoint. Side captions have dark
backing for contrast; Events uses a calendar icon distinct from Rewards.

Validation for this refinement: resource audit, smoke test, camera audit,
illustrated-estate audit and responsive-HUD audit passed. Added checks cover
core footprint hits, cursor zoom stability, gesture release, modal camera lock,
and Reduced Motion stopping/resuming the scenery clock. Actual empty/built and
HUD captures were reviewed, including `turf_illustrated_portrait_built.png`.
A two-frame shader probe at animation times 0 and 12 seconds measured changed
sky/water pixels and exactly unchanged pixels across the skyline region.
Backend logic was unchanged, so the Python suite was not rerun for this pass.

## Illustrated black-and-gold interface

The estate HUD now uses an original generated 16-icon atlas, shared through
`EstateSkin.gd`, and six small SVG textures for scalable metallic frames.
The resource strip, circular side controls, chapter bar, illustrated bottom
navigation and portrait faction shortcut follow the supplied visual references.
Resource amounts and notifications remain live game data. Existing dialogs use
the same charcoal-and-gold frames and buttons, preserving their scrolling and
gameplay handlers. The atlas is cached, mipmapped and reused across controls.

Building names and levels share one framed badge. Portrait camera framing is
slightly closer, but this pass retains the existing terrain and calibrated
seven-site layout. Matching the reference's continuous cliffside estate will
require a separate terrain artwork pass; this UI update does not provide it.

Validation: ProjectResourceAudit (154 resources), SmokeTest, EstateCameraAudit,
IllustratedEstateAudit and EstateHUDAudit passed. Actual graphical captures were
reviewed for portrait HUD, dialogs and small landscape presentation. The capture
scene also saves `turf_illustrated_portrait_built_hud.png` for inspection of all
facilities with the interface visible. Rendering was tested using desktop
OpenGL with software rendering; physical mobile performance remains unmeasured.
