class_name PresentationCatalog
extends Node

const ATLAS_BASE64_PARTS := [
	"res://assets/generated/city_atlas/base64/part_00.txt",
	"res://assets/generated/city_atlas/base64/part_01.txt",
	"res://assets/generated/city_atlas/base64/part_02.txt"
]
const ATLAS_SIZE := Vector2i(320, 160)
const ATLAS_CELL := 80
const ATLAS_REGIONS := {
	"safehouse": Rect2(0, 0, 80, 80),
	"hospital": Rect2(80, 0, 80, 80),
	"barracks": Rect2(160, 0, 80, 80),
	"Garage": Rect2(240, 0, 80, 80),
	"Intel Office": Rect2(0, 80, 80, 80),
	"Scrapyard": Rect2(80, 80, 80, 80),
	"Data Hub": Rect2(160, 80, 80, 80),
	"raid_target": Rect2(240, 80, 80, 80)
}

# Optional loose-file overrides remain useful when an artist replaces one
# structure without rebuilding the whole generated atlas.
const TEXTURE_OVERRIDE_PATHS := {
	"safehouse": "res://assets/art/buildings/safehouse.png",
	"hospital": "res://assets/art/buildings/clinic.png",
	"barracks": "res://assets/art/buildings/barracks.png",
	"Garage": "res://assets/art/buildings/garage.png",
	"Intel Office": "res://assets/art/buildings/intel_office.png",
	"Scrapyard": "res://assets/art/buildings/scrapyard.png",
	"Data Hub": "res://assets/art/buildings/data_hub.png",
	"raid_target": "res://assets/art/world/raid_target.png"
}

const AUDIO_PATHS := {
	"ui_click": "res://assets/audio/ui/click.ogg",
	"reward": "res://assets/audio/ui/reward.ogg",
	"raid_victory": "res://assets/audio/combat/raid_victory.ogg",
	"raid_defeat": "res://assets/audio/combat/raid_defeat.ogg"
}

var _city_atlas: ImageTexture
var _atlas_load_attempted := false
var _atlas_error := ""


func _ready() -> void:
	_ensure_city_atlas()


func apply_to_city(city_map: Node) -> void:
	if city_map == null:
		return

	_ensure_city_atlas()

	for building in [city_map.safehouse, city_map.hospital, city_map.barracks]:
		if building != null:
			building.art_texture = get_texture(String(building.building_type))
			building.queue_redraw()

	for lot in [city_map.lot_a, city_map.lot_b, city_map.lot_c, city_map.lot_d]:
		if lot != null:
			lot.art_texture = get_texture(lot.building_name)
			lot.queue_redraw()

	var target_texture := get_texture("raid_target")
	if target_texture != null:
		for target in city_map.get_raid_targets():
			target.art_texture = target_texture
			target.queue_redraw()


func get_texture(key: String) -> Texture2D:
	var override_path := String(TEXTURE_OVERRIDE_PATHS.get(key, ""))
	if override_path != "" and ResourceLoader.exists(override_path):
		return load(override_path) as Texture2D

	_ensure_city_atlas()
	if _city_atlas == null or not ATLAS_REGIONS.has(key):
		return null

	var region := AtlasTexture.new()
	region.atlas = _city_atlas
	region.region = ATLAS_REGIONS[key]
	region.filter_clip = true
	return region


func get_audio(key: String) -> AudioStream:
	var path := String(AUDIO_PATHS.get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func is_city_atlas_ready() -> bool:
	_ensure_city_atlas()
	return _city_atlas != null


func get_city_atlas_size() -> Vector2i:
	_ensure_city_atlas()
	if _city_atlas == null:
		return Vector2i.ZERO
	return Vector2i(_city_atlas.get_width(), _city_atlas.get_height())


func get_atlas_error() -> String:
	_ensure_city_atlas()
	return _atlas_error


func get_missing_asset_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if not is_city_atlas_ready():
		lines.append("City art atlas -> %s" % _atlas_error)

	for key in AUDIO_PATHS.keys():
		var path := String(AUDIO_PATHS[key])
		if not ResourceLoader.exists(path):
			lines.append("%s -> %s (procedural tone fallback active)" % [String(key), path])
	return lines


func _ensure_city_atlas() -> void:
	if _atlas_load_attempted:
		return
	_atlas_load_attempted = true

	var encoded := ""
	for path in ATLAS_BASE64_PARTS:
		if not FileAccess.file_exists(path):
			_atlas_error = "Missing atlas payload part: %s" % path
			push_warning(_atlas_error)
			return
		encoded += FileAccess.get_file_as_string(path).strip_edges()

	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.is_empty():
		_atlas_error = "Atlas base64 payload decoded to zero bytes."
		push_warning(_atlas_error)
		return

	var image := Image.new()
	var error := image.load_webp_from_buffer(bytes)
	if error != OK:
		_atlas_error = "WebP atlas decode failed with error %d." % error
		push_warning(_atlas_error)
		return

	if image.get_size() != ATLAS_SIZE:
		_atlas_error = "Atlas size mismatch: got %s, expected %s." % [image.get_size(), ATLAS_SIZE]
		push_warning(_atlas_error)
		return

	_city_atlas = ImageTexture.create_from_image(image)
	if _city_atlas == null:
		_atlas_error = "Could not create ImageTexture from decoded atlas."
		push_warning(_atlas_error)
		return

	_atlas_error = ""
