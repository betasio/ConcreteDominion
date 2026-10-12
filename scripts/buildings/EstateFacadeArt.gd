extends RefCounted
## Consistent elevated front views; crops exclude neighboring atlas sprites.
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
static var cache: Dictionary = {}
static func texture(kind: String) -> Texture2D:
	var key := kind.to_snake_case()
	if not REGIONS.has(key):
		return null
	if not cache.has(key):
		var sprite := AtlasTexture.new()
		sprite.atlas = load(PATH)
		sprite.region = REGIONS[key]
		sprite.filter_clip = true
		cache[key] = sprite
	return cache[key]
