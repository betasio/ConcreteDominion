## Premium vector building silhouettes shared by playable turf structures.
## Decorative only: existing Area2D selection and economy logic remain authoritative.
extends RefCounted

static func draw_facility(canvas: CanvasItem, kind: String, level: int) -> void:
	var gold := Color("#dfb970")
	var edge := Color("#536c80")
	var roof := Color("#435364")
	var shadow := Color("#111b28")
	var front := Color("#273b4e")
	var side := Color("#1a2937")
	var is_hq := kind == "safehouse"
	var height := 72.0 + float(mini(level, 5) - 1) * 8.0 + (32.0 if is_hq else 0.0)
	var half_width := 58.0 if is_hq else 48.0
	var base := Vector2(0, -16)
	var top := base + Vector2(0, -height)
	var slab := PackedVector2Array([
		base + Vector2(0, 38), base + Vector2(92, -8),
		base + Vector2(0, -53), base + Vector2(-92, -8)
	])
	canvas.draw_colored_polygon(slab, Color("#101821"))
	canvas.draw_polyline(PackedVector2Array([slab[0], slab[1], slab[2], slab[3], slab[0]]), gold.darkened(0.2), 2.4, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		top + Vector2(-half_width, 0), top + Vector2(0, 26),
		base + Vector2(0, 26), base + Vector2(-half_width, 0)]), side)
	canvas.draw_colored_polygon(PackedVector2Array([
		top + Vector2(0, 26), top + Vector2(half_width, 0),
		base + Vector2(half_width, 0), base + Vector2(0, 26)]), front)
	canvas.draw_colored_polygon(PackedVector2Array([
		top + Vector2(0, -26), top + Vector2(half_width, 0),
		top + Vector2(0, 26), top + Vector2(-half_width, 0)]), roof)
	canvas.draw_polyline(PackedVector2Array([
		top + Vector2(0, -26), top + Vector2(half_width, 0),
		top + Vector2(0, 26), top + Vector2(-half_width, 0),
		top + Vector2(0, -26)]), edge, 2.0, true)
	for floor_no in range(1, int(height / 20.0)):
		var h := float(floor_no) * 18.0
		for column in range(2):
			var x := 9.0 + float(column) * 19.0
			canvas.draw_line(top + Vector2(x, 22 - h - float(column) * 10),
					top + Vector2(x + 9, 18 - h - float(column) * 10),
					gold if (floor_no + column) % 3 != 0 else Color("#7c9daa"), 3.0)
	match kind:
		"safehouse":
			# Art-deco crown, gold entrance and security gates.
			canvas.draw_line(top + Vector2(-30, -9), top + Vector2(0, -25), gold, 3.0)
			canvas.draw_line(top + Vector2(0, -25), top + Vector2(30, -9), gold, 3.0)
			canvas.draw_colored_polygon(PackedVector2Array([
				base + Vector2(9, 20), base + Vector2(31, 10),
				base + Vector2(31, -14), base + Vector2(9, -2)]), gold.darkened(0.30))
			canvas.draw_line(base + Vector2(-72, 11), base + Vector2(-72, -26), gold, 3.0)
			canvas.draw_line(base + Vector2(72, 11), base + Vector2(72, -26), gold, 3.0)
			canvas.draw_circle(top + Vector2(0, -27), 4.0, gold)
		"hospital":
			canvas.draw_rect(Rect2(top + Vector2(-8, -13), Vector2(16, 24)), Color("#e3ded0"))
			canvas.draw_rect(Rect2(top + Vector2(-15, -6), Vector2(30, 10)), Color("#e3ded0"))
			canvas.draw_rect(Rect2(top + Vector2(-5, -11), Vector2(10, 20)), Color("#bd5b55"))
			canvas.draw_rect(Rect2(top + Vector2(-12, -3), Vector2(24, 5)), Color("#bd5b55"))
		"barracks":
			for offset in [-24.0, 0.0, 24.0]:
				canvas.draw_line(base + Vector2(offset, 16), base + Vector2(offset, -21), edge, 2.0)
			canvas.draw_line(top + Vector2(0, -26), top + Vector2(0, -43), gold, 2.0)
		"Garage":
			canvas.draw_colored_polygon(PackedVector2Array([
				base + Vector2(-29, -9), base + Vector2(-4, 3),
				base + Vector2(-4, -26), base + Vector2(-29, -38)]), Color("#718392"))
			for offset in [0.0, 8.0, 16.0]:
				canvas.draw_line(base + Vector2(-28, -12 - offset), base + Vector2(-5, 0 - offset), shadow, 1.6)
		"Intel Office":
			canvas.draw_line(top + Vector2(0, -27), top + Vector2(0, -58), gold, 2.0)
			canvas.draw_arc(top + Vector2(0, -59), 11.0, PI, TAU, 16, gold, 1.8)
			canvas.draw_arc(top + Vector2(0, -59), 18.0, PI, TAU, 16, Color("#83bfcc"), 1.4)
		"Scrapyard":
			for i in range(3):
				canvas.draw_rect(Rect2(base + Vector2(-67 + i * 17, 8 - i * 6), Vector2(20, 11)), Color("#ab684c"))
			canvas.draw_line(top + Vector2(-20, 0), top + Vector2(-20, -39), Color("#9c7961"), 5.0)
		"Data Hub":
			for i in range(3):
				var p := top + Vector2(-15 + i * 14, -9)
				canvas.draw_rect(Rect2(p, Vector2(10, 7)), Color("#51a9bb"))
			canvas.draw_line(top + Vector2(0, -26), top + Vector2(0, -48), Color("#66b9d1"), 2.0)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(-72, 60),
			kind.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 144, 17, Color("#e9dfcd"))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(-44, 81),
			"LV.%d" % level, HORIZONTAL_ALIGNMENT_CENTER, 88, 15, gold)
