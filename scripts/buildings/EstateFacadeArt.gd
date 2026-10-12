extends RefCounted
## Front views for the outer district; inward-facing views for the command estate.
const PATH := "res://assets/premium/buildings/estate_front_atlas.png"
const REGIONS := {
	"garage":Rect2(10,102,422,303),
	"hospital":Rect2(436,48,388,359),
	"barracks":Rect2(826,106,421,278),
	"intel_office":Rect2(16,432,418,365),
	"data_hub":Rect2(437,433,383,365),
	"scrapyard":Rect2(827,524,416,279),
	"rally":Rect2(8,820,428,377),
	"gate":Rect2(440,884,380,305),
	"yacht":Rect2(822,942,424,175)
}
const INWARD_PATH := "res://assets/premium/buildings/estate_inward_atlas.png"
const INWARD_REGIONS := {
	"safehouse": Rect2(8,35,561,429),
	"rally": Rect2(574,68,460,435),
	"garage": Rect2(1040,117,489,410),
	"intel_office": Rect2(22,510,499,456),
	"data_hub": Rect2(546,550,503,437),
}
static var cache: Dictionary = {}
static func texture(kind: String, inward: bool = true) -> Texture2D:
	var key := kind.to_snake_case()
	if not REGIONS.has(key) and not (inward and INWARD_REGIONS.has(key)):
		return null
	var cache_key := key + ("_inward" if inward else "_front")
	if not cache.has(cache_key):
		var sprite := AtlasTexture.new()
		sprite.atlas = load(INWARD_PATH if inward and INWARD_REGIONS.has(key) else PATH)
		sprite.region = INWARD_REGIONS[key] if inward and INWARD_REGIONS.has(key) else REGIONS[key]
		sprite.filter_clip = true
		cache[cache_key] = sprite
	return cache[cache_key]
