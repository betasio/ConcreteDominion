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

const CHARACTER_ATLAS_PATH := "res://assets/generated/characters/character_atlas.webp"
const CHARACTER_ATLAS_SIZE := Vector2i(128, 64)
const CHARACTER_CELL := 32
const CHARACTER_REGIONS := {
	"vex": Rect2(0, 0, 32, 32),
	"mia": Rect2(32, 0, 32, 32),
	"noah": Rect2(64, 0, 32, 32),
	"kira": Rect2(96, 0, 32, 32),
	"enforcer": Rect2(0, 32, 32, 32),
	"driver": Rect2(32, 32, 32, 32),
	"spy": Rect2(64, 32, 32, 32)
}

const CAMPAIGN_ATLAS_PATH := "res://assets/generated/campaign/chapter_campaign_atlas.webp"
const CAMPAIGN_ATLAS_SIZE := Vector2i(256, 64)
const CAMPAIGN_REGIONS := {
	"darius": Rect2(0, 0, 64, 64),
	"northside": Rect2(64, 0, 64, 64),
	"celeste": Rect2(128, 0, 64, 64),
	"casino": Rect2(192, 0, 64, 64)
}

const DECOR_ATLAS_PATH := "res://assets/generated/presentation/presentation_atlas.webp"
const DECOR_ATLAS_SIZE := Vector2i(256, 160)
const DECOR_REGIONS := {
	"ui_panel": Rect2(0, 0, 128, 85),
	"road_intersection": Rect2(145, 0, 100, 66),
	"road_straight": Rect2(145, 68, 100, 61),
	"ui_bar": Rect2(0, 90, 140, 32),
	"ui_button_dark": Rect2(0, 126, 48, 20),
	"ui_button_gold": Rect2(52, 126, 50, 20)
}

const AUDIO_PATHS := {
	"ui_click": "res://assets/audio/ui/click.ogg",
	"reward": "res://assets/audio/ui/reward.ogg",
	"raid_victory": "res://assets/audio/combat/raid_victory.ogg",
	"raid_defeat": "res://assets/audio/combat/raid_defeat.ogg"
}

var _city_atlas: ImageTexture
var _character_atlas: Texture2D
var _campaign_atlas: Texture2D
var _decor_atlas: Texture2D
var _atlas_load_attempted := false
var _atlas_error := ""


func _ready() -> void:
	_ensure_city_atlas()
	_ensure_character_atlas()
	_ensure_campaign_atlas()


func apply_to_city(city_map: Node) -> void:
	if city_map == null:
		return

	_ensure_city_atlas()
	_ensure_decor_atlas()

	if city_map.has_method("setup_presentation"):
		city_map.setup_presentation(self)

	for building in [city_map.safehouse, city_map.hospital, city_map.barracks]:
		if building != null:
			var premium_path: String = "res://assets/premium/buildings/%s.png" % String(building.building_type)
			building.art_texture = load(premium_path) as Texture2D if ResourceLoader.exists(premium_path, "Texture2D") else get_texture(String(building.building_type))
			building.queue_redraw()

	for lot in [city_map.lot_a, city_map.lot_b, city_map.lot_c, city_map.lot_d]:
		if lot != null:
			var premium_path: String = "res://assets/premium/buildings/%s.png" % String(lot.building_name).to_snake_case()
			lot.art_texture = load(premium_path) as Texture2D if ResourceLoader.exists(premium_path, "Texture2D") else get_texture(lot.building_name)
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


func get_decor_texture(key: String) -> Texture2D:
	_ensure_decor_atlas()
	if _decor_atlas == null or not DECOR_REGIONS.has(key):
		return null

	var region := AtlasTexture.new()
	region.atlas = _decor_atlas
	region.region = DECOR_REGIONS[key]
	region.filter_clip = true
	return region


