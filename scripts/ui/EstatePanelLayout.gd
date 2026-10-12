extends Node
## Keep legacy panel names and signals while presenting readable, scrollable dialogs.
const SKIN := preload("res://scripts/ui/EstateSkin.gd")
var game: Node
var panels: Array[PanelContainer] = []
var construction_bar: PanelContainer
var tutorial_panel: PanelContainer


func setup(game_root: Node, visibility_callback: Callable, chrome_theme: Theme) -> void:
	game = game_root
	# Dynamic rows created after setup inherit the same readable button skin.
	chrome_theme.set_stylebox("normal","Button",SKIN.frame("button"))
	chrome_theme.set_stylebox("hover","Button",SKIN.frame("button_gold"))
	chrome_theme.set_stylebox("pressed","Button",SKIN.frame("button_gold"))
	var disabled := SKIN.frame("reward").duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(0.85,0.85,0.85,1.0)
	chrome_theme.set_stylebox("disabled","Button",disabled)
	chrome_theme.set_color("font_color","Button",Color("#f4e6c7"))
	chrome_theme.set_color("font_disabled_color","Button",Color("#a7b0bc"))
	chrome_theme.set_color("font_hover_color","Button",Color("#17100a"))
	chrome_theme.set_color("font_pressed_color","Button",Color("#17100a"))
	chrome_theme.set_font_size("font_size","Button",22 + (3 if game.settings.large_text else 0))
	for owner_ui in game.get_children():
		if not owner_ui is CanvasLayer or owner_ui.name in ["EstateHUD","TutorialUI","SecondaryMenu"]:
			continue
		var ui_root := owner_ui.get_node_or_null("Root")
		if ui_root == null:
			continue
		ui_root.theme = chrome_theme
		# Dialogs must draw above the estate chrome even on legacy layer 1.
		owner_ui.layer = maxi(2,owner_ui.layer)
		for child in ui_root.get_children():
			if not child is PanelContainer or child.name == "TutorialBanner":
				continue
			if child.name == "ConstructionBar":
				construction_bar = child
				_make_scrollable(child)
				_style_content(child)
				child.get_node("Margin/HBox/FinishNow").custom_minimum_size.x = 190
				continue
			panels.append(child)
			child.visibility_changed.connect(visibility_callback)
			_make_scrollable(child)
			_style_content(child)
	game.tutorial_ui.get_node("Root").theme = chrome_theme
	game.get_node("SecondaryMenu/LauncherRoot").theme = chrome_theme
	tutorial_panel = game.tutorial_ui.panel
	_make_scrollable(tutorial_panel)
	game.tutorial_ui.title.clip_text = false
	_style_content(tutorial_panel)
	var menu: PanelContainer = game.get_node("SecondaryMenu").list_panel
	_style_content(menu)
	menu.get_node("MenuScroll/MenuOptions").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.settings.changed.connect(_refresh_text)
	get_viewport().size_changed.connect(func(): fit.call_deferred())
	fit()


func _make_scrollable(panel: PanelContainer) -> void:
	var margin := panel.get_node_or_null("Margin") as MarginContainer
	if margin == null or margin.get_node_or_null("Scroll") != null:
		return
	# Replace only the wrapper. Root/Panel/Margin/VBox/... and every button
	# instance remain valid, including scripts that resolve those paths later.
	margin.name = "RetiredMargin"
	var scroll := ScrollContainer.new()
	scroll.name = "Margin"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	for content in margin.get_children():
		content.reparent(scroll)
		if content is Control:
			content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.queue_free()


func _style_content(node: Node) -> void:
	var extra := 3 if game.settings.large_text else 0
	if node is PanelContainer:
		node.set_meta("custom_ui_skin",true)
		node.add_theme_stylebox_override("panel",SKIN.frame("event" if node.has_meta("estate_hero") else "panel"))
	if node is Label:
		node.add_theme_font_size_override("font_size",(26 if node.name == "Title" else 22)+extra)
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if node.name == "Title":
			node.add_theme_color_override("font_color",Color("#e3be73"))
	elif node is Button:
		SKIN.style_button(node)
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y,68)
		node.add_theme_font_size_override("font_size",22+extra)
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif node is LineEdit:
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y,64)
		node.add_theme_font_size_override("font_size",22+extra)
	for child in node.get_children():
		_style_content(child)


func fit() -> void:
	if game == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var inset: Vector4 = game.safe_area_manager._get_viewport_safe_insets()
	var available := viewport_size - Vector2(inset.x+inset.z,inset.y+inset.w)
	var portrait := available.y > available.x
	var factor := available.x / 560.0 if portrait else available.y / 720.0
	factor = maxf(factor, (44.0/68.0)*viewport_size.x/float(get_window().size.x))
	var width := 524.0 if portrait else minf(820.0,available.x/factor-48.0)
	var height := available.y/factor - 64.0
	for panel in panels:
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.scale = Vector2.ONE * factor
		panel.size = Vector2(width,height)
		panel.position = Vector2(inset.x,inset.y) + (available-panel.size*factor)*0.5 - panel.get_parent().position
	var menu: PanelContainer = game.get_node("SecondaryMenu").list_panel
	_fit_dialog(menu, Vector2(minf(width,420),height),factor,available,inset)
	if tutorial_panel != null:
		tutorial_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		tutorial_panel.scale = Vector2.ONE*factor
		tutorial_panel.size = Vector2(width,minf(300.0,(available.y-320.0*game.get_node("EstateHUD").ui_scale)/factor))
		var chrome: float = game.get_node("EstateHUD").ui_scale
		tutorial_panel.position = Vector2(inset.x+(available.x-width*factor)*0.5,viewport_size.y-inset.w-206*chrome-tutorial_panel.size.y*factor)-tutorial_panel.get_parent().position
	if construction_bar != null:
		construction_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		construction_bar.scale = Vector2.ONE * factor
		construction_bar.size = Vector2(width,116)
		var chrome_scale: float = game.get_node("EstateHUD").ui_scale
		construction_bar.position = Vector2(inset.x+(available.x-width*factor)*0.5,viewport_size.y-inset.w-124*chrome_scale-116*factor)-construction_bar.get_parent().position


func _fit_dialog(panel: Control, dimensions: Vector2, factor: float, available: Vector2, inset: Vector4) -> void:
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.scale = Vector2.ONE*factor
	panel.size = dimensions
	panel.position = Vector2(inset.x,inset.y)+(available-panel.size*factor)*0.5-panel.get_parent().position


func _refresh_text() -> void:
	game.get_node("EstateHUD").root.theme.set_font_size("font_size","Button",22 + (3 if game.settings.large_text else 0))
	for panel in panels:
		_style_content(panel)
	_style_content(tutorial_panel)
	_style_content(game.get_node("SecondaryMenu").list_panel)
	if construction_bar != null:
		_style_content(construction_bar)
	fit.call_deferred()
