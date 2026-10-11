extends CanvasLayer
## Responsive presentation over the existing game systems and panel actions.
const ICON := preload("res://scripts/ui/EstateIcon.gd")
const GOLD := Color("#e3be73")
const IVORY := Color("#f4ecd9")
var game: Node
var root: Control
var top: Panel
var profile_button: Button
var identity: Label
var resources: Array[Label] = []
var navigation: Array[Button] = []
var left_actions: Array[Button] = []
var right_actions: Array[Button] = []
var mission_button: Button
var mission_title: Label
var mission_detail: Label
var mail_badge: Label
var modal_shade: ColorRect
var inventory: PanelContainer
var inventory_text: Label
var panel_layout: Node
var ui_scale := 1.0
var safe_rect := Rect2()


func setup(game_root: Node) -> void:
	game = game_root
	layer = 1
	set_meta("custom_ui_skin", true)
	root = Control.new()
	root.name = "Root"
	# Distance-field glyphs remain crisp when the responsive canvas scales.
	var font := ThemeDB.fallback_font.duplicate() as FontFile
	font.multichannel_signed_distance_field = true
	root.theme = Theme.new()
	root.theme.default_font = font
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	top = Panel.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _box(Color("#0c1115", 0.97)))
	root.add_child(top)
	profile_button = _button("Profile", "", func(): _open_panel("ProfileUI"))
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	var portrait_path := "res://assets/ui/boss_portrait.png"
	portrait.texture = load(portrait_path) if ResourceLoader.exists(portrait_path) else game.presentation_catalog.get_character_portrait("vex")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_button.add_child(portrait)
	_place(portrait, Rect2(4,4,80,76))
	identity = _label(profile_button, "", 20, GOLD)
	_place(identity, Rect2(0,79,88,25))
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for key in ["Cash", "Gold", "Parts", "Intel"]:
		var value := _label(top, key, 24)
		value.name = key
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		resources.append(value)
	var wordmark := _label(top, "CONCRETE DOMINION", 18, GOLD)
	wordmark.name = "Wordmark"
	var power := _label(top, "", 18)
	power.name = "Power"
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	left_actions.append(_button("Build", "build", _focus_build_site, true))
	left_actions.append(_button("Train", "crew", func(): _hud_action("BarracksShortcut"), true))
	left_actions.append(_button("Clinic", "clinic", func(): _hud_action("HospitalShortcut"), true))
	left_actions.append(_button("Support", "support", func(): _hud_action("AllianceShortcut"), true))
	right_actions.append(_button("Events", "events", func(): _open_panel("EventUI"), true))
	right_actions.append(_button("Rewards", "rewards", func(): _open_panel("RetentionUI"), true))
	right_actions.append(_button("More", "more", _open_more, true))
	for entry in [["World","world"],["Tasks","tasks"],["Inventory","inventory"],["Crew","crew"],["Mail","mail"],["Faction","faction"]]:
		var action: String = entry[0]
		navigation.append(_button(action, entry[1], func(): _navigate(action)))
	mail_badge = _label(navigation[4], "", 20)
	mail_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var badge_style := _box(Color("#a82e2b"), Color("#e9b89a"))
	badge_style.set_corner_radius_all(14)
	mail_badge.add_theme_stylebox_override("normal", badge_style)

	mission_button = _button("Mission", "", func(): _open_panel("ProgressionUI"))
	mission_title = _label(mission_button, "", 24, GOLD)
	mission_detail = _label(mission_button, "", 20)
	mission_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mission_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var arrow := _label(mission_button, "›", 42, GOLD)
	arrow.name = "Arrow"

	modal_shade = ColorRect.new()
	modal_shade.color = Color(0.02,0.04,0.06,0.72)
	modal_shade.visible = false
	modal_shade.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			_close_panels()
	)
	root.add_child(modal_shade)
	_create_inventory()
	panel_layout = preload("res://scripts/ui/EstatePanelLayout.gd").new()
	add_child(panel_layout)
	panel_layout.setup(game, _sync_modals, root.theme)
	game.get_node("SecondaryMenu").list_panel.visibility_changed.connect(_sync_modals)
	_hide_legacy_chrome()
	for source in [game.economy, game.loot_inventory, game.progression, game.player_profile, game.mailbox, game.mission_tracker]:
		source.changed.connect(_refresh)
	game.construction_queue.queue_changed.connect(_refresh)
	game.recruitment_queue.queue_changed.connect(_refresh)
	game.city_map.view_mode_changed.connect(func(_mode): _hide_legacy_chrome(); _refresh())
	game.settings.changed.connect(_apply_text_size)
	get_viewport().size_changed.connect(_layout)
	_refresh()
	_layout()
	_apply_text_size()


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	ui_scale = minf(viewport_size.x, viewport_size.y) / 720.0
	if viewport_size.x > viewport_size.y:
		ui_scale *= 0.72
	# Keep 88-unit rail buttons at least 44 physical pixels on rotated phones.
	ui_scale = maxf(ui_scale, 0.5*viewport_size.x/float(get_window().size.x))
	scale = Vector2.ONE * ui_scale
	root.size = viewport_size / ui_scale
	var inset: Vector4 = game.safe_area_manager._get_viewport_safe_insets() / ui_scale
	safe_rect = Rect2(Vector2(inset.x,inset.y), root.size - Vector2(inset.x+inset.z,inset.y+inset.w))
	var area := safe_rect
	_place(top, Rect2(area.position, Vector2(area.size.x, 112)))
	_place(profile_button, Rect2(area.position + Vector2(10,4), Vector2(88,104)))
	var cell := (area.size.x - 116.0) / 4.0
	for i in range(resources.size()):
		_place(resources[i], Rect2(108+i*cell, 10, cell, 62))
	_place(top.get_node("Wordmark"), Rect2(112,80,area.size.x*0.55,25))
	_place(top.get_node("Power"), Rect2(area.size.x*0.62,80,area.size.x*0.36-12,25))
	for i in range(left_actions.size()):
		_place(left_actions[i], Rect2(area.position + Vector2(12,124+i*102),Vector2(88,96)))
	for i in range(right_actions.size()):
		_place(right_actions[i], Rect2(area.position + Vector2(area.size.x-100,124+i*102),Vector2(88,96)))
	var nav_width := area.size.x / 6.0
	for i in range(navigation.size()):
		_place(navigation[i], Rect2(area.position+Vector2(i*nav_width,area.size.y-100),Vector2(nav_width,100)))
	_place(mail_badge,Rect2(nav_width*0.5+10,4,32,28))
	_place(mission_button,Rect2(area.position+Vector2(12,area.size.y-186),Vector2(area.size.x-24,78)))
	_place(mission_title,Rect2(18,9,mission_button.size.x-66,30))
	_place(mission_detail,Rect2(18,42,mission_button.size.x-66,28))
	_place(mission_button.get_node("Arrow"),Rect2(mission_button.size.x-42,8,32,54))
	_place(modal_shade,Rect2(Vector2.ZERO,root.size))
	_place(inventory,Rect2(area.position+Vector2(24,area.size.y*0.3),Vector2(area.size.x-48,320)))
	for button in navigation+left_actions+right_actions:
		_place(button.get_node("Icon"),Rect2((button.size.x-58)*0.5,5,58,58))
		_place(button.get_node("Caption"),Rect2(0,66,button.size.x,28))
	panel_layout.fit()
	# Give the playable estate the space between the resource and mission bars.
	game.city_map.set_estate_content_rect(Rect2((area.position+Vector2(0,116))*ui_scale,Vector2(area.size.x,area.size.y-306)*ui_scale))


