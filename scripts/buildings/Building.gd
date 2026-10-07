class_name Building
extends Area2D

signal selected(building: Building)
signal changed

@export var building_type: StringName = &"building"
@export var display_name: String = "Building"
@export_multiline var description: String = ""
@export var accent_color: Color = Color(0.78, 0.62, 0.25)
@export var level: int = 1
@export var max_level: int = 5
@export var base_upgrade_cash_cost: int = 5000
@export var base_upgrade_duration: float = 15.0
@export var art_texture: Texture2D

var is_selected := false
var is_constructing := false
var pending_level := 0


func _ready() -> void:
	input_event.connect(_on_input_event)
	queue_redraw()


func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()


func can_upgrade() -> bool:
	return not is_constructing and level < max_level


func get_upgrade_cash_cost() -> int:
	return base_upgrade_cash_cost * level


func get_upgrade_duration() -> float:
	return base_upgrade_duration * float(level)


func begin_construction(target_level: int) -> void:
	is_constructing = true
	pending_level = mini(max_level, maxi(level + 1, target_level))
	changed.emit()
	queue_redraw()


func complete_construction(target_level: int) -> void:
	level = clampi(maxi(level, target_level), 1, max_level)
	pending_level = 0
	is_constructing = false
	changed.emit()
	queue_redraw()


func restore_progress(saved_level: int) -> void:
	level = clampi(saved_level, 1, max_level)
	pending_level = 0
	is_constructing = false
	changed.emit()
	queue_redraw()


func _draw() -> void:
	if art_texture != null:
		var size := art_texture.get_size()
		var scale_factor := minf(132.0 / maxf(1.0, size.x), 116.0 / maxf(1.0, size.y))
		draw_texture_rect(art_texture, Rect2(-size * scale_factor * 0.5 + Vector2(0, -42), size * scale_factor), false)
		if is_constructing:
			draw_arc(Vector2(0, -35), 108.0, 0.0, TAU, 48, Color(0.90, 0.68, 0.20), 4.0)
		if is_selected:
			draw_arc(Vector2(0, -35), 112.0, 0.0, TAU, 48, Color(1.0, 0.82, 0.32), 5.0)
		var art_level_text := "Lv.%d" % level
		if is_constructing:
			art_level_text += " → %d" % pending_level
		elif level >= max_level:
			art_level_text += " MAX"
		draw_string(ThemeDB.fallback_font, Vector2(-72, 62), display_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 144, 18, Color(0.95, 0.91, 0.78))
		draw_string(ThemeDB.fallback_font, Vector2(-42, 84), art_level_text, HORIZONTAL_ALIGNMENT_CENTER, 84, 16, accent_color)
		return

	var footprint := PackedVector2Array([
		Vector2(0, -58),
		Vector2(92, -12),
		Vector2(0, 34),
		Vector2(-92, -12)
	])
	var wall := PackedVector2Array([
		Vector2(-60, -18),
		Vector2(0, -50),
		Vector2(60, -18),
		Vector2(60, -88),
		Vector2(0, -120),
		Vector2(-60, -88)
	])

	draw_colored_polygon(footprint, Color(0.10, 0.11, 0.12))
	draw_polyline(PackedVector2Array([footprint[0], footprint[1], footprint[2], footprint[3], footprint[0]]), accent_color, 3.0)
	draw_colored_polygon(wall, Color(0.18, 0.19, 0.21))
	draw_polyline(PackedVector2Array([wall[0], wall[1], wall[2], wall[3], wall[4], wall[5], wall[0]]), accent_color.darkened(0.2), 3.0)

	if building_type == &"hospital":
		draw_rect(Rect2(-17, -102, 34, 62), accent_color, true)
		draw_rect(Rect2(-31, -88, 62, 34), accent_color, true)
	else:
		draw_rect(Rect2(-18, -84, 36, 46), accent_color.darkened(0.25), true)

	if is_constructing:
		draw_line(Vector2(-76, -120), Vector2(-76, 12), Color(0.90, 0.68, 0.20), 5.0)
		draw_line(Vector2(76, -120), Vector2(76, 12), Color(0.90, 0.68, 0.20), 5.0)
		draw_line(Vector2(-82, -95), Vector2(82, -95), Color(0.90, 0.68, 0.20), 5.0)

	if is_selected:
		draw_arc(Vector2(0, -35), 112.0, 0.0, TAU, 48, Color(1.0, 0.82, 0.32), 5.0)

	var level_text := "Lv.%d" % level
	if is_constructing:
		level_text += " → %d" % pending_level
	elif level >= max_level:
		level_text += " MAX"

	draw_string(ThemeDB.fallback_font, Vector2(-72, 62), display_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 144, 18, Color(0.95, 0.91, 0.78))
	draw_string(ThemeDB.fallback_font, Vector2(-42, 84), level_text, HORIZONTAL_ALIGNMENT_CENTER, 84, 16, accent_color)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed

	if pressed:
		selected.emit(self)
		get_viewport().set_input_as_handled()
