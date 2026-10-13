class_name TurfOverlay
extends Node2D

signal preview_requested(target_id: String)

var _tap_position := Vector2.INF
var map_font: FontFile
var control: WorldControlManager
var city_map: Node
var preview_id := ""


func _ready() -> void:
	map_font = ThemeDB.fallback_font.duplicate() as FontFile
	map_font.multichannel_signed_distance_field = true


func setup(manager: WorldControlManager, world: Node) -> void:
	control = manager
	city_map = world
	control.changed.connect(queue_redraw)
	world.view_mode_changed.connect(func(_mode): queue_redraw())
	queue_redraw()


func _draw() -> void:
	if control == null or city_map == null or city_map.get_view_mode() != &"world":
		return

	for target_value in city_map.get_raid_targets():
		var target: RaidTarget = target_value as RaidTarget
		if target == null:
			continue
		var target_id: String = target.get_target_id()

		var center: Vector2 = target.position + Vector2(0, -25)
		var color := Color(0.72, 0.24, 0.24, 0.78)
		if control.is_owned(target_id):
			color = Color(0.20, 0.72, 0.42, 0.82)
		if control.is_contested(target_id):
			color = Color(0.95, 0.62, 0.18, 0.9)

		var discovered := control.is_discovered(target_id)
		if not discovered:
			color = Color("#718b9c")
		if target_id == preview_id:
			color = Color("#e3be73")

		# A translucent diamond reads as controlled city blocks at map scale.
		# This is visual feedback only; ownership remains with WorldControlManager.
		var footprint := PackedVector2Array([
			center + Vector2(0, -82),
			center + Vector2(134, 0),
			center + Vector2(0, 82),
			center + Vector2(-134, 0)
		])
		var tint := color
		tint.a = 0.13
		draw_colored_polygon(footprint, tint)
		var border := PackedVector2Array([
			footprint[0], footprint[1], footprint[2], footprint[3], footprint[0]
		])
		draw_polyline(border, color.darkened(0.1), 3.0, true)
		draw_circle(center + Vector2(0, -99), 5.0, color)


		var pressure := control.get_pressure(target_id)
		if control.is_owned(target_id) and pressure > 0.0:
			draw_rect(Rect2(center.x - 70.0, center.y - 135.0, 140.0, 8.0), Color(0.08, 0.08, 0.08, 0.85), true)
			draw_rect(Rect2(center.x - 70.0, center.y - 135.0, 140.0 * pressure, 8.0), color, true)

		if not discovered:
			draw_circle(center + Vector2(0, -35), 30, Color("#101e29", 0.94))
			draw_arc(center + Vector2(0, -35), 30, 0, TAU, 32, color, 2, true)
			draw_string(map_font, center + Vector2(-30, -23), "?", HORIZONTAL_ALIGNMENT_CENTER, 60, 30, color)
			draw_string(map_font, center + Vector2(-145, 24), String(control.districts[target_id].name).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 290, 24, color)
		var owner_text := control.get_owner_label(target_id) if discovered else "UNSCOUTED · LEVEL %d" % int(control.districts[target_id].level)
		draw_string(
			map_font,
			center + Vector2(-125, 115),
			owner_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			250,
			20,
			color
		)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or control == null or city_map.get_view_mode() != &"world" or city_map.camera.controls_blocked:
		_tap_position = Vector2.INF
		return
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _tap_position.is_finite() and event.position.distance_to(_tap_position) > 10.0 * get_viewport_rect().size.x / float(get_window().size.x):
			_tap_position = Vector2.INF
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		_tap_position = Vector2.INF
		return
	if event is InputEventScreenTouch and event.index != 0:
		_tap_position = Vector2.INF
		return
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if event.pressed:
		_tap_position = event.position
	elif _tap_position.is_finite():
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		_tap_position = Vector2.INF
		for target in city_map.get_raid_targets():
			if not control.is_discovered(target.get_target_id()) and point.distance_to(target.position + Vector2(0, -40)) < 88.0:
				preview_requested.emit(target.get_target_id())
				get_viewport().set_input_as_handled()
				return
