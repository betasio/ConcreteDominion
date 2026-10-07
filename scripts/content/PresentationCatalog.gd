class_name PresentationCatalog
extends Node

const TEXTURE_PATHS := {
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


func apply_to_city(city_map: Node) -> void:
	if city_map == null:
		return

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
	var path := String(TEXTURE_PATHS.get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func get_audio(key: String) -> AudioStream:
	var path := String(AUDIO_PATHS.get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func get_missing_asset_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for key in TEXTURE_PATHS.keys():
		var path := String(TEXTURE_PATHS[key])
		if not ResourceLoader.exists(path):
			lines.append("%s -> %s" % [String(key), path])
	for key in AUDIO_PATHS.keys():
		var path := String(AUDIO_PATHS[key])
		if not ResourceLoader.exists(path):
			lines.append("%s -> %s" % [String(key), path])
	return lines
