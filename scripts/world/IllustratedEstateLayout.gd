extends RefCounted
## Coordinates are measured in the terrain texture, not in the camera viewport.
## Keep the terrain sprite and interactive sites on the same transform.
const TEXTURE_SIZE := Vector2(1161, 1354)
const ORIGIN := Vector2(118, 651)
const ART_SCALE := 1.16
# Continue the road beyond the estate; the full camera frame stops before its end.
const SOUTH_APPROACH_HEIGHT := 360.0
const SOUTH_OVERLAP := 55.0
const TERRAIN_BOTTOM := ORIGIN.y + TEXTURE_SIZE.y * 0.5 * ART_SCALE
const ROAD_END := TERRAIN_BOTTOM + SOUTH_APPROACH_HEIGHT - SOUTH_OVERLAP
const PAD_CENTERS := {
	&"Safehouse": Vector2(580, 108),
	&"Hospital": Vector2(324, 696),
	&"Barracks": Vector2(580, 696),
	&"BuildLotA": Vector2(784, 256),
	&"BuildLotB": Vector2(346, 406),
	&"BuildLotC": Vector2(831, 697),
	&"BuildLotD": Vector2(815, 418),
}


static func artwork_to_world(point: Vector2) -> Vector2:
	return ORIGIN + (point - TEXTURE_SIZE * 0.5) * ART_SCALE

# Half-extents of the usable courtyard, leaving its walls and stairs exposed.
const PAD_HALF_SIZES := {
	&"Safehouse": Vector2(145,50), &"Hospital": Vector2(100,43),
	&"Barracks": Vector2(100,43), &"BuildLotA": Vector2(85,43),
	&"BuildLotB": Vector2(100,43), &"BuildLotC": Vector2(100,43),
	&"BuildLotD": Vector2(85,43),
}

static func building_rect(texture_size: Vector2, half_size: Vector2) -> Rect2:
	# Ground center, not the roof or the texture's bottom edge, anchors the art.
	var rendered := texture_size * (half_size.x*1.88 / texture_size.x)
	return Rect2(-rendered*Vector2(0.5,0.85),rendered)
