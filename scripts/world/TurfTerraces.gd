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
	_draw_stone_to_landscape_transition()
	# Terrain silhouette and illustrated cliff art supply the backdrop.
	# Layer heights create believable vertical faces and deep ground shadows.
	# Rendered underneath the selectable building nodes.
	_draw_platform(city_map.safehouse.position + Vector2(0, 36), 166.0, 78.0, 37.0, true)
	_draw_platform(city_map.hospital.position + Vector2(0, 36), 112.0, 56.0, 24.0, false)
	_draw_platform(city_map.barracks.position + Vector2(0, 36), 112.0, 56.0, 24.0, false)
	for lot in [city_map.lot_a, city_map.lot_b, city_map.lot_c, city_map.lot_d]:
		_draw_platform(lot.position + Vector2(0, 35), 106.0, 52.0, 18.0, false)
	_draw_segmented_retaining_edges()
	_draw_connecting_ramps()
	_draw_architectural_courtyards()
	_draw_terrace_lights()
	# Entrance gate now resides by lower garage access, above the road layer.

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
	# Keep the vertical faces solid and readable at the playable camera zoom.
	# Dense crosshatched joints previously resembled black wire cages under
	# the building pads and competed with the premium illustrated structures.
	var course_shift: Vector2 = down * 0.55
	draw_line(left + course_shift, front + course_shift,
			Color("#66716d", 0.22), 1.2)
	draw_line(front + course_shift, right + course_shift,
			Color("#66716d", 0.22), 1.2)
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
	# Secured entrance: stone columns and wrought-metal gate between them.
	var gate_left: Vector2 = finish + Vector2(-33, -10)
	var gate_right: Vector2 = finish + Vector2(33, -10)
	draw_line(gate_left, gate_right, Color("#b9945e"), 4.0)
	draw_line(gate_left + Vector2(0, -20), gate_right + Vector2(0, -20), Color("#b9945e"), 4.0)
	for index in range(1, 9):
		var t := float(index) / 9.0
		var post := gate_left.lerp(gate_right, t)
		draw_line(post, post + Vector2(0, -20), Color("#36434c"), 3.0)
	draw_circle(finish + Vector2(0, -20), 7.0, Color("#cba968"))
	draw_circle(finish + Vector2(0, -20), 3.0, Color("#27313b"))



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
	# Angular stone strata create a broken rocky face rather than a single
	# flat vertical extrusion. Facets follow the true foreground contour.
	for i in range(3, 8):
		var edge_a: Vector2 = outline[i]
		var edge_b: Vector2 = outline[i + 1]
		for segment in range(4):
			var t0 := float(segment) / 4.0
			var t1 := float(segment + 1) / 4.0
			var p0: Vector2 = edge_a.lerp(edge_b, t0)
			var p1: Vector2 = edge_a.lerp(edge_b, t1)
			var low0 := p0 + Vector2(-7.0 if segment % 2 == 0 else 5.0, 52.0 + float(segment % 3) * 6.0)
			var low1 := p1 + Vector2(9.0 if segment % 2 == 0 else -4.0, 67.0 - float(segment % 3) * 5.0)
			draw_colored_polygon(PackedVector2Array([p0, p1, low1, low0]),
					Color("#354249") if (segment + i) % 3 == 0 else Color("#222d33"))
			draw_line(p0 + Vector2(0, 5), low0, Color("#647079", 0.38), 1.5)
	# Sparse perimeter planting softens the faceted silhouette.
	for i in [3, 4, 6, 7]:
		var foot: Vector2 = outline[i].lerp(outline[i + 1], 0.48)
		draw_circle(foot + Vector2(0, -9), 14.0, Color("#263d35"))
		draw_circle(foot + Vector2(-6, -16), 10.0, Color("#395648"))
		draw_circle(foot + Vector2(9, -18), 7.0, Color("#52715a"))
	draw_colored_polygon(outline, Color("#303d42"))
	# Layered tree screens along the outer boundary. These are planted just
	# inside the perimeter and leave all seven facility footprints open.
	for segment_index in [0, 1, 2, 4, 6, 8, 9]:
		var a: Vector2 = outline[segment_index]
		var b: Vector2 = outline[(segment_index + 1) % outline.size()]
		for tree_index in range(1, 5):
			var t := float(tree_index) / 5.0
			var foot: Vector2 = a.lerp(b, t)
			var inward: Vector2 = (hq - foot).normalized() * 18.0
			var planting: Vector2 = foot + inward
			var crown_height := 17.0 + float((tree_index + segment_index) % 3) * 5.0
			draw_circle(planting + Vector2(3, 4), 14.0, Color("#142a29", 0.55))
			draw_line(planting, planting + Vector2(0, -crown_height), Color("#564e40"), 3.5)
			draw_circle(planting + Vector2(0, -crown_height), 11.0, Color("#2d5042"))
			draw_circle(planting + Vector2(-5, -crown_height - 5), 7.0, Color("#426b52"))
			draw_circle(planting + Vector2(5, -crown_height + 2), 7.0, Color("#345e4a"))
	draw_polyline(PackedVector2Array([
		outline[0], outline[1], outline[2], outline[3],
		outline[4], outline[5], outline[6], outline[7], outline[8], outline[9],
		outline[0]
	]), Color("#56645f", 0.32), 1.5, true)
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


