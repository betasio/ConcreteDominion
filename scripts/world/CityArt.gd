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

const TURFS := preload("res://assets/world/city/turf_collection.png")
const CIVIC := preload("res://assets/world/city/civic_landmarks.png")
const TURF_REGIONS := [Rect2(0,0,510,488),Rect2(510,0,518,490),Rect2(1028,0,508,496),Rect2(0,488,565,512),Rect2(565,490,511,510),Rect2(1076,500,460,485)]

static func turf(index: int) -> Texture2D:
	return _region("turf%d" % index, TURFS, TURF_REGIONS[clampi(index,0,5)])

static func landmark(id: String) -> Texture2D:
	var index := {"exchange":0,"city_hall":1,"port":2}.get(id,0) as int
	return _region(id, CIVIC, Rect2(index*627,0,627,800))

static func _region(key: String, sheet: Texture2D, region: Rect2) -> Texture2D:
	if not textures.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = region
		atlas.filter_clip = true
		textures[key] = atlas
	return textures[key]

static func tier(level: int) -> int:
	return 2 if level >= 5 else (1 if level >= 3 else 0)
