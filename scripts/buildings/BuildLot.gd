class_name BuildLot
extends Area2D

const FACILITY_VISUALS := preload("res://scripts/buildings/FacilityVisuals.gd")

signal selected(lot: BuildLot)
signal changed

@export var building_name: String = "Garage"
@export var build_cash_cost: int = 12000
@export var build_duration: float = 20.0
@export var base_upgrade_cash_cost: int = 8000
@export var base_upgrade_duration: float = 18.0
@export var max_level: int = 5
@export_multiline var description: String = "An empty property ready for development."
@export var art_texture: Texture2D

var is_selected := false
var is_constructing := false
var is_built := false
var level := 0
var pending_level := 0


func _ready() -> void:
	# Once built, the optional premium image is used instead of vector scaffolding.
	var premium_path := "res://assets/premium/buildings/%s.png" % building_name.to_snake_case()
	if ResourceLoader.exists(premium_path, "Texture2D"):
		art_texture = load(premium_path) as Texture2D
	input_event.connect(_on_input_event)
	queue_redraw()


func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()


func begin_construction(target_level: int = 1) -> void:
	is_constructing = true
	pending_level = maxi(1, target_level)
	changed.emit()
	queue_redraw()


func complete_construction(target_level: int = 1) -> void:
	is_constructing = false
	is_built = true
	level = clampi(maxi(level, target_level), 1, max_level)
	pending_level = 0
	changed.emit()
	queue_redraw()


func can_upgrade() -> bool:
	return is_built and not is_constructing and level < max_level


func get_upgrade_cash_cost() -> int:
	return base_upgrade_cash_cost * maxi(1, level)


func get_upgrade_duration() -> float:
	return base_upgrade_duration * float(maxi(1, level))


func get_effect_summary() -> String:
	if not is_built:
		return "Not operational."

	match building_name:
		"Garage":
			return "Driver support +%d%% • Driver training -%d%%" % [
				level * 2,
				level * 5
			]
		"Intel Office":
			return "Spy support +%.1f%% • Spy training -%d%%" % [
				float(level) * 2.5,
				level * 5
			]
		"Scrapyard":
			return "Parts production +%d/hr" % (level * 2)
		"Data Hub":
			return "Intel production +%d/hr" % level
		_:
			return "Facility Lv.%d operational." % level


func restore_progress(built: bool, saved_level: int = 1) -> void:
	is_built = built
	level = clampi(saved_level, 1, max_level) if built else 0
	is_constructing = false
	pending_level = 0
	changed.emit()
	queue_redraw()


func _draw() -> void:
	if art_texture != null and is_built:
		var size := art_texture.get_size()
		var scale_factor := minf(168.0 / maxf(1.0, size.x), 146.0 / maxf(1.0, size.y))
		draw_texture_rect(art_texture, Rect2(-size * scale_factor * 0.5 + Vector2(0, -36), size * scale_factor), false)
		if is_selected:
			draw_arc(Vector2(0, -18), 104.0, 0.0, TAU, 48, Color(1.0, 0.82, 0.32), 5.0)
		draw_string(ThemeDB.fallback_font, Vector2(-70, 62), building_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 140, 18, Color(0.95, 0.91, 0.78))
		draw_string(ThemeDB.fallback_font, Vector2(-34, -100), "LV.%d" % level, HORIZONTAL_ALIGNMENT_CENTER, 68, 15, Color(0.95, 0.78, 0.30))
		return

	if is_built and not is_constructing:
		FACILITY_VISUALS.draw_facility(self, building_name, level)
		if is_selected:
			draw_arc(Vector2(0, -18), 104.0, 0.0, TAU, 48, Color("#f4d078"), 5.0)
		return

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
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-34, -100),
			"LV.%d" % level,
			HORIZONTAL_ALIGNMENT_CENTER,
			68,
			15,
			Color(0.95, 0.78, 0.30)
		)
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
