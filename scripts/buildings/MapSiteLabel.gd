extends RefCounted
## Small, high-contrast map labels shared by the illustrated estate's sites.


static func draw_badge(item: CanvasItem, text: String, top: float, font_size: int = 18) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16.0
	var height := float(font_size) + 10.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#101c22", 0.91)
	box.border_color = Color("#b89861", 0.8)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	item.draw_style_box(box, Rect2(-width * 0.5, top, width, height))
	item.draw_string(font, Vector2(-width * 0.5 + 8.0, top + 5.0 + font.get_ascent(font_size)),
			text, HORIZONTAL_ALIGNMENT_CENTER, width - 16.0, font_size, Color("#f5e5c5"))
