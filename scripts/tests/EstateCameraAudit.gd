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
	# Zoom limits now fit the viewport, instead of assuming landscape forever.
	if not camera.use_camera_limits or camera.min_zoom <= 0.0 or camera.max_zoom <= camera.min_zoom:
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
	for size in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(1080, 2340)]:
		get_window().size = size
		await get_tree().process_frame
		map.set_view_mode(&"base")
		camera.edge_pan_enabled = false
		camera.reset_smoothing()
		camera.force_update_scroll()
		await get_tree().process_frame
		var viewport_rect := get_viewport().get_visible_rect()
		for site in map.get_persistent_buildings():
			var screen_point: Vector2 = site.get_global_transform_with_canvas().origin
			if not viewport_rect.grow(-20.0).has_point(screen_point):
				push_error("[CAMERA AUDIT] Site clipped at %s: %s" % [size, site.name])
				get_tree().quit(1)
				return
		# Exercise the actual two-finger input handler at each aspect ratio.
		var old_zoom: float = camera.zoom.x
		for index in range(2):
			var touch := InputEventScreenTouch.new()
			touch.index = index
			touch.pressed = true
			touch.position = Vector2(100 + index * 100, 100)
			camera.call("_unhandled_input", touch)
		var drag := InputEventScreenDrag.new()
		drag.index = 1
		drag.position = Vector2(400, 100)
		camera.call("_unhandled_input", drag)
		if camera.zoom.x <= old_zoom or camera.zoom.x > camera.max_zoom + 0.001:
			push_error("[CAMERA AUDIT] Portrait/landscape pinch zoom failed")
			get_tree().quit(1)
			return
		for index in range(2):
			var release := InputEventScreenTouch.new()
			release.index = index
			camera.call("_unhandled_input", release)
	# Backplate stays in the same world as the terrain during camera movement.
	var backdrop = map.get_node("GoldenBayBackdrop")
	var coast_transform: Transform2D = backdrop.panorama.transform
	var original_position: Vector2 = camera.position
	camera.position += Vector2(60,40)
	await get_tree().process_frame
	if backdrop.panorama.transform != coast_transform:
		push_error("[CAMERA AUDIT] Coastline slides independently of terrain")
		get_tree().quit(1)
		return
	camera.position = original_position
	# Cursor zoom preserves the world point under the cursor away from limits.
	camera.position = Vector2(118,350)
	var pivot := get_viewport().get_visible_rect().size*0.5+Vector2(60,40)
	var offset := pivot-get_viewport().get_visible_rect().size*0.5
	camera.call("_set_camera_zoom",camera.min_zoom*1.2)
	var anchor: Vector2 = camera.position+offset/camera.zoom.x
	camera.call("_zoom_at_screen_point",camera.min_zoom*1.5,pivot)
	if (camera.position+offset/camera.zoom.x).distance_to(anchor) > 0.01:
		push_error("[CAMERA AUDIT] Cursor zoom drifts")
		get_tree().quit(1)
		return
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = pivot
	camera.call("_unhandled_input",touch)
	touch.pressed = false
	camera.call("_input",touch)
	if not camera._active_touches.is_empty():
		push_error("[CAMERA AUDIT] Gesture release over UI was lost")
		get_tree().quit(1)
		return
	camera.set_controls_blocked(true)
	var blocked_zoom: Vector2 = camera.zoom
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	camera.call("_unhandled_input",wheel)
	if camera.zoom != blocked_zoom:
		push_error("[CAMERA AUDIT] Blocked camera still zooms")
		get_tree().quit(1)
		return
	camera.set_controls_blocked(false)
	map.set_view_mode(&"world")
	if camera.use_camera_limits or camera.min_zoom > 0.5:
		push_error("[CAMERA AUDIT] World mode did not restore camera freedom")
		get_tree().quit(1)
		return
	print("[CAMERA AUDIT] PASS - three aspect ratios, all seven sites framed, pinch zoom, estate bounds and world view reset")
	get_tree().quit(0)
