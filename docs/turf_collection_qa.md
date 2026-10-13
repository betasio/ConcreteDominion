# Turf collection QA — 2026-10-13

New generated world art, enlarged civic compounds, local HQ appearances and
exclusive skin bonuses. Home estate placements are preserved.

Verified locally with Godot 4.7.2 and isolated saves:
- 51 Python server tests pass, including private premium ownership and unchanged
  landmark scoring.
- ProjectResourceAudit loads 179 resources without script errors.
- TurfSkinAudit passes real NPC damage, fractional production/collection,
  ownership, save persistence and reserved landmark geometry checks.
- WorldMapAudit, GameFunctionalityAudit, EstateCameraAudit, EstateHUDAudit,
  GameplayRegressionAudit, EstateDistrictAudit and ResourceEconomyAudit pass.
- Real HTTP city probe passes at 1280×720, 390×844 and 640×360, with generated
  screenshots under ignored `build/previews/online_city_*.png`.
- Rendered turf collection audit checks portrait bounds and produces
  `build/previews/turf_collection_390x844.png`.

The display driver reports unsupported VSync and the pre-existing one-object
shutdown leak. No script/runtime errors are accepted by the QA runners.

Checkout, peer appearance synchronization and server-authoritative HQ progression
are not implemented in this change; see `world_map.md` for the exact bonus scope.
