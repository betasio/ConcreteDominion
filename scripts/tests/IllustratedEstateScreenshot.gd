extends Node
## Captures the real initialized turf scene for visual QA under an Xvfb display.

func _ready() -> void:
	ProjectSettings.set_setting("concrete_dominion/enable_3d_safehouse", true)
	ProjectSettings.set_setting("concrete_dominion/preview_illustrated_terrain", true)
	call_deferred("_capture")


func _capture() -> void:
	var packed := load("res://scenes/core/Main.tscn") as PackedScene
	if packed == null:
		push_error("Unable to load Main for turf capture.")
		get_tree().quit(1)
		return
	var game := packed.instantiate()
	add_child(game)
	# Captures must not overwrite a developer's save or depend on their camera
	# pointer position. Run with a fresh XDG_DATA_HOME for a clean account.
	game.get_node("SaveManager").set_process(false)
	var city := game.get_node_or_null("CityMap")
	if city == null:
		push_error("CityMap missing in turf capture.")
		get_tree().quit(1)
		return
	city.set_view_mode(&"base")
	city.camera.edge_pan_enabled = false
	city.camera.reset_smoothing()
	# First capture shows the playable interface without the first-run modal.
	var tutorial_ui := game.get_node_or_null("TutorialUI") as CanvasLayer
	if tutorial_ui != null:
		tutorial_ui.visible = false
	# Allow presentation initialization, resource upload and camera smoothing.
	for i in range(24):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Turf capture image was empty.")
		get_tree().quit(1)
		return
	var output := "res://build/previews/turf_illustrated_hq.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	var err := image.save_png(output)
	if err != OK:
		push_error("Could not save turf image: %d" % err)
		get_tree().quit(1)
		return
	print("[TURF SCREENSHOT] Saved: %s" % output)
	# A second image without HUD exposes lot/building overlap and city art.
	var visible_layers: Array[CanvasLayer] = []
	for child in game.get_children():
		if child is CanvasLayer:
			if child.visible:
				visible_layers.append(child)
			(child as CanvasLayer).visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var city_image: Image = get_viewport().get_texture().get_image()
	var city_output := "res://build/previews/turf_illustrated_map_only.png"
	if city_image == null or city_image.is_empty() or city_image.save_png(city_output) != OK:
		push_error("Could not save unobstructed turf image.")
		get_tree().quit(1)
		return
	print("[TURF SCREENSHOT] Saved: %s" % city_output)
	# Exercise all visual states, not just the empty sites. Construction and
	# upgrades must not bring back opaque foundation slabs over the artwork.
	var lots: Array = [city.lot_a, city.lot_b, city.lot_c, city.lot_d]
	for lot in lots:
		lot.begin_construction(1)
	city.lot_a.set_selected(true)
	await _save_frame("turf_illustrated_constructing")
	for lot in lots:
		lot.complete_construction(1)
	city.lot_d.begin_construction(2)
	await _save_frame("turf_illustrated_built")
	get_window().size = Vector2i(720,1280)
	await get_tree().process_frame
	city.set_view_mode(&"base")
	city.camera.reset_smoothing()
	await _save_frame("turf_illustrated_portrait_built")
	for layer in visible_layers:
		layer.visible = true
	await _save_frame("turf_illustrated_portrait_built_hud")
	for layer in visible_layers:
		layer.visible = false
	for lot in lots:
		lot.restore_progress(false)
		lot.set_selected(false)
	# Use the project's real stretch mode when switching to a phone aspect.
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame
	city.set_view_mode(&"base")
	city.camera.reset_smoothing()
	await _save_frame("turf_illustrated_portrait")
	for layer in visible_layers:
		layer.visible = true
	await _save_frame("turf_illustrated_portrait_hud")
	var estate_hud = game.get_node("EstateHUD")
	estate_hud.navigation[1].pressed.emit()
	await _save_frame("turf_illustrated_portrait_tasks")
	estate_hud._close_panels()
	estate_hud.left_actions[1].pressed.emit()
	await _save_frame("turf_illustrated_portrait_training")
	estate_hud._close_panels()
	estate_hud.right_actions[2].pressed.emit()
	await _save_frame("turf_illustrated_portrait_more")
	estate_hud._close_panels()
	game.tutorial_ui.visible = false
	get_window().size = Vector2i(640,360)
	await get_tree().process_frame
	city.set_view_mode(&"base")
	city.camera.reset_smoothing()
	await _save_frame("turf_illustrated_landscape_phone")
	get_window().size = Vector2i(720,1280)
	await get_tree().process_frame
	city.set_view_mode(&"base")
	city.camera.reset_smoothing()
	game.tutorial_ui.visible = true
	await _save_frame("turf_illustrated_portrait_tutorial")
	game.tutorial_ui.visible = false
	game.construction_queue.set_process(false)
	if not game.construction_queue.start_upgrade(city.safehouse):
		push_error("Could not start construction HUD capture")
		get_tree().quit(1)
		return
	await _save_frame("turf_illustrated_portrait_construction_hud")
	for layer in visible_layers:
		layer.visible = false
	city.camera.call("_set_camera_zoom", city.camera.max_zoom)
	city.camera.position = city.lot_d.position
	city.camera.reset_smoothing()
	await _save_frame("turf_illustrated_portrait_close")
	# State changes can trigger reward tones; stop their generator playback
	# before tearing down the screenshot scene, even with the Dummy driver.
	for player in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
	await get_tree().process_frame
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _save_frame(file_name: String) -> void:
	for frame in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture := get_viewport().get_texture().get_image()
	var path := "res://build/previews/%s.png" % file_name
	if capture == null or capture.is_empty() or capture.save_png(path) != OK:
		push_error("[TURF SCREENSHOT] Failed: %s" % path)
		get_tree().quit(1)
		return
	print("[TURF SCREENSHOT] Saved: %s" % path)
