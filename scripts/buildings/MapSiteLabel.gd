extends RefCounted
## Small, high-contrast map labels shared by the illustrated estate's sites.

static var badge_font: FontFile

static func draw_badge(item: CanvasItem, text: String, top: float, font_size: int = 18) -> void:
	if badge_font == null:
		badge_font = ThemeDB.fallback_font.duplicate() as FontFile
		badge_font.multichannel_signed_distance_field = true
	var font := badge_font
	var lines := text.split(" · ",true,1)
	var title := lines[0]
	var width := font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+24.0
	if lines.size() > 1:
		width = maxf(width,font.get_string_size(lines[1],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size-2).x+24.0)
	var height := float(font_size)+14.0+(float(font_size) if lines.size() > 1 else 0.0)
	var box := preload("res://scripts/ui/EstateSkin.gd").frame("label")
	item.draw_style_box(box,Rect2(-width*0.5,top,width,height))
	item.draw_string(font,Vector2(-width*0.5+12,top+6+font.get_ascent(font_size)),
			title,HORIZONTAL_ALIGNMENT_CENTER,width-24,font_size,Color("#f5efdf"))
	if lines.size() > 1:
		item.draw_string(font,Vector2(-width*0.5+12,top+font_size+7+font.get_ascent(font_size-2)),
				lines[1],HORIZONTAL_ALIGNMENT_CENTER,width-24,font_size-2,Color("#e5be71"))
