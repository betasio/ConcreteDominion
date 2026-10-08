class_name EnvironmentDepth
extends Node2D
## Cosmetic layered environmental depth; no collision, economy or ownership changes.
@export var city_map_path: NodePath = NodePath("..")
var city_map: Node2D
var shimmer: float = 0.0

func _ready() -> void:
	city_map = get_node_or_null(city_map_path) as Node2D
	if city_map != null:
		city_map.view_mode_changed.connect(func(_mode: StringName) -> void: queue_redraw())
	set_process(true)

func _process(delta: float) -> void:
	shimmer = fmod(shimmer + delta, TAU)
	# Slow breathing highlights without redrawing every frame.
	if int(shimmer * 8.0) != int((shimmer - delta) * 8.0):
		queue_redraw()

func _draw() -> void:
	if city_map == null:
		return
	var world: bool = city_map.get_view_mode() == &"world"
	for y in range(1, 20):
		for x in range(1, 24):
			if x % 5 == 2 or y % 5 == 2:
				continue
			if not world and x >= 6 and x <= 17 and y >= 5 and y <= 16:
				continue
			if (x * 13 + y * 29) % 5 != 0:
				continue
			var p: Vector2 = city_map.iso_to_screen(Vector2i(x, y))
			var variant: int = (x * 7 + y * 11) % 3
			_draw_environment(p, variant, world)
	if not world:
		_draw_turf_fixtures()

func _draw_environment(p: Vector2, variant: int, world: bool) -> void:
	var shadow := PackedVector2Array([
		p + Vector2(-41, 3), p + Vector2(0, -17),
		p + Vector2(49, 5), p + Vector2(5, 27)])
	draw_colored_polygon(shadow, Color(0.02, 0.04, 0.08, 0.35))
	match variant:
		0:
			# Parklet: geometric grass, low hedges and a tree canopy.
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -24), p + Vector2(37, -5),
				p + Vector2(0, 14), p + Vector2(-37, -5)]), Color("#30443f"))
			draw_line(p + Vector2(-20, -6), p + Vector2(19, -6), Color("#769080"), 2.0)
			draw_line(p + Vector2(0, -6), p + Vector2(0, -36), Color("#4b3f36"), 4.0)
			draw_circle(p + Vector2(0, -42), 14, Color("#355b51"))
			draw_circle(p + Vector2(-5, -46), 7, Color("#4d7860", 0.85))
		1:
			# Service garage/loading canopy with industrial strip lighting.
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(-33, -25), p + Vector2(0, -43),
				p + Vector2(35, -25), p + Vector2(0, -7)]), Color("#59636d"))
			draw_line(p + Vector2(-27, -25), p + Vector2(0, -11), Color("#dbb477"), 2.0)
			draw_line(p + Vector2(27, -25), p + Vector2(0, -11), Color("#dbb477"), 2.0)
			draw_line(p + Vector2(-25, -21), p + Vector2(-25, 2), Color("#364653"), 3.0)
		2:
			# Small storefront: distinct awning, window and luminous sign.
			draw_rect(Rect2(p + Vector2(-27, -49), Vector2(54, 36)), Color("#283948"))
			draw_rect(Rect2(p + Vector2(-19, -41), Vector2(38, 15)), Color("#527484"))
			draw_line(p + Vector2(-29, -25), p + Vector2(29, -25),
					Color("#b54f55") if world else Color("#cbac69"), 5.0)
			draw_rect(Rect2(p + Vector2(-21, -55), Vector2(42, 5)),
					Color("#ecc88c", 0.65 + sin(shimmer) * 0.08))
	
func _draw_turf_fixtures() -> void:
	# Perimeter landscaping and decorative parked cars frame the player's compound.
	for cell in [Vector2i(6, 9), Vector2i(16, 8), Vector2i(7, 16)]:
		var p: Vector2 = city_map.iso_to_screen(cell)
		draw_circle(p + Vector2(0, -18), 11, Color("#31574a"))
		draw_circle(p + Vector2(-4, -23), 5, Color("#698d66"))
	for cell in [Vector2i(8, 11), Vector2i(15, 12)]:
		var p: Vector2 = city_map.iso_to_screen(cell)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-17, -3), p + Vector2(2, -12),
			p + Vector2(19, -4), p + Vector2(0, 6)]), Color("#354456"))
		draw_line(p + Vector2(3, -10), p + Vector2(13, -5), Color("#a9c4cf"), 2.0)
