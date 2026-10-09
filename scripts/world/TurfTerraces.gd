class_name TurfTerraces
extends Node2D
## Layered retaining platforms: entirely visual, with gameplay nodes unchanged.
## Uses live positions of the city buildings to avoid visual/selection drift.
@export var city_map_path: NodePath = NodePath("..")
var city_map: Node2D

func _ready() -> void:
	city_map = get_node_or_null(city_map_path) as Node2D
	if city_map != null:
		city_map.view_mode_changed.connect(func(_mode: StringName) -> void: queue_redraw())
	queue_redraw()

func _draw() -> void:
	if city_map == null or city_map.get_view_mode() != &"base":
		return
	_draw_estate_landform()
	# Layer heights create believable vertical faces and deep ground shadows.
	# Rendered underneath the selectable building nodes.
	_draw_platform(city_map.safehouse.position + Vector2(0, 36), 166.0, 78.0, 37.0, true)
	_draw_platform(city_map.hospital.position + Vector2(0, 36), 112.0, 56.0, 24.0, false)
	_draw_platform(city_map.barracks.position + Vector2(0, 36), 112.0, 56.0, 24.0, false)
	for lot in [city_map.lot_a, city_map.lot_b, city_map.lot_c, city_map.lot_d]:
		_draw_platform(lot.position + Vector2(0, 35), 106.0, 52.0, 18.0, false)
	_draw_connecting_ramps()
	_draw_entry()

func _draw_platform(center: Vector2, rx: float, ry: float, depth: float, hero: bool) -> void:
	var back := center + Vector2(0, -ry)
	var right := center + Vector2(rx, -8)
	var front := center + Vector2(0, ry - 10)
	var left := center + Vector2(-rx, -8)
	var down := Vector2(0, depth)
	var top := PackedVector2Array([back, right, front, left])
	var east_face := PackedVector2Array([right, front, front + down, right + down])
	var west_face := PackedVector2Array([front, left, left + down, front + down])
	draw_colored_polygon(east_face, Color("#293239") if hero else Color("#202a32"))
	draw_colored_polygon(west_face, Color("#131d27") if hero else Color("#172029"))
	draw_colored_polygon(top, Color("#394650") if hero else Color("#303a42"))
	draw_polyline(PackedVector2Array([left, back, right, front]), Color("#bd995b") if hero else Color("#7d8790"), 3.0, true)
	draw_line(front, front + down, Color("#67727a"), 2.0)
	for i in range(1, 6):
		var t := float(i) / 6.0
		var brick := front.lerp(left, t)
		draw_line(brick + Vector2(0, 4), brick + Vector2(0, depth - 3), Color("#53606a", 0.45), 1.0)
	# Ground lights accentuate the HQ terrace without hiding its sprite.
	if hero:
		for p in [left, right]:
			draw_circle(p + Vector2(0, -4), 7.0, Color(0.96, 0.70, 0.31, 0.16))
			draw_circle(p + Vector2(0, -4), 2.5, Color("#f8d18b"))

func _draw_entry() -> void:
	var hq: Vector2 = city_map.safehouse.position
	var start := hq + Vector2(0, 128)
	var finish := hq + Vector2(0, 225)
	draw_line(start + Vector2(-26, 0), finish + Vector2(-38, 0), Color("#6e6250"), 7.0)
	draw_line(start + Vector2(26, 0), finish + Vector2(38, 0), Color("#6e6250"), 7.0)
	draw_line(start, finish, Color("#303a43"), 49.0)
	draw_line(start, finish, Color("#b99b6b", 0.7), 1.5)
	for x in [-39.0, 39.0]:
		var pillar := finish + Vector2(x, -9)
		draw_rect(Rect2(pillar + Vector2(-6, -19), Vector2(12, 25)), Color("#45515d"))
		draw_circle(pillar + Vector2(0, -22), 4.0, Color("#eabf75"))


func _draw_estate_landform() -> void:
	# A single irregular estate silhouette conceals the repetitive city grid
	# behind the playable compound. Terrace pads and buildings render above it.
	var hq: Vector2 = city_map.safehouse.position
	var west: Vector2 = city_map.lot_c.position
	var east: Vector2 = city_map.lot_d.position
	var south: Vector2 = city_map.lot_a.position
	var outline := PackedVector2Array([
		hq + Vector2(-140, -150),
		hq + Vector2(95, -172),
		hq + Vector2(250, -84),
		east + Vector2(170, -85),
		east + Vector2(195, 80),
		south + Vector2(170, 154),
		south + Vector2(-80, 192),
		west + Vector2(-175, 85),
		west + Vector2(-190, -40),
		hq + Vector2(-255, -95)
	])
	var depth := Vector2(0, 80)
	# Cliff faces are visible at the foreground and sides.
	for i in range(3, 8):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[i + 1]
		draw_colored_polygon(PackedVector2Array([a, b, b + depth, a + depth]),
				Color("#171e26") if i % 2 == 0 else Color("#27313a"))
		draw_line(a, b, Color("#69777d", 0.58), 3.0)
		for step in range(1, 5):
			var p := a.lerp(b, float(step) / 5.0)
			draw_line(p + Vector2(0, 7), p + Vector2(0, 65),
					Color("#46515b", 0.30), 1.5)
	draw_colored_polygon(outline, Color("#303d42"))
	draw_polyline(PackedVector2Array([
		outline[0], outline[1], outline[2], outline[3],
		outline[4], outline[5], outline[6], outline[7], outline[8], outline[9],
		outline[0]
	]), Color("#a28c62", 0.64), 3.0, true)
	# Broad, understated landscaped bands give the estate a planted backdrop.
	for x in [-155.0, -105.0, 110.0, 165.0]:
		var base: Vector2 = hq + Vector2(x, 20)
		draw_circle(base, 30.0, Color("#263d37", 0.66))
		draw_circle(base + Vector2(8, -12), 17.0, Color("#3d5a4b", 0.58))


func _draw_connecting_ramps() -> void:
	# Narrow stone ramps connect the prestige terrace, shared court and
	# lower service route without changing gameplay navigation or selection.
	var hq: Vector2 = city_map.safehouse.position
	var middle: Vector2 = (city_map.hospital.position + city_map.barracks.position) * 0.5
	var garage: Vector2 = city_map.lot_a.position
	_draw_ramp(hq + Vector2(0, 72), middle + Vector2(0, 20), 25.0)
	_draw_ramp(middle + Vector2(0, 42), garage + Vector2(0, 27), 21.0)

func _draw_ramp(start: Vector2, finish: Vector2, width: float) -> void:
	var delta := finish - start
	if delta.length() < 1.0:
		return
	var side := delta.normalized().orthogonal() * width * 0.5
	var corners := PackedVector2Array([
		start - side, start + side, finish + side, finish - side
	])
	draw_colored_polygon(corners, Color("#414951"))
	draw_line(start - side, finish - side, Color("#c7a46c"), 3.0)
	draw_line(start + side, finish + side, Color("#c7a46c"), 3.0)
	for step in range(1, 7):
		var p: Vector2 = start.lerp(finish, float(step) / 7.0)
		draw_line(p - side * 0.78, p + side * 0.78, Color("#72808a", 0.40), 1.5)
