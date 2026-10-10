extends Node2D

signal building_selected(building: Building)
signal lot_selected(lot: BuildLot)
signal raid_target_selected(target: RaidTarget)
signal view_mode_changed(mode: StringName)

const CONVOY_SCENE := preload("res://scenes/world/ConvoyVisual.tscn")
const RAID_IMPACT_SCENE := preload("res://scenes/effects/RaidImpactVFX.tscn")
const HQ_HYBRID_SCRIPT := preload("res://scripts/world/HQHybridVisual.gd")

@export var grid_width: int = 24
@export var grid_height: int = 20
@export var tile_width: float = 128.0
@export var tile_height: float = 64.0

@onready var camera: Camera2D = $StrategyCamera
@onready var buildings_layer: Node2D = $Buildings
@onready var raid_targets_layer: Node2D = $RaidTargets
@onready var convoy_layer: Node2D = $Convoys
@onready var effects_layer: Node2D = $Effects
@onready var safehouse: Building = $Buildings/Safehouse
@onready var hospital: Building = $Buildings/Hospital
@onready var barracks: Building = $Buildings/Barracks
@onready var lot_a: BuildLot = $Buildings/BuildLotA
@onready var lot_b: BuildLot = $Buildings/BuildLotB
@onready var lot_c: BuildLot = $Buildings/BuildLotC
@onready var lot_d: BuildLot = $Buildings/BuildLotD
@onready var turf_overlay: TurfOverlay = $TurfOverlay
@onready var downtown_bank: RaidTarget = $RaidTargets/DowntownBank
@onready var harbor_bank: RaidTarget = $RaidTargets/HarborBank
@onready var northside_hq: RaidTarget = $RaidTargets/NorthsideHQ
@onready var casino_vault: RaidTarget = $RaidTargets/CasinoVault
@onready var financial_tower: RaidTarget = $RaidTargets/FinancialTower
@onready var midtown_exchange: RaidTarget = $RaidTargets/MidtownExchange
@onready var industrial_depot: RaidTarget = $RaidTargets/IndustrialDepot

var selected_target: Node
var active_convoy: ConvoyVisual
var view_mode: StringName = &"base"
var progression: PlayerProgression
var presentation: PresentationCatalog

var _road_color := Color(0.17, 0.19, 0.21)
var _lot_color_a := Color(0.22, 0.25, 0.23)
var _lot_color_b := Color(0.25, 0.28, 0.26)
var _line_color := Color(0.38, 0.42, 0.39, 0.55)


func setup_progression(player_progression: PlayerProgression) -> void:
	progression = player_progression
	for target in get_raid_targets():
		target.setup_progression(progression)


func setup_presentation(catalog: PresentationCatalog) -> void:
	presentation = catalog
	queue_redraw()


func _ready() -> void:
	# Upper prestige terrace, middle security/medical terrace and lower
	# service yards. Position changes only: node identity/save keys stay intact.
	safehouse.position = iso_to_screen(Vector2i(10, 7)) + Vector2(0, -60)
	hospital.position = iso_to_screen(Vector2i(7, 10))
	barracks.position = iso_to_screen(Vector2i(13, 10))
	lot_a.position = iso_to_screen(Vector2i(11, 15))  # Garage: lower drive
	lot_b.position = iso_to_screen(Vector2i(14, 12))  # Intel: secure flank
	lot_c.position = iso_to_screen(Vector2i(7, 15))   # Scrapyard: outer service
	lot_d.position = iso_to_screen(Vector2i(15, 15))  # Data Hub: lower flank

	downtown_bank.position = iso_to_screen(Vector2i(4, 6))
	harbor_bank.position = iso_to_screen(Vector2i(19, 6))
	northside_hq.position = iso_to_screen(Vector2i(19, 15))
	casino_vault.position = iso_to_screen(Vector2i(4, 15))
	financial_tower.position = iso_to_screen(Vector2i(22, 10))
	midtown_exchange.position = iso_to_screen(Vector2i(4, 10))
	industrial_depot.position = iso_to_screen(Vector2i(22, 17))

	if ProjectSettings.get_setting("concrete_dominion/enable_3d_safehouse", true):
		var hybrid := Node2D.new()
		hybrid.name = "HQHybridVisual"
		hybrid.set_script(HQ_HYBRID_SCRIPT)
		safehouse.add_child(hybrid)
		safehouse.render_3d_art = true
		safehouse.queue_redraw()

	safehouse.selected.connect(_select_building)
	hospital.selected.connect(_select_building)
	barracks.selected.connect(_select_building)
	lot_a.selected.connect(_select_lot)
	lot_b.selected.connect(_select_lot)
	lot_c.selected.connect(_select_lot)
	lot_d.selected.connect(_select_lot)

	for target in get_raid_targets():
		target.selected.connect(_select_raid_target)

	set_view_mode(&"base")
	queue_redraw()


