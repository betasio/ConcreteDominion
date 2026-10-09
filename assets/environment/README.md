# ConcreteDominion illustrated environment art

The dedicated art layer is implemented by `scripts/world/TurfEnvironmentArt.gd`
and added to `scenes/world/CityMap.tscn` above the procedural turf and
below the interactive buildings.

Install the twenty-five transparent PNGs from
`ConcreteDominion_Environment_Art_Ready_To_Install.zip` into this directory:
`assets/environment/`. The PNG filenames are loaded automatically and are
deliberately optional, so older builds still display the procedural compound.

These are original illustrated concept-derived assets. After the PNGs are
installed, run the Godot QA workflow and inspect turf screenshot framing:
the art positioning is a first-pass layout and should be refined against
the real capture before treating the environment as finished.

The environment layer never changes building state or handles input.
