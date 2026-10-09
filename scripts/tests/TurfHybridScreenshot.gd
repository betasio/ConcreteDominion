extends Node
## Captures the real initialized turf scene for visual QA under an Xvfb display.

func _ready() -> void:
	ProjectSettings.set_setting("concrete_dominion/enable_3d_safehouse", true)
	call_deferred("_capture")


func _capture() -> void:
	var packed := load("res://scenes/core/Main.tscn") as PackedScene
	if packed == null:
		push_error("Unable to load Main for turf capture.")
		get_tree().quit(1)
		return
	var game := packed.instantiate()
	add_child(game)
	var city := game.get_node_or_null("CityMap")
	if city == null:
		push_error("CityMap missing in turf capture.")
		get_tree().quit(1)
		return
	city.set_view_mode(&"base")
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
	var output := "res://build/previews/turf_hybrid_hq.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	var err := image.save_png(output)
	if err != OK:
		push_error("Could not save turf image: %d" % err)
		get_tree().quit(1)
		return
	print("[TURF SCREENSHOT] Saved: %s" % output)
	# A second image without HUD exposes lot/building overlap and city art.
	for child in game.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var city_image: Image = get_viewport().get_texture().get_image()
	var city_output := "res://build/previews/turf_hybrid_map_only.png"
	if city_image == null or city_image.is_empty() or city_image.save_png(city_output) != OK:
		push_error("Could not save unobstructed turf image.")
		get_tree().quit(1)
		return
	print("[TURF SCREENSHOT] Saved: %s" % city_output)
	get_tree().quit(0)
