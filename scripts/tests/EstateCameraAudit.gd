extends Node
## Assert zoom and pan constraints for illustrated base and world modes.
func _ready() -> void:
	call_deferred("_audit")

func _audit() -> void:
	ProjectSettings.set_setting("concrete_dominion/preview_illustrated_terrain", true)
	var packed := load("res://scenes/world/CityMap.tscn") as PackedScene
	if packed == null:
		push_error("[CAMERA AUDIT] Missing CityMap scene")
		get_tree().quit(1)
		return
	var map := packed.instantiate()
	add_child(map)
	var camera: Camera2D = map.get_node("StrategyCamera")
	if not camera.use_camera_limits or absf(camera.min_zoom - 0.73) > 0.01:
		push_error("[CAMERA AUDIT] Illustrated base limits were not applied")
		get_tree().quit(1)
		return
	camera.call("_set_camera_zoom", 0.1)
	if absf(camera.zoom.x - camera.min_zoom) > 0.001:
		push_error("[CAMERA AUDIT] Minimum zoom not enforced")
		get_tree().quit(1)
		return
	camera.call("_set_camera_zoom", 5.0)
	if absf(camera.zoom.x - camera.max_zoom) > 0.001:
		push_error("[CAMERA AUDIT] Maximum zoom not enforced")
		get_tree().quit(1)
		return
	camera.position = Vector2(-9999, 9999)
	camera.call("_clamp_camera_to_world")
	if camera.position.x < camera.camera_bounds.position.x or camera.position.y > camera.camera_bounds.end.y:
		push_error("[CAMERA AUDIT] Camera center escaped estate bounds")
		get_tree().quit(1)
		return
	map.set_view_mode(&"world")
	if camera.use_camera_limits or camera.min_zoom > 0.5:
		push_error("[CAMERA AUDIT] World mode did not restore camera freedom")
		get_tree().quit(1)
		return
	print("[CAMERA AUDIT] PASS - estate bounds, zoom clamping, and world view reset")
	get_tree().quit(0)
