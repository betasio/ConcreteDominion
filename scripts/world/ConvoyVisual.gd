class_name ConvoyVisual
extends Node2D

signal arrived

var route: PackedVector2Array = PackedVector2Array()
var duration := 1.0
var elapsed := 0.0
var _segment_lengths: PackedFloat32Array = PackedFloat32Array()
var _total_length := 0.0


func setup_path(points: PackedVector2Array, travel_time: float) -> void:
	route = points
	duration = maxf(0.1, travel_time)
	elapsed = 0.0
	_rebuild_lengths()

	if route.size() > 0:
		position = route[0]

	if route.size() > 1:
		rotation = (route[1] - route[0]).angle()

	queue_redraw()


func setup(from_position: Vector2, to_position: Vector2, travel_time: float) -> void:
	setup_path(PackedVector2Array([from_position, to_position]), travel_time)


func _rebuild_lengths() -> void:
	_segment_lengths = PackedFloat32Array()
	_total_length = 0.0

	if route.size() < 2:
		return

	for i in range(route.size() - 1):
		var length := route[i].distance_to(route[i + 1])
		_segment_lengths.append(length)
		_total_length += length


func _process(delta: float) -> void:
	if route.size() < 2:
		return

	elapsed += delta
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	_update_position_on_route(eased)

	if t >= 1.0:
		arrived.emit()
		queue_free()


func _update_position_on_route(progress: float) -> void:
	if _total_length <= 0.0:
		position = route[route.size() - 1]
		return

	var target_distance := _total_length * progress
	var walked := 0.0

	for i in range(_segment_lengths.size()):
		var segment_length := float(_segment_lengths[i])

		if walked + segment_length >= target_distance:
			var local_t := (target_distance - walked) / maxf(segment_length, 0.001)
			var from := route[i]
			var to := route[i + 1]
			position = from.lerp(to, local_t)
			rotation = (to - from).angle()
			return

		walked += segment_length

	position = route[route.size() - 1]


func _draw() -> void:
	draw_rect(Rect2(-30, -13, 60, 26), Color(0.14, 0.16, 0.18), true)
	draw_rect(Rect2(-13, -20, 27, 11), Color(0.45, 0.52, 0.58), true)
	draw_rect(Rect2(14, -8, 12, 14), Color(0.62, 0.48, 0.20), true)
	draw_circle(Vector2(-18, 15), 6.0, Color(0.04, 0.04, 0.04))
	draw_circle(Vector2(18, 15), 6.0, Color(0.04, 0.04, 0.04))
	draw_line(Vector2(-36, 0), Vector2(-52, 0), Color(0.85, 0.65, 0.25, 0.55), 3.0)