func _base_composition_center() -> Vector2:
	# Frame the playable estate from its real building bounds rather than
	# repeatedly hand-tuning offsets after each terrace rearrangement.
	var sites: Array[Vector2] = [
		safehouse.position, hospital.position, barracks.position,
		lot_a.position, lot_b.position, lot_c.position, lot_d.position
	]
	var left: float = sites[0].x
	var right: float = left
	var top: float = sites[0].y
	var bottom: float = top
	for p in sites:
		left = minf(left, p.x)
		right = maxf(right, p.x)
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	# Give the upper HQ art some sky and the Garage drive space at the foot.
	return Vector2((left + right) * 0.5, (top + bottom) * 0.5 + 23.0)


func set_view_mode(mode: StringName) -> void:
	if mode != &"base" and mode != &"world":
		return

	var previous_mode: StringName = view_mode
	view_mode = mode
	_clear_selection()
	var destination: Vector2 = _base_composition_center() if mode == &"base" else Vector2(0, 140)
	var destination_zoom := Vector2(1.02, 1.02) if mode == &"base" else Vector2(0.72, 0.72)
	# Preserve immediate initialization and save restoration; animate user switches.
	var animate_camera: bool = is_inside_tree() and previous_mode != mode
	if camera.has_meta("view_tween"):
		var old_tween: Tween = camera.get_meta("view_tween") as Tween
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	if view_mode == &"base":
		buildings_layer.visible = true
		raid_targets_layer.visible = false
		convoy_layer.visible = false
		effects_layer.visible = false
		# Camera is moved after visibility changes.
	else:
		buildings_layer.visible = false
		raid_targets_layer.visible = true
		convoy_layer.visible = true
		effects_layer.visible = true
		# Camera is moved after visibility changes.

	if animate_camera:
		var camera_tween := create_tween().set_parallel(true)
		camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		camera_tween.tween_property(camera, "position", destination, 0.48)
		camera_tween.tween_property(camera, "zoom", destination_zoom, 0.48)
		camera.set_meta("view_tween", camera_tween)
	else:
		camera.position = destination
		camera.zoom = destination_zoom

	view_mode_changed.emit(view_mode)
	queue_redraw()


func get_view_mode() -> StringName:
	return view_mode


func get_persistent_buildings() -> Array:
	return [safehouse, hospital, barracks, lot_a, lot_b, lot_c, lot_d]


func get_raid_targets() -> Array:
	return [downtown_bank, harbor_bank, midtown_exchange, northside_hq, casino_vault, financial_tower, industrial_depot]


func get_raid_target_by_id(target_id: String) -> RaidTarget:
	for target in get_raid_targets():
		if target.get_target_id() == target_id:
			return target
	return null


func focus_raid_target_by_id(target_id: String) -> void:
	var target := get_raid_target_by_id(target_id)
	if target == null:
		return

	if view_mode != &"world":
		set_view_mode(&"world")
	if not target.visible:
		return

	focus_raid_target(target)


func launch_convoy_to(target_id: String, travel_time: float) -> void:
	var target := get_raid_target_by_id(target_id)
	if target == null:
		return

	if active_convoy != null and is_instance_valid(active_convoy):
		active_convoy.queue_free()

	active_convoy = CONVOY_SCENE.instantiate()
	convoy_layer.add_child(active_convoy)
	active_convoy.setup_path(_get_convoy_route(target_id), travel_time)


func restore_active_convoy(target_id: String, remaining_time: float) -> void:
	if remaining_time <= 0.0:
		return
	launch_convoy_to(target_id, remaining_time)


func show_raid_impact(result: Dictionary) -> void:
	var target := get_raid_target_by_id(String(result.get("target_id", "")))
	if target == null:
		return

	var effect: RaidImpactVFX = RAID_IMPACT_SCENE.instantiate()
	effects_layer.add_child(effect)
	effect.position = target.position + Vector2(0, -65)
	effect.setup(bool(result.get("victory", false)))


