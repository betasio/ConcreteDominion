class_name TurfOverlay
extends Node2D

var control: WorldControlManager
var city_map: Node


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
		if not control.is_discovered(target_id):
			continue

		var center: Vector2 = target.position + Vector2(0, -25)
		var color := Color(0.72, 0.24, 0.24, 0.78)
		if control.is_owned(target_id):
			color = Color(0.20, 0.72, 0.42, 0.82)
		if control.is_contested(target_id):
			color = Color(0.95, 0.62, 0.18, 0.9)

		draw_arc(center, 112.0, 0.0, TAU, 48, color, 5.0)

		var pressure := control.get_pressure(target_id)
		if control.is_owned(target_id) and pressure > 0.0:
			draw_rect(Rect2(center.x - 70.0, center.y - 135.0, 140.0, 8.0), Color(0.08, 0.08, 0.08, 0.85), true)
			draw_rect(Rect2(center.x - 70.0, center.y - 135.0, 140.0 * pressure, 8.0), color, true)

		var owner_text := control.get_owner_label(target_id)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-80, 125),
			owner_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			160,
			15,
			color
		)