func _refresh() -> void:
	identity.text = "LV. %d" % game.progression.account_level
	resources[0].text = "$ %s\nCASH" % _compact(game.economy.cash)
	resources[1].text = "◆ %s\nGOLD" % _compact(game.economy.gold)
	resources[2].text = "%s\nPARTS" % _compact(game.loot_inventory.get_count("Parts"))
	resources[3].text = "%s\nINTEL" % _compact(game.loot_inventory.get_count("Intel"))
	top.get_node("Power").text = "POWER  %s" % _compact(game.player_profile.get_power_rating())
	var chapter: Dictionary = game.mission_tracker.get_story_chapter_status()
	mission_title.text = "Chapter %d · %s" % [chapter.chapter,chapter.title]
	mission_detail.text = chapter.next_description
	var mail_count: int = game.mailbox.get_unclaimed_count()
	mail_badge.text = str(mail_count)
	mail_badge.visible = mail_count > 0
	navigation[0].get_node("Caption").text = "Estate" if game.city_map.get_view_mode() == &"world" else "World"
	left_actions[0].get_node("Caption").text = "Building" if game.construction_queue.is_busy() else "Build"
	left_actions[1].get_node("Caption").text = "Training" if game.recruitment_queue.is_busy() else "Train"
	mission_button.visible = not game.construction_queue.is_busy()
	if modal_shade.visible:
		game.hud.construction_bar.hide()
	inventory_text.text = "Parts       %s\n\nIntel         %s\n\nContraband   %s" % [game.loot_inventory.get_count("Parts"),game.loot_inventory.get_count("Intel"),game.loot_inventory.get_count("Contraband")]


