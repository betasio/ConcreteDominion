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
	var rendered := texture_size * (half_size.x*2.10 / texture_size.x)
	return Rect2(Vector2(0,6)-rendered*Vector2(0.5,0.78),rendered)

# Courtyard corners measured on the source artwork, clockwise. Upper sites are
# inward-facing parallelograms; neither their hitboxes nor art use a generic diamond.
const PAD_CORNERS := {
	&"Safehouse": [Vector2(492,77),Vector2(673,77),Vector2(680,142),Vector2(484,142)],
	&"RallyHall": [Vector2(361,227),Vector2(469,269),Vector2(417,315),Vector2(296,275)],
	&"BuildLotA": [Vector2(692,265),Vector2(800,225),Vector2(860,270),Vector2(733,315)],
	&"BuildLotB": [Vector2(310,365),Vector2(451,403),Vector2(403,453),Vector2(260,410)],
	&"BuildLotD": [Vector2(711,404),Vector2(855,366),Vector2(904,411),Vector2(755,455)],
	&"Hospital": [Vector2(259,653),Vector2(408,653),Vector2(410,735),Vector2(249,735)],
	&"Barracks": [Vector2(505,653),Vector2(654,653),Vector2(665,735),Vector2(501,735)],
	&"BuildLotC": [Vector2(750,653),Vector2(910,653),Vector2(921,735),Vector2(751,735)],
	&"District00": [Vector2(240,802),Vector2(408,802),Vector2(399,892),Vector2(229,892)],
	&"District01": [Vector2(500,802),Vector2(663,802),Vector2(667,891),Vector2(492,891)],
	&"District02": [Vector2(751,801),Vector2(920,801),Vector2(935,894),Vector2(752,893)],
	&"District10": [Vector2(210,962),Vector2(398,961),Vector2(391,1064),Vector2(196,1064)],
	&"District11": [Vector2(485,962),Vector2(678,962),Vector2(684,1065),Vector2(482,1065)],
	&"District12": [Vector2(766,962),Vector2(951,962),Vector2(971,1064),Vector2(768,1064)],
	&"EstateGate": [Vector2(514,534),Vector2(646,534),Vector2(646,598),Vector2(514,598)],
}
# Width in world units, vertical ground anchor in sprite UV, local offset, mirror.
# Mirroring turns left-bank entrances toward their east-side stairs.
const ART_FITS := {
	&"Safehouse": [245.0, 0.86, Vector2(0,4), false],
	&"RallyHall": [244.0, 0.76, Vector2(-3,4), true],
	&"BuildLotA": [239.0, 0.76, Vector2(0,14), false],
	&"BuildLotB": [242.0, 0.79, Vector2(1,14), true],
	&"BuildLotD": [232.0, 0.79, Vector2(-5,10), false],
	&"Hospital": [204.0, 0.82, Vector2(0,8), false],
	&"Barracks": [208.0, 0.78, Vector2(0,8), false],
	&"BuildLotC": [208.0, 0.78, Vector2(0,8), false],
}

static func pad_outline(site: Node2D, half_size: Vector2) -> PackedVector2Array:
	if PAD_CORNERS.has(site.name):
		var points := PackedVector2Array()
		for corner in PAD_CORNERS[site.name]:
			points.append(artwork_to_world(corner) - site.position)
		return points
	return PackedVector2Array([Vector2(0,-half_size.y),Vector2(half_size.x,0),Vector2(0,half_size.y),Vector2(-half_size.x,0)])

static func draw_building(site: Node2D, texture: Texture2D, half_size: Vector2) -> void:
	if not ART_FITS.has(site.name):
		site.draw_texture_rect(texture,building_rect(texture.get_size(),half_size),false)
		return
	var fit: Array = ART_FITS[site.name]
	var rendered := texture.get_size() * (float(fit[0]) / texture.get_width())
	var rect := Rect2(-rendered * Vector2(0.5,float(fit[1])),rendered)
	site.draw_set_transform(fit[2],0.0,Vector2(-1,1) if fit[3] else Vector2.ONE)
	site.draw_texture_rect(texture,rect,false)
	site.draw_set_transform(Vector2.ZERO)
