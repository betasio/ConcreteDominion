class_name TurfGround
extends Node2D
## Decorative landscaping and property pads below the interactive building layer.
## Never handles input and does not change economy, ownership, or save data.
@export var city_map_path: NodePath = NodePath("..")
var city_map: Node2D
var courtyard_texture: Texture2D

func _ready() -> void:
	# The uploaded stairs.png is the illustrated paved courtyard tile.
	var art_path := "res://assets/environment/stairs.png"
	if ResourceLoader.exists(art_path):
		courtyard_texture = load(art_path) as Texture2D
	city_map = get_node_or_null(city_map_path) as Node2D
	if city_map != null:
		city_map.view_mode_changed.connect(func(_mode: StringName) -> void: queue_redraw())
	queue_redraw()

func _draw() -> void:
	if city_map == null or city_map.get_view_mode() != &"base":
		return
	var nodes := [city_map.safehouse, city_map.hospital, city_map.barracks,
			city_map.lot_a, city_map.lot_b, city_map.lot_c, city_map.lot_d]
	_draw_connected_courtyards()
	_draw_compound_routes()
	_draw_landscaping()
	for node in nodes:
		_draw_pad(node.position, node == city_map.safehouse)
	_draw_gate_approach()


func _draw_pad(pos: Vector2, headquarters: bool) -> void:
	var width := 121.0 if headquarters else 94.0
	var depth := 66.0 if headquarters else 52.0
	var points := PackedVector2Array([
		pos + Vector2(0, -depth),
		pos + Vector2(width, -6),
		pos + Vector2(0, depth - 12),
		pos + Vector2(-width, -6)
	])
	draw_colored_polygon(points, Color("#18242d") if headquarters else Color("#222e35"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
			Color("#d5aa63", 0.79) if headquarters else Color("#72818a", 0.6), 2.3, true)
	# Low gold perimeter markers add depth without obscuring selection hitboxes.
	for corner in [points[1], points[3]]:
		draw_circle(corner + Vector2(0, -8), 4.0, Color("#e4bb74", 0.7))

func _draw_bollard(pos: Vector2) -> void:
	draw_line(pos, pos + Vector2(0, -16), Color("#43505a"), 4.0)
	draw_circle(pos + Vector2(0, -16), 3.0, Color("#e8ba72"))


func _draw_compound_routes() -> void:
	# A single hierarchy: HQ boulevard -> middle court -> service yard.
	# Branch spurs attach at the court rather than forming an X interchange.
	var hq: Vector2 = city_map.safehouse.position + Vector2(0, 65)
	var middle: Vector2 = (city_map.hospital.position + city_map.barracks.position) * 0.5 + Vector2(0, 28)
	var lower: Vector2 = city_map.lot_a.position + Vector2(0, 23)
	var routes: Array[PackedVector2Array] = [
		PackedVector2Array([hq, middle, lower]),
		PackedVector2Array([middle + Vector2(-48, 0), city_map.hospital.position + Vector2(0, 34)]),
		PackedVector2Array([middle + Vector2(48, 0), city_map.barracks.position + Vector2(0, 34)]),
		PackedVector2Array([lower + Vector2(-42, 0), city_map.lot_c.position + Vector2(0, 32)]),
		PackedVector2Array([lower + Vector2(42, 0), city_map.lot_d.position + Vector2(0, 32)]),
		PackedVector2Array([middle + Vector2(56, 30), city_map.lot_b.position + Vector2(0, 34)])
	]
	for points in routes:
		draw_polyline(points, Color("#897b68", 0.67), 18.0, true)
		draw_polyline(points, Color("#27343a"), 14.0, true)
		draw_polyline(points, Color("#a4a59d", 0.26), 1.0, true)
		# Restrained seam markings: no broad overlapping intersection lines.
		for index in range(1, points.size()):
			var segment: Vector2 = points[index] - points[index - 1]
			if segment.length() > 120.0:
				var center: Vector2 = points[index - 1].lerp(points[index], 0.5)
				var across: Vector2 = segment.normalized().orthogonal() * 4.5
				draw_line(center - across, center + across, Color("#a8a797", 0.32), 1.1)


func _draw_landscaping() -> void:
	# Landscaping is tied to current facility positions, not old grid cells.
	# Stay outside the central building art and collision footprints.
	var sites := [city_map.safehouse, city_map.hospital, city_map.barracks,
			city_map.lot_a, city_map.lot_b, city_map.lot_c, city_map.lot_d]
	for site in sites:
		var base: Vector2 = site.position
		for side in [-1.0, 1.0]:
			var p := base + Vector2(side * 125.0, 24.0)
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(-16, 3), p + Vector2(0, -5),
				p + Vector2(16, 3), p + Vector2(0, 11)
			]), Color("#263a35"))
			draw_line(p, p + Vector2(0, -18), Color("#625b48"), 3.0)
			draw_circle(p + Vector2(0, -23), 10.0, Color("#355b4b"))
			draw_circle(p + Vector2(-5, -26), 6.0, Color("#60806a"))
			draw_circle(p + Vector2(14, 5), 2.5, Color("#e8c281"))
	# Warm recessed lights align with the central HQ arrival route.
	for offset in [-42.0, 42.0]:
		var light_position: Vector2 = city_map.safehouse.position + Vector2(offset, 110)
		draw_circle(light_position, 14.0, Color(0.93, 0.71, 0.37, 0.12))
		draw_circle(light_position, 3.0, Color("#efc985"))


