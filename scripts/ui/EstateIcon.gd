extends Control
## Resolution-independent navigation symbols; no external icon font required.
var symbol := "world"
var ring := false
const GOLD := Color("#e3be73")


func _draw() -> void:
	var unit := minf(size.x, size.y) / 64.0
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * unit)
	if ring:
		draw_circle(Vector2.ZERO, 30, Color("#101716", 0.96))
		draw_arc(Vector2.ZERO, 30, 0, TAU, 48, GOLD, 1.3, true)
	match symbol:
		"build":
			draw_line(Vector2(-14, 17), Vector2(11, -13), GOLD, 6, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-2,-20), Vector2(5,-26), Vector2(23,-11), Vector2(16,-4)]), GOLD)
		"crew", "support":
			for x in [-15, 15]:
				draw_circle(Vector2(x, -8), 6, GOLD.darkened(0.2))
				draw_rect(Rect2(x - 7, 1, 14, 18), GOLD.darkened(0.2))
			draw_circle(Vector2(0, -13), 8, GOLD)
			draw_rect(Rect2(-9, -2, 18, 24), GOLD)
		"clinic":
			draw_rect(Rect2(-6, -22, 12, 44), GOLD)
			draw_rect(Rect2(-22, -6, 44, 12), GOLD)
		"mail":
			draw_rect(Rect2(-23,-16,46,32), GOLD, false, 2.5)
			_line([Vector2(-22,-15), Vector2(0,3), Vector2(22,-15)])
			_line([Vector2(-22,15), Vector2(-7,1)])
			_line([Vector2(22,15), Vector2(7,1)])
		"tasks":
			draw_rect(Rect2(-17,-23,34,46), GOLD, false, 2.5)
			for y in [-12, 1, 14]:
				_line([Vector2(-11,y), Vector2(-8,y+3), Vector2(-3,y-4)])
				draw_line(Vector2(3,y), Vector2(11,y), GOLD, 2, true)
		"inventory", "store":
			_line([Vector2(-23,-10), Vector2(0,-22), Vector2(23,-10), Vector2(23,16), Vector2(0,27), Vector2(-23,16), Vector2(-23,-10), Vector2(0,2), Vector2(23,-10)])
			draw_line(Vector2(0,2), Vector2(0,27), GOLD, 2.5, true)
		"faction":
			_line([Vector2(-21,-23), Vector2(21,-23), Vector2(19,7), Vector2(0,27), Vector2(-19,7), Vector2(-21,-23)])
			_line([Vector2(-11,3), Vector2(0,-9), Vector2(11,3)])
			_line([Vector2(-11,13), Vector2(0,1), Vector2(11,13)])
		"events":
			draw_rect(Rect2(-21,-19,42,42), GOLD, false, 2.5)
			draw_line(Vector2(-21,-7),Vector2(21,-7),GOLD,2.5,true)
			for x in [-11,11]:
				draw_line(Vector2(x,-25),Vector2(x,-14),GOLD,3,true)
			for y in [2,13]:
				for x in [-11,0,11]:
					draw_circle(Vector2(x,y),2.0,GOLD)
		"rewards":
			draw_rect(Rect2(-21,-3,42,25), GOLD, false, 2.5)
			draw_rect(Rect2(-25,-10,50,9), GOLD, false, 2.5)
			draw_line(Vector2(0,-10), Vector2(0,23), GOLD, 3, true)
			draw_arc(Vector2(-7,-16), 8, 0, TAU, 24, GOLD, 2, true)
			draw_arc(Vector2(7,-16), 8, 0, TAU, 24, GOLD, 2, true)
		"more":
			for x in [-16, 0, 16]:
				draw_circle(Vector2(x,0), 4, GOLD)
		_:
			_line([Vector2(-24,-18),Vector2(-8,-25),Vector2(8,-18),Vector2(24,-25),Vector2(24,18),Vector2(8,25),Vector2(-8,18),Vector2(-24,25),Vector2(-24,-18)])
			draw_line(Vector2(-8,-25),Vector2(-8,18),GOLD,2,true)
			draw_line(Vector2(8,-18),Vector2(8,25),GOLD,2,true)


func _line(points: Array) -> void:
	draw_polyline(PackedVector2Array(points), GOLD, 2.5, true)
