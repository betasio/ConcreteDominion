class_name FactionIdentityCard
extends Control

# Drawn entirely from Godot primitives so cosmetics are crisp on PC and Android.
const EMBLEMS := ["crown", "serpent", "shield", "wolf"]
const BANNERS := ["obsidian", "crimson", "gold", "steel"]
const PALETTES := {
	"obsidian": [Color("#18212e"), Color("#41536b")],
	"crimson": [Color("#501c2d"), Color("#dc5664")],
	"gold": [Color("#594522"), Color("#f1c46d")],
	"steel": [Color("#263c4b"), Color("#8cafc0")]
}

var faction_name := "UNCLAIMED TERRITORY"
var faction_tag := "CD"
var emblem := "shield"
var banner := "obsidian"
var prestige := ""
var season_awards := 0


func set_identity(info: Dictionary, badge: String = "", awards: int = 0) -> void:
	faction_name = String(info.get("name", "UNCLAIMED TERRITORY")).left(32)
	faction_tag = String(info.get("tag", "CD")).left(5)
	emblem = String(info.get("emblem", "shield"))
	banner = String(info.get("banner", "obsidian"))
	prestige = badge if badge in ["CHAMPION", "RUNNER_UP", "PODIUM", "VETERAN"] else ""
	season_awards = maxi(0, awards)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 90.0 or h < 100.0:
		return
	var palette: Array = PALETTES.get(banner, PALETTES["obsidian"])
	var base: Color = palette[0]
	var accent: Color = palette[1]
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0c121c"), true)
	draw_rect(Rect2(3, 3, w - 6, h - 6), accent.darkened(0.55), false, 2)
	draw_rect(Rect2(10, 10, w - 20, h - 20), base, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.58, 11), Vector2(w - 11, 11),
		Vector2(w - 11, h - 12), Vector2(w * 0.27, h - 12)
	]), accent.darkened(0.55))
	for i in range(4):
		draw_line(Vector2(w * 0.6 + i * 20, 18), Vector2(w * 0.4 + i * 20, h - 20), accent.darkened(0.25), 1)
	draw_line(Vector2(17, 20), Vector2(w - 17, 20), accent, 2)
	draw_line(Vector2(17, h - 27), Vector2(w - 17, h - 27), accent, 2)

	var center := Vector2(88, h * 0.43)
	draw_circle(center, 59, Color("#111b29"))
	draw_arc(center, 58, 0, TAU, 64, accent, 3)
	_draw_emblem(center, accent.lightened(0.22))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(162, 56), "[%s]" % faction_tag, HORIZONTAL_ALIGNMENT_LEFT, maxi(80, int(w - 180)), 20, accent.lightened(0.35))
	draw_string(font, Vector2(162, 91), faction_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, maxi(80, int(w - 180)), 25, Color("#f7f0df"))
	draw_string(font, Vector2(162, 120), "ONLINE FACTION IDENTITY", HORIZONTAL_ALIGNMENT_LEFT, maxi(80, int(w - 180)), 13, Color("#b3c4d2"))
	var grade := prestige.replace("_", " ") if not prestige.is_empty() else "NO PRESTIGE YET"
	draw_string(font, Vector2(162, 155), grade, HORIZONTAL_ALIGNMENT_LEFT, maxi(80, int(w - 180)), 18, Color("#f7d793") if not prestige.is_empty() else Color("#9bacbb"))
	draw_string(font, Vector2(162, 177), "%d ARCHIVED SEASON AWARDS" % season_awards, HORIZONTAL_ALIGNMENT_LEFT, maxi(80, int(w - 180)), 13, Color("#c2d3dd"))


func _draw_emblem(c: Vector2, tint: Color) -> void:
	match emblem:
		"crown":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-32, 20), c + Vector2(-38, -19), c + Vector2(-15, -1),
				c + Vector2(0, -34), c + Vector2(15, -1), c + Vector2(38, -19),
				c + Vector2(32, 20)
			]), tint)
			draw_rect(Rect2(c + Vector2(-33, 23), Vector2(66, 9)), tint)
		"serpent":
			draw_arc(c + Vector2(1, -1), 30, 0.25, TAU * 1.65, 48, tint, 9)
			draw_circle(c + Vector2(24, -22), 9, tint)
			draw_circle(c + Vector2(28, -24), 2, Color("#111b29"))
		"wolf":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-34, -30), c + Vector2(-12, -18), c,
				c + Vector2(12, -18), c + Vector2(34, -30),
				c + Vector2(28, 14), c + Vector2(0, 36), c + Vector2(-28, 14)
			]), tint)
			draw_circle(c + Vector2(-12, 5), 4, Color("#111b29"))
			draw_circle(c + Vector2(12, 5), 4, Color("#111b29"))
		_:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -38), c + Vector2(34, -23),
				c + Vector2(29, 13), c + Vector2(0, 36),
				c + Vector2(-29, 13), c + Vector2(-34, -23)
			]), tint)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -22), c + Vector2(19, -13),
				c + Vector2(17, 9), c + Vector2(0, 23),
				c + Vector2(-17, 9), c + Vector2(-19, -13)
			]), Color("#18212e"))
