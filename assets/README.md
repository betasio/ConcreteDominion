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


## Approved generated city atlas

The approved dark-luxury isometric building direction is now integrated into the runtime.

The primary runtime pack is embedded as a compact WebP payload split across:

- `assets/generated/city_atlas/base64/part_00.txt`
- `assets/generated/city_atlas/base64/part_01.txt`
- `assets/generated/city_atlas/base64/part_02.txt`

`PresentationCatalog` decodes the payload once at startup and slices it into named 80×80 regions.

Current atlas layout:

| Row | Column 0 | Column 1 | Column 2 | Column 3 |
| --- | --- | --- | --- | --- |
| 0 | Safehouse | Underground Clinic | Crew Barracks | Garage |
| 1 | Intel Office | Scrapyard | Data Hub | Raid Target |

Loose PNG paths documented above remain supported as **per-asset overrides**. If an art director later replaces only one building, the loose PNG automatically wins over the embedded atlas slice.

Procedural drawing remains the final fallback if neither the atlas nor an override is available.
