extends RefCounted
## Original generated modular art. Atlas regions preserve transparent foundations.
const SHEET := preload("res://assets/world/city/city_buildings.png")
const GROUND := preload("res://assets/world/city/city_ground.png")
const REGIONS := [Rect2(0,0,534,490), Rect2(534,0,504,490), Rect2(1038,0,498,490), Rect2(0,490,534,510), Rect2(534,490,502,510), Rect2(1036,490,500,510)]
static var textures: Dictionary = {}

static func texture(index: int) -> Texture2D:
	if not textures.has(index):
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = REGIONS[index]
		atlas.filter_clip = true
		textures[index] = atlas
	return textures[index]