func _draw_pavement_detail() -> void:
	# Deterministic curb stones, drainage and lane markers.
	# Everything stays below the gameplay structures and is non-interactive.
	for cell in [Vector2i(9, 10), Vector2i(11, 10), Vector2i(12, 10),
			Vector2i(10, 9), Vector2i(10, 11), Vector2i(10, 12),
			Vector2i(12, 13), Vector2i(9, 13)]:
		var center: Vector2 = city_map.iso_to_screen(cell)
		var start: Vector2 = center + Vector2(-19, -10)
		var end: Vector2 = center + Vector2(19, 9)
		draw_line(start, end, Color("#b7a17c", 0.38), 1.8)
		draw_line(start + Vector2(0, 4), end + Vector2(0, 4),
				Color("#141e29", 0.72), 1.8)
	for cell in [Vector2i(8, 10), Vector2i(12, 11), Vector2i(10, 14)]:
		var p: Vector2 = city_map.iso_to_screen(cell)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-21, -7), p + Vector2(3, -18),
			p + Vector2(29, -6), p + Vector2(4, 6)
		]), Color("#18242d"))
		for line_index in range(3):
			var shift: float = float(line_index) * 8.0
			draw_line(p + Vector2(-15 + shift, -7),
					p + Vector2(-8 + shift, -3), Color("#87949b", 0.49), 1.5)
	# HQ driveway inlaid edging highlights the main entrance.
	var a: Vector2 = city_map.iso_to_screen(Vector2i(8, 10))
	var b: Vector2 = city_map.iso_to_screen(Vector2i(10, 10))
	draw_line(a + Vector2(-7, 6), b + Vector2(-7, 18), Color("#ceaa6c", 0.70), 2.2)
	draw_line(a + Vector2(7, 20), b + Vector2(7, 32), Color("#ceaa6c", 0.70), 2.2)


