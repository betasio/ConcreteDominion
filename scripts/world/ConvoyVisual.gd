class_name ConvoyVisual
extends Node2D

signal arrived

var start_position := Vector2.ZERO
var end_position := Vector2.ZERO
var duration := 1.0
var elapsed := 0.0


func setup(from_position: Vector2, to_position: Vector2, travel_time: float) -> void:
	start_position = from_position
	end_position = to_position
	duration = maxf(0.1, travel_time)
	position = start_position
	rotation = (end_position - start_position).angle()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	position = start_position.lerp(end_position, eased)

	if t >= 1.0:
		arrived.emit()
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-28, -12, 56, 24), Color(0.18, 0.20, 0.22), true)
	draw_rect(Rect2(-12, -18, 24, 10), Color(0.42, 0.48, 0.52), true)
	draw_circle(Vector2(-17, 14), 6.0, Color(0.05, 0.05, 0.05))
	draw_circle(Vector2(17, 14), 6.0, Color(0.05, 0.05, 0.05))
