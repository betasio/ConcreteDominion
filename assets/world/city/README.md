# Original city artwork

Generated for ConcreteDominion with the image-generation tool on 2026-10-13.
User-supplied strategy-game references informed the isometric composition and
ownership-color convention; these are newly generated buildings, not crops from
the reference screenshots. Labels, colors and contest status are runtime UI.

- `city_buildings.png`: transparent 1536×1024 atlas. Top row: terracotta-roof
  mansion, dark-roof mansion, City Hall. Bottom row: Underground Exchange,
  Port Authority, neutral residential block. A background-removal generation
  produced the final cutouts. `CityArt.gd` defines the six regions; textures are
  cached and share one source image. No per-building image-generation requests.
- `city_ground.png`: generated seamless overhead olive grass/soil texture.
  Isometric ground polygons apply it under the roads and separate buildings.
- Both imports generate mipmaps to prevent shimmer at map scale. Geometry,
  road markings, traffic, ownership plates and input targets remain separate
  from the artwork. Estate/home assets are not replaced.

## Expanded collection (2026-10-13)

- `turf_collection.png`: original transparent 1536×1024 sheet, generated in one
  batch. Villa, mansion and palace above; Crimson Citadel, Emerald Exchange and
  landscaped park below. Runtime atlas regions follow the individual foundations.
- `civic_landmarks.png`: original transparent 1881×836 sheet. Underground Exchange,
  monumental City Hall and Port Authority. These use 570-world-unit footprints;
  player turfs use 260. Screen-space reservations prevent the taller architecture
  from obscuring nearby player buildings. No reference-game artwork is embedded.
- Mipmapped atlas textures are shared and cached. The existing ground and neutral
  neighborhood atlas are reused. Asphalt, verges, lane markings and moving traffic
  remain runtime layers. Home-estate artwork and placements are unchanged.