func _draw_gate_approach() -> void:
	# One continuous stone-paved avenue aligns with the HQ and the estate's
	# illustrated entrance, rather than conflicting with the primary roads.
	var lower: Vector2 = city_map.lot_a.position
	var from: Vector2 = lower + Vector2(0, 38)
	var gate: Vector2 = lower + Vector2(0, 124)
	var exit: Vector2 = lower + Vector2(0, 182)
	var route := PackedVector2Array([from, gate, exit])
	draw_polyline(route, Color("#b29a75", 0.80), 50.0, true)
	draw_polyline(route, Color("#313b42"), 43.0, true)
	draw_polyline(route, Color("#637078", 0.42), 1.8, true)
	for step in range(1, 7):
		var p: Vector2 = from.lerp(exit, float(step) / 7.0)
		draw_line(p + Vector2(-15, 0), p + Vector2(15, 0),
				Color("#627179", 0.38), 1.6)
	for side in [-1.0, 1.0]:
		draw_line(from + Vector2(side * 29.0, 0), exit + Vector2(side * 29.0, 0),
				Color("#b49b6c", 0.58), 2.2)
		for dy in [18.0, 92.0, 162.0]:
			_draw_bollard(from + Vector2(side * 36.0, dy))


func _draw_connected_courtyards() -> void:
	# Broad, connected architectural ground planes establish three legible
	# tiers beneath the facilities. Roads, individual foundations and art are
	# drawn above them rather than appearing as separate floating diamonds.
	var hq: Vector2 = city_map.safehouse.position
	var clinic: Vector2 = city_map.hospital.position
	var barracks: Vector2 = city_map.barracks.position
	var garage: Vector2 = city_map.lot_a.position
	var scrap: Vector2 = city_map.lot_c.position
	var data: Vector2 = city_map.lot_d.position
	var middle_center: Vector2 = (clinic + barracks) * 0.5 + Vector2(0, 32)
	var service_center: Vector2 = (scrap + data) * 0.5 + Vector2(0, 34)
	_draw_court_surface(hq + Vector2(0, 32), 214.0, 106.0, true)
	_draw_court_surface(middle_center, 308.0, 100.0, false)
	_draw_court_surface(service_center, 355.0, 104.0, false)
	# Stone approach landings visually join the decks at the road bends.
	_draw_court_surface(garage + Vector2(0, 31), 130.0, 69.0, false)

func _draw_court_surface(center: Vector2, rx: float, ry: float, prestige: bool) -> void:
	var corners := PackedVector2Array([
		center + Vector2(0, -ry),
		center + Vector2(rx, -10),
		center + Vector2(0, ry - 12),
		center + Vector2(-rx, -10)
	])
	draw_colored_polygon(corners, Color("#36454a") if prestige else Color("#304042"))
	# Paint the real illustrated stone-plaza art into each connected tier.
	# Roads and building foundations draw later, keeping all controls visible.
	if courtyard_texture != null:
		var art_size: Vector2 = courtyard_texture.get_size()
		if art_size.x > 0.0:
			var rendered_width: float = rx * (1.02 if prestige else 0.94)
			var rendered_size: Vector2 = art_size * (rendered_width / art_size.x)
			var top_left: Vector2 = center - rendered_size * 0.5 + Vector2(0, -18)
			draw_texture_rect(courtyard_texture, Rect2(top_left, rendered_size), false)

	# Narrow hand-laid stone bands break up the previously untextured slabs.
	# Constrain the geometry to this diamond by interpolating its edges.
	for band in range(1, 6):
		var t := float(band) / 6.0
		var far_left: Vector2 = corners[0].lerp(corners[3], t)
		var far_right: Vector2 = corners[0].lerp(corners[1], t)
		var near_left: Vector2 = corners[3].lerp(corners[2], t)
		var near_right: Vector2 = corners[1].lerp(corners[2], t)
		draw_line(far_left, far_right, Color("#82918a", 0.21), 1.2)
		draw_line(near_left, near_right, Color("#101d22", 0.16), 1.2)
	draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2],
			corners[3], corners[0]]),
			Color("#9e8b65", 0.53) if prestige else Color("#71827b", 0.55), 2.5, true)
	# Quiet seam lines indicate high-end laid stone without a busy tiled grid.
	for step in [-0.5, 0.0, 0.5]:
		var left: Vector2 = corners[3].lerp(corners[0], (step + 1.0) * 0.5)
		var right: Vector2 = corners[2].lerp(corners[1], (step + 1.0) * 0.5)
		draw_line(left, right, Color("#89938c", 0.14), 1.2)