func _get_convoy_route(target_id: String) -> PackedVector2Array:
	var cells: Array[Vector2i] = [Vector2i(10, 10), Vector2i(12, 10), Vector2i(12, 7)]

	match target_id:
		"downtown_bank":
			cells.append_array([Vector2i(7, 7), Vector2i(7, 6), Vector2i(4, 6)])
		"harbor_bank":
			cells.append_array([Vector2i(17, 7), Vector2i(19, 7), Vector2i(19, 6)])
		"northside_hq":
			cells.append_array([Vector2i(12, 12), Vector2i(17, 12), Vector2i(17, 15), Vector2i(19, 15)])
		"casino_vault":
			cells.append_array([Vector2i(7, 7), Vector2i(7, 12), Vector2i(4, 12), Vector2i(4, 15)])
		"financial_tower":
			cells.append_array([Vector2i(17, 7), Vector2i(22, 7), Vector2i(22, 10)])
		"midtown_exchange":
			cells.append_array([Vector2i(7, 7), Vector2i(7, 10), Vector2i(4, 10)])
		"industrial_depot":
			cells.append_array([Vector2i(17, 12), Vector2i(22, 12), Vector2i(22, 17)])
		_:
			var target := get_raid_target_by_id(target_id)
			if target != null:
				return PackedVector2Array([
					safehouse.position + Vector2(0, -35),
					target.position + Vector2(0, -35)
				])

	var route := PackedVector2Array()
	for cell in cells:
		route.append(iso_to_screen(cell) + Vector2(0, -35))
	return route


func get_persistent_target(target_id: String) -> Node:
	match target_id:
		"safehouse":
			return safehouse
		"hospital":
			return hospital
		"barracks":
			return barracks
		"lot_garage":
			return lot_a
		"lot_intel":
			return lot_b
		"lot_scrapyard":
			return lot_c
		"lot_datahub":
			return lot_d
		_:
			return null


func get_target_id(target: Node) -> String:
	if target == safehouse:
		return "safehouse"
	if target == hospital:
		return "hospital"
	if target == barracks:
		return "barracks"
	if target == lot_a:
		return "lot_garage"
	if target == lot_b:
		return "lot_intel"
	if target == lot_c:
		return "lot_scrapyard"
	if target == lot_d:
		return "lot_datahub"
	return ""


func get_save_data() -> Dictionary:
	var raid_target_data := {}
	for target in get_raid_targets():
		raid_target_data[target.get_target_id()] = target.get_save_data()

	return {
		"safehouse_level": safehouse.level,
		"hospital_level": hospital.level,
		"barracks_level": barracks.level,
		"garage_built": lot_a.is_built,
		"garage_level": lot_a.level,
		"intel_built": lot_b.is_built,
		"intel_level": lot_b.level,
		"scrapyard_built": lot_c.is_built,
		"scrapyard_level": lot_c.level,
		"datahub_built": lot_d.is_built,
		"datahub_level": lot_d.level,
		"raid_targets": raid_target_data,
		"view_mode": String(view_mode)
	}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	safehouse.restore_progress(int(data.get("safehouse_level", safehouse.level)))
	hospital.restore_progress(int(data.get("hospital_level", hospital.level)))
	barracks.restore_progress(int(data.get("barracks_level", barracks.level)))
	lot_a.restore_progress(bool(data.get("garage_built", lot_a.is_built)), int(data.get("garage_level", 1)))
	lot_b.restore_progress(bool(data.get("intel_built", lot_b.is_built)), int(data.get("intel_level", 1)))
	lot_c.restore_progress(bool(data.get("scrapyard_built", lot_c.is_built)), int(data.get("scrapyard_level", 1)))
	lot_d.restore_progress(bool(data.get("datahub_built", lot_d.is_built)), int(data.get("datahub_level", 1)))

	var raid_target_data = data.get("raid_targets", {})
	if raid_target_data is Dictionary:
		for target in get_raid_targets():
			target.load_save_data(
				raid_target_data.get(target.get_target_id(), {}),
				offline_seconds
			)

	set_view_mode(StringName(data.get("view_mode", "base")))


func _draw() -> void:
	if view_mode == &"base":
		_draw_estate_backdrop()
		return
	for y in range(grid_height):
		for x in range(grid_width):
			var center := iso_to_screen(Vector2i(x, y))
			var is_road := x % 5 == 2 or y % 5 == 2
			var color := _road_color if is_road else (_lot_color_a if (x + y) % 2 == 0 else _lot_color_b)
			_draw_diamond(center, color)

	_draw_street_art()