func get_character_portrait(key: String) -> Texture2D:
	_ensure_character_atlas()
	var normalized := key.to_lower()
	if _character_atlas == null or not CHARACTER_REGIONS.has(normalized):
		return null

	var region := AtlasTexture.new()
	region.atlas = _character_atlas
	region.region = CHARACTER_REGIONS[normalized]
	region.filter_clip = true
	return region


func get_unit_portrait(role: StringName) -> Texture2D:
	return get_character_portrait(String(role).to_lower())


func get_campaign_art(key: String) -> Texture2D:
	_ensure_campaign_atlas()
	var normalized := key.to_lower()
	if _campaign_atlas == null or not CAMPAIGN_REGIONS.has(normalized):
		return null
	var region := AtlasTexture.new()
	region.atlas = _campaign_atlas
	region.region = CAMPAIGN_REGIONS[normalized]
	region.filter_clip = true
	return region


func is_campaign_atlas_ready() -> bool:
	_ensure_campaign_atlas()
	return _campaign_atlas != null


func get_campaign_atlas_size() -> Vector2i:
	_ensure_campaign_atlas()
	if _campaign_atlas == null:
		return Vector2i.ZERO
	return Vector2i(_campaign_atlas.get_width(), _campaign_atlas.get_height())


func is_character_atlas_ready() -> bool:
	_ensure_character_atlas()
	return _character_atlas != null


func get_character_atlas_size() -> Vector2i:
	_ensure_character_atlas()
	if _character_atlas == null:
		return Vector2i.ZERO
	return Vector2i(_character_atlas.get_width(), _character_atlas.get_height())


func is_decor_atlas_ready() -> bool:
	_ensure_decor_atlas()
	return _decor_atlas != null


func get_decor_atlas_size() -> Vector2i:
	_ensure_decor_atlas()
	if _decor_atlas == null:
		return Vector2i.ZERO
	return Vector2i(_decor_atlas.get_width(), _decor_atlas.get_height())


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
	if not is_decor_atlas_ready():
		lines.append("Presentation atlas -> %s" % DECOR_ATLAS_PATH)
	if not is_character_atlas_ready():
		lines.append("Character atlas -> %s" % CHARACTER_ATLAS_PATH)
	if not is_campaign_atlas_ready():
		lines.append("Campaign atlas -> %s" % CAMPAIGN_ATLAS_PATH)

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



func _ensure_decor_atlas() -> void:
	if _decor_atlas != null:
		return
	if not ResourceLoader.exists(DECOR_ATLAS_PATH):
		return
	_decor_atlas = load(DECOR_ATLAS_PATH) as Texture2D



func _ensure_character_atlas() -> void:
	if _character_atlas != null:
		return
	if not ResourceLoader.exists(CHARACTER_ATLAS_PATH):
		return
	_character_atlas = load(CHARACTER_ATLAS_PATH) as Texture2D
	if _character_atlas != null and Vector2i(_character_atlas.get_width(), _character_atlas.get_height()) != CHARACTER_ATLAS_SIZE:
		push_warning("Character atlas size mismatch: got %s, expected %s." % [
			Vector2i(_character_atlas.get_width(), _character_atlas.get_height()),
			CHARACTER_ATLAS_SIZE
		])
		_character_atlas = null



func _ensure_campaign_atlas() -> void:
	if _campaign_atlas != null:
		return
	if not ResourceLoader.exists(CAMPAIGN_ATLAS_PATH):
		return
	_campaign_atlas = load(CAMPAIGN_ATLAS_PATH) as Texture2D
	if _campaign_atlas != null and Vector2i(_campaign_atlas.get_width(), _campaign_atlas.get_height()) != CAMPAIGN_ATLAS_SIZE:
		push_warning("Campaign atlas size mismatch: got %s, expected %s." % [
			Vector2i(_campaign_atlas.get_width(), _campaign_atlas.get_height()),
			CAMPAIGN_ATLAS_SIZE
		])
		_campaign_atlas = null
