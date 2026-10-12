class_name BuildLot
extends Area2D

const FACILITY_VISUALS := preload("res://scripts/buildings/FacilityVisuals.gd")
const ESTATE_LAYOUT := preload("res://scripts/world/IllustratedEstateLayout.gd")
const MAP_LABEL := preload("res://scripts/buildings/MapSiteLabel.gd")

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
@export var use_illustrated_pad: bool = false

var is_selected := false
var is_constructing := false
var is_built := false
var level := 0
var pending_level := 0
var illustrated_footprint := Vector2(78, 41)


func configure_illustrated_pad(half_size: Vector2) -> void:
	use_illustrated_pad = true
	var facade := preload("res://scripts/buildings/EstateFacadeArt.gd").texture(building_name)
	if facade != null:
		art_texture = facade
	illustrated_footprint = half_size
	# Replace this instance's oversized legacy rectangle, never the shared
	# scene resource. The whole stone pad remains selectable in every state.
	var collision := get_node("CollisionShape2D") as CollisionShape2D
	var shape := ConvexPolygonShape2D.new()
	shape.points = _illustrated_outline()
	collision.shape = shape
	queue_redraw()


func _illustrated_outline() -> PackedVector2Array:
	return ESTATE_LAYOUT.pad_outline(self,illustrated_footprint)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
			return "Supplies production +%d/hr" % (level * 2)
		"Data Hub":
			return "Intel +%d/hr • Radar: %s" % [level,"incoming faction identity" if level == 1 else "incoming faction, strategy and members"]
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
	if use_illustrated_pad:
		_draw_illustrated_site()
		return
	if art_texture != null and is_built:
		var size := art_texture.get_size()
		var scale_factor := minf(168.0 / maxf(1.0, size.x), 146.0 / maxf(1.0, size.y))
		var rendered_size := size * scale_factor
		draw_texture_rect(art_texture, Rect2(Vector2(-rendered_size.x * 0.5, 35.0 - rendered_size.y), rendered_size), false)
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
		# Vacant parcels should resemble secured development plots rather
		# than large generic placeholder labels in the premium turf view.
		var slab := PackedVector2Array([
			Vector2(0, -45), Vector2(68, -10),
			Vector2(0, 24), Vector2(-68, -10)
		])
		draw_colored_polygon(slab, Color("#26343d"))
		draw_polyline(PackedVector2Array([slab[0], slab[1], slab[2], slab[3], slab[0]]), Color("#6c7980"), 2.0, true)
		for offset in [-30.0, 0.0, 30.0]:
			draw_line(Vector2(offset - 11.0, -14.0), Vector2(offset + 11.0, -2.0), Color("#a58b5e", 0.46), 1.5)
		# Survey stakes and work lights communicate that this plot can be built.
		for post in [Vector2(-63, -10), Vector2(63, -10)]:
			draw_line(post, post + Vector2(0, -18), Color("#495662"), 4.0)
			draw_circle(post + Vector2(0, -19), 3.0, Color("#dcb879"))
		draw_string(ThemeDB.fallback_font, Vector2(-54, -25), "AVAILABLE", HORIZONTAL_ALIGNMENT_CENTER, 108, 13, Color("#f0ca82"))

	if is_selected:
		draw_arc(Vector2(0, -18), 104.0, 0.0, TAU, 48, Color(1.0, 0.82, 0.32), 5.0)

	var label := building_name if is_built else ("BUILDING" if is_constructing else "BUILD SITE")
	# Keep facility identity visible in compact lots; long facility names previously
	# clipped against adjacent buildings and the screen edge at 1280x720.
	if not is_built and not is_constructing:
		label = "%s SITE" % building_name
	var label_font_size := 14 if label.length() > 12 else 16
	draw_string(ThemeDB.fallback_font, Vector2(-82, 58), label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 164, label_font_size, Color(0.95, 0.91, 0.78))


func _draw_illustrated_site() -> void:
	# The painted terrain supplies the foundation in ALL construction states.
	# Only the occupied building, a small action marker and labels belong here.
	if is_selected:
		var outline := _illustrated_outline()
		outline.append(outline[0])
		draw_polyline(outline, Color("#f4d078"), 2.5, true)
	if is_built:
		# The terrain already contains the gate joined exactly to its wall.
		# Keep its live selection/upgrade state without drawing a second gate.
		if building_name != "Estate Gate":
			if art_texture != null:
				ESTATE_LAYOUT.draw_building(self,art_texture,illustrated_footprint)
			else:
				FACILITY_VISUALS.draw_facility(self,building_name,level)
	else:
		var gold := Color("#f5d69c")
		draw_circle(Vector2(0, -4), 18.0, Color("#14242b", 0.94))
		draw_arc(Vector2(0, -4), 18.0, 0.0, TAU, 40, gold, 2.0, true)
		if is_constructing:
			# Hammer: a state indicator, not a fabricated progress percentage.
			draw_line(Vector2(-5, 5), Vector2(5, -9), gold, 3.0, true)
			draw_line(Vector2(0, -13), Vector2(10, -6), gold, 5.0, true)
		else:
			draw_line(Vector2(-7, -4), Vector2(7, -4), gold, 2.5, true)
			draw_line(Vector2(0, -11), Vector2(0, 3), gold, 2.5, true)
	var title := building_name.to_upper()
	if is_built or is_constructing:
		var status := "BUILDING" if not is_built else "LV.%d" % level
		if is_built and is_constructing:
			status += " → %d" % pending_level
		title += " · " + status
	var badge_y := 18.0 if not is_built else illustrated_footprint.y*0.45
	if building_name == "Estate Gate":
		badge_y = -120.0
	elif name == &"RallyHall":
		badge_y = -26.0
	elif name == &"BuildLotA" and is_built:
		badge_y = -22.0
	MAP_LABEL.draw_badge(self,title,badge_y,16)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed

	if pressed:
		selected.emit(self)
		get_viewport().set_input_as_handled()
