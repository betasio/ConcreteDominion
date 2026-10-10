extends Node
## Captures the real animated coastal background with Godot for visual QA.
func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene := load("res://scenes/backgrounds/CoastalEstatePreview.tscn") as PackedScene
	if scene == null:
		push_error("Coastal backdrop preview scene missing")
		get_tree().quit(1)
		return
	var instance := scene.instantiate()
	add_child(instance)
	for i in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image()
	if result == null or result.is_empty():
		push_error("Empty coastal backdrop screenshot")
		get_tree().quit(1)
		return
	var output := "res://build/previews/coastal_estate_animated.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	if result.save_png(output) != OK:
		push_error("Failed to save coastal preview")
		get_tree().quit(1)
		return
	print("[COASTAL BACKDROP] Saved: " + output)
	# Second capture lets us inspect live shader motion rather than one static frame.
	for i in range(90):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var later := get_viewport().get_texture().get_image()
	var later_output := "res://build/previews/coastal_estate_animated_later.png"
	if later == null or later.is_empty() or later.save_png(later_output) != OK:
		push_error("Failed to capture later animated coastal frame")
		get_tree().quit(1)
		return
	print("[COASTAL BACKDROP] Saved later frame: " + later_output)
	get_tree().quit(0)
