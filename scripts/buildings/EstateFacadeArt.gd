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
const PLOT_PATH := "res://assets/premium/buildings/estate_plot_aligned_atlas.png"
const PLOT_REGIONS := {
	"rally": Rect2(91,8,630,486),
	"garage": Rect2(875,65,574,442),
	"intel_office": Rect2(105,424,585,555),
	"data_hub": Rect2(889,527,545,453),
}
static var cache: Dictionary = {}
static func texture(kind: String, inward: bool = true) -> Texture2D:
	var key := kind.to_snake_case()
	if not REGIONS.has(key) and not (inward and INWARD_REGIONS.has(key)):
		return null
	var cache_key := key + ("_inward" if inward else "_front")
	if not cache.has(cache_key):
		var sprite := AtlasTexture.new()
		if inward and PLOT_REGIONS.has(key):
			sprite.atlas = load(PLOT_PATH)
			sprite.region = PLOT_REGIONS[key]
		elif inward and INWARD_REGIONS.has(key):
			sprite.atlas = load(INWARD_PATH)
			sprite.region = INWARD_REGIONS[key]
		else:
			sprite.atlas = load(PATH)
			sprite.region = REGIONS[key]
		sprite.filter_clip = true
		cache[cache_key] = sprite
	return cache[cache_key]


static func draw_fitted(item: CanvasItem, texture: Texture2D, rect: Rect2) -> void:
	# The antenna and banner cross rectangular atlas cell boundaries. Polygon
	# crops keep each silhouette separate without importing another texture.
	var crop := PackedVector2Array()
	if texture is AtlasTexture and texture.atlas.resource_path == PLOT_PATH:
		if texture.region == PLOT_REGIONS["rally"]:
			crop = PackedVector2Array([Vector2(91,8),Vector2(721,8),Vector2(721,494),Vector2(520,494),Vector2(91,258)])
		elif texture.region == PLOT_REGIONS["intel_office"]:
			crop = PackedVector2Array([Vector2(105,424),Vector2(310,424),Vector2(310,510),Vector2(545,510),Vector2(545,600),Vector2(690,650),Vector2(690,979),Vector2(105,979)])
	if crop.is_empty():
		item.draw_texture_rect(texture,rect,false)
		return
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for pixel in crop:
		points.append(rect.position + (pixel-texture.region.position) / texture.region.size * rect.size)
		uvs.append(pixel / texture.atlas.get_size())
	item.draw_polygon(points,PackedColorArray([Color.WHITE]),uvs,texture.atlas)
