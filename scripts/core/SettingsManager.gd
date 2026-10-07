class_name SettingsManager
extends Node

signal changed

const SETTINGS_PATH := "user://settings.cfg"

var master_volume: float = 0.85
var haptics_enabled: bool = true
var haptics_strength: float = 0.65
var reduced_motion: bool = false
var large_text: bool = false
var edge_pan_enabled: bool = true


func _ready() -> void:
	load_settings()
	apply_runtime_settings()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_runtime_settings()
	save_settings()
	changed.emit()


func set_haptics_enabled(value: bool) -> void:
	haptics_enabled = value
	save_settings()
	changed.emit()


func set_haptics_strength(value: float) -> void:
	haptics_strength = clampf(value, 0.0, 1.0)
	save_settings()
	changed.emit()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	save_settings()
	changed.emit()


func set_large_text(value: bool) -> void:
	large_text = value
	save_settings()
	changed.emit()


func set_edge_pan_enabled(value: bool) -> void:
	edge_pan_enabled = value
	save_settings()
	changed.emit()


func apply_runtime_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(
			bus,
			-80.0 if master_volume <= 0.001 else linear_to_db(master_volume)
		)


func pulse_haptic(duration_ms: int = 35, strength_scale: float = 1.0) -> void:
	if not haptics_enabled or haptics_strength <= 0.0:
		return
	if not DisplayServer.is_touchscreen_available():
		return

	Input.vibrate_handheld(
		maxi(1, duration_ms),
		clampf(haptics_strength * strength_scale, 0.0, 1.0)
	)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("feedback", "haptics_enabled", haptics_enabled)
	config.set_value("feedback", "haptics_strength", haptics_strength)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "large_text", large_text)
	config.set_value("controls", "edge_pan_enabled", edge_pan_enabled)
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	haptics_enabled = bool(config.get_value("feedback", "haptics_enabled", haptics_enabled))
	haptics_strength = clampf(float(config.get_value("feedback", "haptics_strength", haptics_strength)), 0.0, 1.0)
	reduced_motion = bool(config.get_value("accessibility", "reduced_motion", reduced_motion))
	large_text = bool(config.get_value("accessibility", "large_text", large_text))
	edge_pan_enabled = bool(config.get_value("controls", "edge_pan_enabled", edge_pan_enabled))
