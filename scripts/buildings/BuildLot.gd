class_name BuildLot
extends Area2D

signal selected(lot: BuildLot)

@export var building_name: String = "Garage"
@export var build_cash_cost: int = 12000
@export var build_duration: float = 20.0
@export_multiline var description: String = "An empty property ready for development."

var is_selected := false
var is_constructing := false
var is_built := false


func _ready() -> void:
	input_event.connect(_on_input_event)
	queue_redraw()


func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()


func begin_construction() -> void:
	is_constructing = true
	queue_redraw()


func complete_construction(_target_level: int = 1) -> void:
	is_constructing = false
	is_built = true
	queue_redraw()


func _draw() -> void:
	var diamond := PackedVector2Array([
		Vector2(0, -55),
		Vector2(90, -10),
		Vector2(0, 35),
		Vector2(-90, -10)
	])

	var fill := Color(0.16, 0.17, 0.16)
	if is_constructing:
		fill = Color(0.30, 0.25, 0.15)
	elif is_built:
		fill = Color(0.16, 0.24, 0.20)

	draw_colored_polygon(diamond, fill)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0.72, 0.58, 0.24), 3.0)

	if is_built:
		draw_rect(Rect2(-45, -90, 90, 65), Color(0.22, 0.24, 0.27), true)
		draw_rect(Rect2(-24, -55, 48, 30), Color(0.48, 0.52, 0.56), true)
	elif is_constructing:
		for x in [-42, 0, 42]:
			draw_line(Vector2(x, -72), Vector2(x, 5), Color(0.80, 0.64, 0.28), 5.0)
		draw_line(Vector2(-58, -52), Vector2(58, -52), Color(0.80, 0.64, 0.28), 5.0)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-52, -12), "EMPTY LOT", HORIZONTAL_ALIGNMENT_CENTER, 104, 16, Color(0.80, 0.76, 0.65))

	if is_selected:
		draw_arc(Vector2(0, -18), 104.0, 0.0, TAU, 48, Color(1.0, 0.82, 0.32), 5.0)

	var label := building_name if is_built else ("BUILDING..." if is_constructing else "BUILD LOT")
	draw_string(ThemeDB.fallback_font, Vector2(-70, 62), label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 140, 18, Color(0.95, 0.91, 0.78))


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed

	if pressed:
		selected.emit(self)
		get_viewport().set_input_as_handled()
