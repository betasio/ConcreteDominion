class_name RaidTarget
extends Area2D

signal selected(target: RaidTarget)
signal changed

@export var target_id: String = "downtown_bank"
@export var display_name: String = "Downtown Bank"
@export var difficulty: String = "Medium"
@export var max_hp: float = 9000.0
@export var reward_cash: int = 7500
@export var cooldown_seconds: float = 30.0
@export var accent_color: Color = Color(0.72, 0.52, 0.18)

var cooldown_remaining := 0.0
var is_selected := false
var _last_displayed_second := -1


func _ready() -> void:
	input_event.connect(_on_input_event)
	queue_redraw()


func _process(delta: float) -> void:
	if cooldown_remaining <= 0.0:
		return

	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	var shown := ceili(cooldown_remaining)
	if shown != _last_displayed_second:
		_last_displayed_second = shown
		changed.emit()
		queue_redraw()

	if cooldown_remaining <= 0.0:
		_last_displayed_second = -1
		changed.emit()
		queue_redraw()


func is_available() -> bool:
	return cooldown_remaining <= 0.0


func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()


func start_cooldown() -> void:
	cooldown_remaining = maxf(0.0, cooldown_seconds)
	_last_displayed_second = -1
	changed.emit()
	queue_redraw()


func get_battle_data() -> Dictionary:
	return {
		"id": target_id,
		"name": display_name,
		"hp": max_hp,
		"reward_cash": reward_cash,
		"difficulty": difficulty
	}


func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining
	}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	cooldown_remaining = maxf(
		0.0,
		float(data.get("cooldown_remaining", 0.0)) - maxf(0.0, offline_seconds)
	)
	_last_displayed_second = -1
	changed.emit()
	queue_redraw()


func _draw() -> void:
	var base := PackedVector2Array([
		Vector2(0, -62),
		Vector2(95, -14),
		Vector2(0, 34),
		Vector2(-95, -14)
	])

	var building := PackedVector2Array([
		Vector2(-58, -28),
		Vector2(0, -58),
		Vector2(58, -28),
		Vector2(58, -105),
		Vector2(0, -134),
		Vector2(-58, -105)
	])

	var body_color := Color(0.20, 0.21, 0.23) if is_available() else Color(0.13, 0.14, 0.15)

	draw_colored_polygon(base, Color(0.09, 0.10, 0.11))
	draw_polyline(PackedVector2Array([base[0], base[1], base[2], base[3], base[0]]), accent_color, 3.0)
	draw_colored_polygon(building, body_color)
	draw_polyline(PackedVector2Array([building[0], building[1], building[2], building[3], building[4], building[5], building[0]]), accent_color.darkened(0.2), 3.0)

	if target_id.contains("bank"):
		draw_rect(Rect2(-34, -92, 68, 36), accent_color.darkened(0.25), true)
		draw_string(ThemeDB.fallback_font, Vector2(-20, -66), "$", HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Color.WHITE)
	else:
		draw_rect(Rect2(-34, -93, 68, 38), accent_color.darkened(0.3), true)
		draw_string(ThemeDB.fallback_font, Vector2(-28, -66), "HQ", HORIZONTAL_ALIGNMENT_CENTER, 56, 20, Color.WHITE)

	if not is_available():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-70, 12),
			"RESPAWN %02d" % ceili(cooldown_remaining),
			HORIZONTAL_ALIGNMENT_CENTER,
			140,
			15,
			Color(0.85, 0.75, 0.55)
		)

	if is_selected:
		draw_arc(Vector2(0, -38), 114.0, 0.0, TAU, 48, Color(1.0, 0.82, 0.32), 5.0)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(-78, 65),
		display_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		156,
		17,
		Color(0.95, 0.91, 0.78)
	)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var pressed := false

	if event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed

	if pressed:
		selected.emit(self)
		get_viewport().set_input_as_handled()
