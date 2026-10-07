# Presentation replacement hooks

Concrete Dominion can run entirely with the procedural fallback presentation, but the runtime now checks these paths for replacement assets.

## Building art

Place transparent PNGs at:

- `assets/art/buildings/safehouse.png`
- `assets/art/buildings/clinic.png`
- `assets/art/buildings/barracks.png`
- `assets/art/buildings/garage.png`
- `assets/art/buildings/intel_office.png`
- `assets/art/buildings/scrapyard.png`
- `assets/art/buildings/data_hub.png`
- `assets/art/world/raid_target.png`

The renderer scales these into the existing isometric footprints. If a file is absent, the procedural art remains active.

## Audio

Place OGG files at:

- `assets/audio/ui/click.ogg`
- `assets/audio/ui/reward.ogg`
- `assets/audio/combat/raid_victory.ogg`
- `assets/audio/combat/raid_defeat.ogg`

If an audio file is absent, AudioManager falls back to the generated tone.

Do not commit licensed/source assets unless their redistribution rights are clear.