func _navigate(action: String) -> void:
	match action:
		"World":
			_close_panels()
			game.city_map.set_view_mode(&"world" if game.city_map.get_view_mode() == &"base" else &"base")
		"Tasks": _open_panel("ProgressionUI")
		"Inventory":
			_close_panels()
			inventory.show()
			_sync_modals()
		"Crew": _hud_action("BarracksShortcut")
		"Mail": _open_panel("ProfileUI")
		"Faction": _open_panel("FactionUI")


func _focus_build_site() -> void:
	_close_panels()
	game.city_map.set_view_mode(&"base")
	if game.construction_queue.is_busy():
		var target: Node = game.construction_queue.active_job.target
		if target is BuildLot:
			game.city_map._select_lot(target)
		else:
			game.city_map._select_building(target)
		return
	for lot in [game.city_map.lot_a,game.city_map.lot_b,game.city_map.lot_c,game.city_map.lot_d]:
		if not lot.is_built:
			game.city_map._select_lot(lot)
			return
	game.city_map._select_building(game.city_map.safehouse)


func _hud_action(shortcut: String) -> void:
	_close_panels()
	game.hud.get_node("Root/"+shortcut).pressed.emit()


func _open_panel(owner_name: String) -> void:
	_close_panels()
	game.get_node(owner_name+"/Root/Shortcut").pressed.emit()


func _open_more() -> void:
	_close_panels()
	game.get_node("SecondaryMenu").menu_button.pressed.emit()


func _close_panels() -> void:
	for panel in panel_layout.panels:
		panel.hide()
	inventory.hide()
	game.get_node("SecondaryMenu").list_panel.hide()
	_sync_modals()


func _sync_modals() -> void:
	if modal_shade == null or panel_layout == null:
		return
	var showing: bool = inventory.visible or game.get_node("SecondaryMenu").list_panel.visible
	for panel in panel_layout.panels:
		showing = showing or panel.visible
	modal_shade.visible = showing
	game.hud.construction_bar.visible = game.construction_queue.is_busy() and not showing
	game.tutorial_ui.visible = not showing


func _hide_legacy_chrome() -> void:
	game.hud.layer = 2
	for path in ["TopBar","ViewBar","HospitalShortcut","BarracksShortcut","RaidShortcut","AllianceShortcut"]:
		game.hud.get_node("Root/"+path).hide()
	for owner_name in ["ProgressionUI","RetentionUI"]:
		game.get_node(owner_name+"/Root/Shortcut").hide()
	game.get_node("RetentionUI/Root/TutorialBanner").hide()
	game.get_node("SecondaryMenu").menu_button.hide()


func _apply_text_size() -> void:
	var size_delta := 3 if game.settings.large_text else 0
	for label in resources:
		label.add_theme_font_size_override("font_size",24+size_delta)
	for button in navigation+left_actions+right_actions:
		button.get_node("Caption").add_theme_font_size_override("font_size",22+size_delta)


func _create_inventory() -> void:
	inventory = PanelContainer.new()
	inventory.name = "Inventory"
	inventory.add_theme_stylebox_override("panel",_box(Color("#11191f",0.98)))
	root.add_child(inventory)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	inventory.add_child(column)
	_label(column,"INVENTORY",28,GOLD)
	inventory_text = _label(column,"",24)
	inventory_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 68
	close.add_theme_font_size_override("font_size",24)
	column.add_child(close)
	close.pressed.connect(_close_panels)
	inventory.hide()


func _button(title: String, icon: String, action: Callable, circular: bool = false) -> Button:
	var button := Button.new()
	button.name = title
	button.tooltip_text = title
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new() if circular else _box(Color("#101619",0.96)))
	button.add_theme_stylebox_override("hover",_box(Color("#3b3020",0.95)))
	button.add_theme_stylebox_override("pressed",_box(Color("#614c29",0.96)))
	button.add_theme_stylebox_override("focus",_box(Color(0,0,0,0),Color("#fff0b6")))
	root.add_child(button)
	if not icon.is_empty():
		var glyph := Control.new()
		glyph.set_script(ICON)
		glyph.symbol = icon
		glyph.ring = circular
		glyph.name = "Icon"
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(glyph)
		var caption := _label(button,title,22,IVORY)
		caption.name = "Caption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(action)
	return button


func _label(parent: Node, text: String, font_size: int, color: Color = IVORY) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
	label.add_theme_constant_override("shadow_offset_y",1)
	parent.add_child(label)
	return label


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


func _box(fill: Color, border: Color = GOLD) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border.darkened(0.28)
	box.set_border_width_all(1)
	box.set_content_margin_all(10)
	return box


func _compact(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value)/1000000.0)
	if value >= 10000:
		return "%.1fK" % (float(value)/1000.0)
	return str(value)
