class_name SafeAreaManager
extends Node

var roots: Array[Control] = []


func setup(ui_roots: Array[Control]) -> void:
	roots = ui_roots
	get_tree().root.size_changed.connect(_apply_safe_area)
	call_deferred("_apply_safe_area")


func _apply_safe_area() -> void:
	var inset := _get_viewport_safe_insets()

	for root in roots:
		if root == null or not is_instance_valid(root):
			continue
		root.offset_left = inset.x
		root.offset_top = inset.y
		root.offset_right = -inset.z
		root.offset_bottom = -inset.w


func _get_viewport_safe_insets() -> Vector4:
	if not DisplayServer.is_touchscreen_available():
		return Vector4.ZERO

	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var viewport_size := get_viewport().get_visible_rect().size

	if safe.size.x <= 0 or safe.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return Vector4.ZERO

	var scale_x := viewport_size.x / float(window_size.x)
	var scale_y := viewport_size.y / float(window_size.y)

	var left := maxf(0.0, float(safe.position.x) * scale_x)
	var top := maxf(0.0, float(safe.position.y) * scale_y)
	var right_px := window_size.x - safe.end.x
	var bottom_px := window_size.y - safe.end.y
	var right := maxf(0.0, float(right_px) * scale_x)
	var bottom := maxf(0.0, float(bottom_px) * scale_y)

	return Vector4(left, top, right, bottom)
