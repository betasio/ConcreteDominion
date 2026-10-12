extends RefCounted
## Coordinates are measured in the terrain texture, not in the camera viewport.
## Keep the terrain sprite and interactive sites on the same transform.
const TEXTURE_SIZE := Vector2(941, 1672)
const ORIGIN := Vector2(72, 447)
const ART_SCALE := 0.73
const ANNEX_PATH := "res://assets/environment/data_hub_terrace.png"
# Ground-contact center of the gold diamond in the transparent annex sprite.
const ANNEX_PAD_PIXEL := Vector2(754, 586)
const ANNEX_SCALE := 0.24
const PAD_CENTERS := {
	&"Safehouse": Vector2(721, 375),
	&"Hospital": Vector2(414, 545),
	&"Barracks": Vector2(215, 711),
	&"BuildLotA": Vector2(284, 963),
	&"BuildLotB": Vector2(773, 800),
	&"BuildLotC": Vector2(675, 1130),
	&"BuildLotD": Vector2(955, 1020),
}


static func artwork_to_world(point: Vector2) -> Vector2:
	return ORIGIN + (point - TEXTURE_SIZE * 0.5) * ART_SCALE

# Half-extents of the usable courtyard, leaving its walls and stairs exposed.
const PAD_HALF_SIZES := {
	&"Safehouse": Vector2(94,46), &"Hospital": Vector2(76,38),
	&"Barracks": Vector2(98,48), &"BuildLotA": Vector2(92,46),
	&"BuildLotB": Vector2(76,38), &"BuildLotC": Vector2(86,43),
	&"BuildLotD": Vector2(64,34),
}

static func building_rect(texture_size: Vector2, half_size: Vector2) -> Rect2:
	# Ground center, not the roof or the texture's bottom edge, anchors the art.
	var rendered := texture_size * (half_size.x*1.88 / texture_size.x)
	return Rect2(-rendered*Vector2(0.5,0.74),rendered)
