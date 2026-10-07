class_name RaidImpactVFX
extends Node2D

@export var duration: float = 0.9

var elapsed := 0.0
var victory := true


func setup(is_victory: bool) -> void:
	victory = is_victory
	elapsed = 0.0
	scale = Vector2(0.25, 0.25)
	modulate.a = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	var t := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.25, 1.8, t)
	modulate.a = 1.0 - t
	queue_redraw()

	if t >= 1.0:
		queue_free()


func _draw() -> void:
	var core := Color(1.0, 0.72, 0.18, 0.9) if victory else Color(0.85, 0.24, 0.18, 0.9)
	var smoke := Color(0.30, 0.31, 0.33, 0.7)

	draw_circle(Vector2.ZERO, 28.0, core)
	draw_circle(Vector2(-28, -10), 18.0, smoke)
	draw_circle(Vector2(24, -18), 16.0, smoke)
	draw_circle(Vector2(10, 24), 20.0, smoke)

	for i in range(10):
		var angle := TAU * float(i) / 10.0
		var inner := Vector2.RIGHT.rotated(angle) * 26.0
		var outer := Vector2.RIGHT.rotated(angle) * 62.0
		draw_line(inner, outer, core, 4.0)