func _draw_estate_backdrop() -> void:
	# The HQ view is an estate, not a tactical grid. Reserve grid lines and
	# road-atlas intersections for World view only.
	# The distant panorama sits behind this Node2D. Avoid painting an opaque\n	# rectangle over it; keep the old backdrop only when the PNG is missing.\n	if not ResourceLoader.exists("res://assets/backgrounds/coastal_estate/ConcreteDominion_Golden_Bay_Background.png"):\n		draw_rect(Rect2(Vector2(-3000, -2200), Vector2(6000, 4400)), Color("#1c292e"))
	# Original procedural distant hills also hide the skyline; they are only a fallback.\n	if ResourceLoader.exists("res://assets/backgrounds/coastal_estate/ConcreteDominion_Golden_Bay_Background.png"):\n		return\n	var ridges := [
		PackedVector2Array([
			Vector2(-1800, -1100), Vector2(-400, -750), Vector2(160, -900),
			Vector2(1400, -450), Vector2(1900, 350), Vector2(-1800, 350)
		]),
		PackedVector2Array([
			Vector2(-1700, 120), Vector2(-880, -170), Vector2(-360, -20),
			Vector2(250, 300), Vector2(1100, 700), Vector2(-1700, 1200)
		])
	]
	draw_colored_polygon(ridges[0], Color("#26383b"))
	draw_colored_polygon(ridges[1], Color("#1a3232"))
	# Quiet silhouettes imply distant hills rather than repetitive box blocks.
	for x in range(-1600, 1700, 310):
		var y := -430.0 + sin(float(x) * 0.006) * 85.0
		draw_circle(Vector2(float(x), y), 120.0, Color("#2d4942", 0.40))
		draw_circle(Vector2(float(x) + 55.0, y - 30.0), 72.0, Color("#375348", 0.25))


func _draw_street_art() -> void:
	if presentation == null:
		return

	var intersection := presentation.get_decor_texture("road_intersection")
	var straight := presentation.get_decor_texture("road_straight")
	if intersection == null:
		return

	# Decorative overlays sit on top of the procedural road diamonds. This keeps
	# navigation readable while adding the approved asphalt/crosswalk language.
	for y in range(2, grid_height, 5):
		for x in range(2, grid_width, 5):
			var center := iso_to_screen(Vector2i(x, y))
			draw_texture_rect(
				intersection,
				Rect2(center - Vector2(60, 40), Vector2(120, 80)),
				false,
				Color(1, 1, 1, 0.92)
			)

	if straight == null:
		return

	for x in range(7, grid_width, 10):
		var center := iso_to_screen(Vector2i(x, 2))
		draw_texture_rect(
			straight,
			Rect2(center - Vector2(54, 33), Vector2(108, 66)),
			false,
			Color(1, 1, 1, 0.72)
		)

	for y in range(7, grid_height, 10):
		var center := iso_to_screen(Vector2i(2, y))
		draw_set_transform(center, PI * 0.5, Vector2.ONE)
		draw_texture_rect(
			straight,
			Rect2(Vector2(-54, -33), Vector2(108, 66)),
			false,
			Color(1, 1, 1, 0.72)
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func iso_to_screen(cell: Vector2i) -> Vector2:
	var origin := Vector2(0.0, -grid_height * tile_height * 0.25)
	return origin + Vector2(
		(cell.x - cell.y) * tile_width * 0.5,
		(cell.x + cell.y) * tile_height * 0.5
	)


func focus_building(building_type: StringName) -> void:
	if view_mode != &"base":
		set_view_mode(&"base")

	var target: Building
	if building_type == &"hospital":
		target = hospital
	elif building_type == &"safehouse":
		target = safehouse
	elif building_type == &"barracks":
		target = barracks
	else:
		return

	_select_building(target)
	camera.position = target.position + Vector2(0, -40)


func focus_raid_target(target: RaidTarget) -> void:
	if view_mode != &"world":
		set_view_mode(&"world")

	_select_raid_target(target)
	camera.position = target.position + Vector2(0, -40)


func _clear_selection() -> void:
	if selected_target != null and selected_target.has_method("set_selected"):
		selected_target.call("set_selected", false)
	selected_target = null


func _select_building(building: Building) -> void:
	if view_mode != &"base":
		return

	_clear_selection()
	selected_target = building
	building.set_selected(true)
	building_selected.emit(building)


func _select_lot(lot: BuildLot) -> void:
	if view_mode != &"base":
		return

	_clear_selection()
	selected_target = lot
	lot.set_selected(true)
	lot_selected.emit(lot)


func _select_raid_target(target: RaidTarget) -> void:
	if view_mode != &"world":
		return

	_clear_selection()
	selected_target = target
	target.set_selected(true)
	raid_target_selected.emit(target)


func _draw_diamond(center: Vector2, fill: Color) -> void:
	var half_w := tile_width * 0.5
	var half_h := tile_height * 0.5
	var points := PackedVector2Array([
		center + Vector2(0, -half_h),
		center + Vector2(half_w, 0),
		center + Vector2(0, half_h),
		center + Vector2(-half_w, 0)
	])
	draw_colored_polygon(points, fill)
	draw_polyline(
		PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
		_line_color,
		1.5
	)