func _draw_terrace_lights() -> void:
	# Low-level warm illumination along the tier transitions and retaining
	# walls; lights are cosmetic and do not intercept building interaction.
	var sites := [
		city_map.safehouse.position + Vector2(0, 42),
		city_map.hospital.position + Vector2(0, 37),
		city_map.barracks.position + Vector2(0, 37),
		city_map.lot_a.position + Vector2(0, 35),
		city_map.lot_b.position + Vector2(0, 35)
	]
	for site in sites:
		var p: Vector2 = site
		for side in [-1.0, 1.0]:
			var position: Vector2 = p + Vector2(side * 78.0, 10.0)
			draw_circle(position, 18.0, Color(0.94, 0.67, 0.28, 0.08))
			draw_line(position, position + Vector2(0, -11), Color("#5a6568"), 3.0)
			draw_circle(position + Vector2(0, -12), 3.5, Color("#f1c57b"))
	# Stair-like masonry steps soften the transition from HQ to middle court.
	var hq_foot: Vector2 = city_map.safehouse.position + Vector2(0, 111)
	for step in range(5):
		var y := float(step) * 7.0
		var half_width := 35.0 + float(step) * 3.5
		draw_line(hq_foot + Vector2(-half_width, y),
				hq_foot + Vector2(half_width, y), Color("#a39b87", 0.56), 2.0)


func _draw_architectural_courtyards() -> void:
	# Recessed planted stone courts soften the transition between premium art
	# and hard-edged supporting platforms, without covering building sprites.
	var hq: Vector2 = city_map.safehouse.position
	var garage: Vector2 = city_map.lot_a.position
	var scrapyard: Vector2 = city_map.lot_c.position
	var data_hub: Vector2 = city_map.lot_d.position
	_draw_court_strip(hq + Vector2(-116, 49), 68.0, true)
	_draw_court_strip(hq + Vector2(116, 49), 68.0, true)
	_draw_court_strip(garage + Vector2(-89, 39), 50.0, false)
	_draw_court_strip(scrapyard + Vector2(-83, 38), 46.0, false)
	_draw_court_strip(data_hub + Vector2(83, 38), 46.0, false)

func _draw_court_strip(center: Vector2, length: float, prestige: bool) -> void:
	var half: float = length * 0.5
	var stone := PackedVector2Array([
		center + Vector2(-half, -9), center + Vector2(half, -9),
		center + Vector2(half + 6, 8), center + Vector2(-half - 6, 8)
	])
	draw_colored_polygon(stone, Color("#1b292c"))
	draw_line(stone[0], stone[1], Color("#b19b72") if prestige else Color("#74837c"), 2.0)
	for i in range(3):
		var x: float = -half + 10.0 + float(i) * (length - 20.0) / 2.0
		var plant: Vector2 = center + Vector2(x, -4)
		draw_circle(plant, 8.0, Color("#213a31"))
		draw_circle(plant + Vector2(-3, -4), 6.0, Color("#4b6c50"))
		draw_circle(plant + Vector2(3, -6), 4.0, Color("#66805b"))
		if prestige and i != 1:
			draw_circle(plant + Vector2(0, 5), 2.0, Color("#ebc17c"))


func _draw_retaining_links() -> void:
	# Broad engineered terraces between the three compound elevations.
	# Draw before ramps so ramp paving stays legible over retaining structures.
	var hq: Vector2 = city_map.safehouse.position
	var mid: Vector2 = (city_map.hospital.position + city_map.barracks.position) * 0.5
	var service: Vector2 = city_map.lot_a.position
	_draw_retaining_bridge(hq + Vector2(0, 90), mid + Vector2(0, 4), 54.0, 28.0)
	_draw_retaining_bridge(mid + Vector2(0, 60), service + Vector2(0, 9), 48.0, 19.0)

func _draw_retaining_bridge(start: Vector2, finish: Vector2, width: float, height: float) -> void:
	var direction: Vector2 = finish - start
	if direction.length_squared() < 1.0:
		return
	var side: Vector2 = direction.normalized().orthogonal() * width * 0.5
	var top := PackedVector2Array([
		start - side, start + side, finish + side, finish - side
	])
	# The road foundation bridges each change in grade, with an exposed
	# stone face and warm trim instead of disconnected horizontal pads.
	var front_a: Vector2 = start + side
	var front_b: Vector2 = finish + side
	draw_colored_polygon(PackedVector2Array([
		front_a, front_b, front_b + Vector2(0, height),
		front_a + Vector2(0, height)
	]), Color("#1c282f"))
	draw_colored_polygon(top, Color("#35434a"))
	draw_line(start - side, finish - side, Color("#988663"), 2.5)
	draw_line(front_a, front_b, Color("#bd9d64", 0.79), 3.0)
	draw_line(front_a + Vector2(0, height), front_b + Vector2(0, height),
			Color("#47555b"), 1.5)
	for i in range(1, 7):
		var t := float(i) / 7.0
		var p: Vector2 = front_a.lerp(front_b, t)
		draw_line(p + Vector2(0, 4), p + Vector2(0, height - 3),
				Color("#7d8785", 0.45), 1.4)


