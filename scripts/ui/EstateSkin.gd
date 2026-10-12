extends RefCounted
## Shared high-resolution atlas and nine-slice chrome; gameplay text stays live.
const ROOT := "res://assets/ui/"
const REGIONS := {
	"world":Rect2(0,22,341,314), "tasks":Rect2(345,20,279,321),
	"inventory":Rect2(637,30,308,312), "crew":Rect2(949,18,302,321),
	"mail":Rect2(8,370,326,254), "faction":Rect2(333,348,311,275),
	"build":Rect2(646,342,299,285), "research":Rect2(982,343,263,289),
	"support":Rect2(0,660,344,250), "clinic":Rect2(348,638,276,280),
	"rewards":Rect2(634,636,309,297), "events":Rect2(949,638,300,288),
	"cash":Rect2(10,956,321,270), "gold":Rect2(336,945,301,284),
	"parts":Rect2(635,946,310,272), "intel":Rect2(947,925,306,313)
}
const ITEM_REGIONS := {
	"cash":Rect2(18,148,378,315), "gold":Rect2(400,153,378,305),
	"parts":Rect2(779,142,360,314), "intel":Rect2(1149,146,380,311),
	"events":Rect2(22,541,376,377), "rewards":Rect2(410,539,363,379),
	"training":Rect2(769,583,379,311), "faction":Rect2(1182,525,328,402)
}
static var icons: Dictionary = {}
static var frames: Dictionary = {}

static func icon(symbol: String) -> Texture2D:
	if not REGIONS.has(symbol) and not ITEM_REGIONS.has(symbol):
		return null
	if not icons.has(symbol):
		var texture := AtlasTexture.new()
		texture.atlas = load(ROOT+("estate_items.png" if ITEM_REGIONS.has(symbol) else "estate_icons.png"))
		texture.region = ITEM_REGIONS[symbol] if ITEM_REGIONS.has(symbol) else REGIONS[symbol]
		texture.filter_clip = true
		icons[symbol] = texture
	return icons[symbol]

static func frame(kind: String = "panel") -> StyleBoxTexture:
	if not frames.has(kind):
		var box := StyleBoxTexture.new()
		box.texture = load(ROOT+"estate_"+("bar" if kind == "label" else kind)+".svg")
		box.set_texture_margin_all(7 if kind == "label" or kind.begins_with("resource_") or kind in ["promo","event","chapter","reward"] else 22)
		box.set_content_margin_all(16 if kind == "panel" else 10)
		frames[kind] = box
	return frames[kind]

static func style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal",frame("button"))
	button.add_theme_stylebox_override("hover",frame("button_gold"))
	button.add_theme_stylebox_override("pressed",frame("button_gold"))
	var disabled := frame("reward").duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(0.85,0.85,0.85,1.0)
	button.add_theme_stylebox_override("disabled",disabled)
	button.add_theme_color_override("font_color",Color("#f4e6c7"))
	button.add_theme_color_override("font_disabled_color",Color("#a7b0bc"))
	button.add_theme_color_override("font_hover_color",Color("#17100a"))
	button.add_theme_color_override("font_pressed_color",Color("#17100a"))

	if button.has_meta("event_reward"):
		var state: String = button.get_meta("event_reward")
		button.add_theme_stylebox_override("normal",frame("button_gold" if state == "claimable" else "reward"))
		button.add_theme_stylebox_override("disabled",frame("reward"))
		button.add_theme_color_override("font_disabled_color",Color("#91b69f" if state == "claimed" else "#b5c0cc"))
		button.add_theme_color_override("icon_disabled_color",Color.WHITE)
		if state == "claimable":
			button.add_theme_color_override("font_color",Color("#21170e"))
