class_name Building
extends Area2D

const FACILITY_VISUALS := preload("res://scripts/buildings/FacilityVisuals.gd")

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
	# Optional premium art pack: preserve the original visual when assets are absent.
	var premium_path := "res://assets/premium/buildings/%s.png" % String(building_type)
	if ResourceLoader.exists(premium_path, "Texture2D"):
		art_texture = load(premium_path) as Texture2D
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
		var art_width := 208.0 if building_type == &"safehouse" else 172.0
		var art_height := 186.0 if building_type == &"safehouse" else 154.0
		var scale_factor := minf(art_width / maxf(1.0, size.x), art_height / maxf(1.0, size.y))
		# Anchor the illustration by its footprint so roofs rise above the lot
		# rather than drifting when different source aspect ratios are imported.
		var rendered_size := size * scale_factor
		draw_texture_rect(art_texture, Rect2(Vector2(-rendered_size.x * 0.5, 38.0 - rendered_size.y), rendered_size), false)
		if is_constructing:
			draw_arc(Vector2(0, -35), 108.0, 0.0, TAU, 48, Color(0.90, 0.68, 0.20), 4.0)
		if is_selected:
			draw_arc(Vector2(0, -35), 112.0, 0.0, TAU, 48, Color(1.0, 0.82, 0.32), 5.0)
		var art_level_text := "Lv.%d" % level
		if is_constructing:
			art_level_text += " → %d" % pending_level
		elif level >= max_level:
			art_level_text += " MAX"
		var map_label := "BARRACKS" if building_type == &"barracks" else ("CLINIC" if building_type == &"hospital" else display_name.to_upper())
		draw_string(ThemeDB.fallback_font, Vector2(-86, 62), map_label, HORIZONTAL_ALIGNMENT_CENTER, 172, 17, Color(0.95, 0.91, 0.78))
		draw_string(ThemeDB.fallback_font, Vector2(-42, 84), art_level_text, HORIZONTAL_ALIGNMENT_CENTER, 84, 16, accent_color)
		return

	FACILITY_VISUALS.draw_facility(self, String(building_type), level)
	if is_constructing:
		draw_arc(Vector2(0, -35), 108.0, 0.0, TAU, 48, Color("#e3ae47"), 4.0)
	if is_selected:
		draw_arc(Vector2(0, -35), 112.0, 0.0, TAU, 48, Color("#f4d078"), 5.0)
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