func _draw_tier_edge_bands() -> void:
	# Continuous dressed-stone ledges connect the terrace geometry visually,
	# following live center points rather than the original isometric grid.
	var hq: Vector2 = city_map.safehouse.position
	var middle: Vector2 = (city_map.hospital.position + city_map.barracks.position) * 0.5
	var garage: Vector2 = city_map.lot_a.position
	_draw_ledge(hq + Vector2(-169, 88), hq + Vector2(169, 88), 34.0, true)
	_draw_ledge(city_map.hospital.position + Vector2(-117, 91),
			city_map.barracks.position + Vector2(117, 91), 24.0, false)
	_draw_ledge(city_map.lot_c.position + Vector2(-115, 85),
			city_map.lot_d.position + Vector2(115, 85), 18.0, false)
	# Shorted side returns frame each tier without blocking the road corridors.
	for direction in [-1.0, 1.0]:
		_draw_ledge(middle + Vector2(direction * 200, 50),
				middle + Vector2(direction * 220, 107), 18.0, false)
		_draw_ledge(garage + Vector2(direction * 176, 38),
				garage + Vector2(direction * 188, 103), 16.0, false)

func _draw_ledge(start: Vector2, finish: Vector2, depth: float, prestige: bool) -> void:
	# Underside is stone, top edge is gold for HQ and gray limestone elsewhere.
	var down := Vector2(0, depth)
	draw_colored_polygon(PackedVector2Array([
		start, finish, finish + down, start + down
	]), Color("#1a272d") if prestige else Color("#233037"))
	draw_line(start, finish,
			Color("#bc9e67", 0.8) if prestige else Color("#86908b", 0.70), 3.0)
	draw_line(start + down, finish + down, Color("#586366", 0.55), 2.0)
	for index in range(1, 10):
		var point: Vector2 = start.lerp(finish, float(index) / 10.0)
		draw_line(point + Vector2(0, 5), point + Vector2(0, depth - 3),
				Color("#76807d", 0.38), 1.2)


func _draw_segmented_retaining_edges() -> void:
	# The estate's center is reserved for access roads and the tier ramps.
	# Short masonry shoulders mark each elevation without cutting across it.
	var hq: Vector2 = city_map.safehouse.position
	var clinic: Vector2 = city_map.hospital.position
	var barracks: Vector2 = city_map.barracks.position
	var scrap: Vector2 = city_map.lot_c.position
	var data: Vector2 = city_map.lot_d.position
	for side in [-1.0, 1.0]:
		var hq_start: Vector2 = hq + Vector2(side * 90.0, 91.0)
		var hq_end: Vector2 = hq + Vector2(side * 167.0, 91.0)
		_draw_ledge(hq_start, hq_end, 26.0, true)
	for site in [clinic, barracks]:
		for side in [-1.0, 1.0]:
			var origin: Vector2 = site + Vector2(side * 51.0, 81.0)
			_draw_ledge(origin, origin + Vector2(side * 49.0, 0), 18.0, false)
	for site in [scrap, data]:
		for side in [-1.0, 1.0]:
			var origin: Vector2 = site + Vector2(side * 53.0, 70.0)
			_draw_ledge(origin, origin + Vector2(side * 44.0, 0), 14.0, false)


func _draw_stone_to_landscape_transition() -> void:
	# Short natural shoulders bridge the visible stone podiums to the estate
	# bedrock without crossing buildings or the central entrance route.
	var sites: Array[Vector2] = [
		city_map.safehouse.position,
		city_map.hospital.position,
		city_map.barracks.position,
		city_map.lot_c.position,
		city_map.lot_d.position
	]
	for index in range(sites.size()):
		var center: Vector2 = sites[index]
		var radius: float = 160.0 if index == 0 else 112.0
		for side in [-1.0, 1.0]:
			var outer: Vector2 = center + Vector2(side * (radius + 22.0), 74.0)
			var inner: Vector2 = center + Vector2(side * (radius - 10.0), 50.0)
			# Simple convex wedges are deliberately triangulation-safe.
			var wedge := PackedVector2Array([
				inner + Vector2(0, -15),
				outer + Vector2(0, -19),
				outer + Vector2(0, 19),
				inner + Vector2(0, 12)
			])
			draw_colored_polygon(wedge, Color("#30443e", 0.72))
			draw_line(inner + Vector2(0, 13), outer + Vector2(0, 19),
					Color("#768071", 0.33), 2.0)
