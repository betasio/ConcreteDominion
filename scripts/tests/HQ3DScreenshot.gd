extends Node
## Automated reference image from the real imported GLB under Godot lighting.

func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var model_path := "res://assets/buildings/3d/HQ_Mobile.glb"
	if not ResourceLoader.exists(model_path):
		push_error("[HQ 3D] Uploaded mobile model is missing.")
		get_tree().quit(1)
		return
	var packed := load("res://scenes/tests/HQ3DComparison.tscn") as PackedScene
	if packed == null:
		push_error("[HQ 3D] Comparison scene failed to load.")
		get_tree().quit(1)
		return
	var comparison := packed.instantiate()
	add_child(comparison)
	for frame in range(40):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("[HQ 3D] Empty viewport image.")
		get_tree().quit(1)
		return
	var output := "res://build/previews/hq_mobile_3d.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	if image.save_png(output) != OK:
		push_error("[HQ 3D] Failed saving 3D reference screenshot.")
		get_tree().quit(1)
		return
	print("[HQ 3D] Saved: %s" % output)
	get_tree().quit(0)
