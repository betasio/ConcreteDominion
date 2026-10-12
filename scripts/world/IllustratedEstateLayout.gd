extends RefCounted
## Coordinates are measured in the terrain texture, not in the camera viewport.
## Keep the terrain sprite and interactive sites on the same transform.
const TEXTURE_SIZE := Vector2(1086, 1448)
const ORIGIN := Vector2(118, 590)
const ART_SCALE := 1.0
const PAD_CENTERS := {
	&"Safehouse": Vector2(543, 127),
	&"Hospital": Vector2(218, 814),
	&"Barracks": Vector2(543, 814),
	&"BuildLotA": Vector2(793, 321),
	&"BuildLotB": Vector2(263, 486),
	&"BuildLotC": Vector2(856, 814),
	&"BuildLotD": Vector2(812, 486),
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
	return Rect2(-rendered*Vector2(0.5,0.74),rendered)
