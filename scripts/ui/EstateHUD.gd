extends CanvasLayer
## Responsive presentation over the existing game systems and panel actions.
const SKIN := preload("res://scripts/ui/EstateSkin.gd")
const ICON := preload("res://scripts/ui/EstateIcon.gd")
const GOLD := Color("#e3be73")
const IVORY := Color("#f4ecd9")
var game: Node
var root: Control
var top: Panel
var profile_button: Button
var identity: Label
var resources: Array[Label] = []
var resource_cells: Array[Button] = []
var event_badge: Label
var rewards_badge: Label
var event_clock := 0.0
var faction_banner: Button
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
	top.add_theme_stylebox_override("panel", SKIN.frame("tab"))
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
	_place(portrait, Rect2(6,6,68,56))
	identity = _label(profile_button, "", 20, GOLD)
	_place(identity, Rect2(0,62,80,22))
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for key in ["Cash", "Gold", "Parts", "Intel"]:
		var slot := Button.new()
		for state in ["normal","hover","pressed"]:
			slot.add_theme_stylebox_override(state,SKIN.frame("resource_"+key.to_lower()))
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.pressed.connect(func(): _navigate("Inventory"))
		slot.tooltip_text = key
		top.add_child(slot)
		resource_cells.append(slot)
		var glyph := TextureRect.new()
		glyph.name = "ResourceIcon"
		glyph.texture = SKIN.icon(key.to_lower())
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(glyph)
		var resource_name := _label(slot,key.to_upper(),13,Color("#aab2b6"))
		resource_name.name = "ResourceName"
		var value := _label(slot, key, 24)
		value.name = key
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		resources.append(value)
	var wordmark := _label(top, "CONCRETE DOMINION", 18, GOLD)
	wordmark.name = "Wordmark"
	var power := _label(top, "", 18)
	power.name = "Power"
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	left_actions.append(_button("Build", "build", _focus_build_site, true))
	left_actions.append(_button("Train", "training", func(): _hud_action("BarracksShortcut"), true))
	left_actions.append(_button("Clinic", "clinic", func(): _hud_action("HospitalShortcut"), true))
	left_actions.append(_button("Support", "support", func(): _hud_action("AllianceShortcut"), true))
	right_actions.append(_button("Events", "events", func(): _open_panel("EventUI"), true))
	right_actions.append(_button("Rewards", "rewards", func(): _open_panel("RetentionUI"), true))
	right_actions.append(_button("More", "more", _open_more, true))
	for index in [0,1]:
		right_actions[index].get_node("Icon").ring = false
	event_badge = _notification_dot(right_actions[0])
	rewards_badge = _notification_dot(right_actions[1])
	for entry in [["World","world"],["Tasks","tasks"],["Inventory","inventory"],["Crew","crew"],["Mail","mail"],["Faction","faction"]]:
		var action: String = entry[0]
		var destination := _button(action, entry[1], func(): _navigate(action))
		destination.add_theme_stylebox_override("normal",SKIN.frame("tab"))
		navigation.append(destination)
	faction_banner = _button("FactionBanner","",func(): _open_panel("FactionUI"))
	faction_banner.add_theme_stylebox_override("normal",SKIN.frame("promo"))
	var faction_art := TextureRect.new()
	faction_art.name = "Art"
	var alliance_art := AtlasTexture.new()
	alliance_art.atlas = load("res://assets/ui/estate_icons.png")
	alliance_art.region = SKIN.REGIONS["faction"]
	alliance_art.filter_clip = true
	faction_art.texture = alliance_art
	faction_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	faction_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	faction_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faction_banner.add_child(faction_art)
	_place(faction_art,Rect2(138,3,106,76))
	var faction_title := _label(faction_banner,"UNDERWORLD\nALLIANCE",18,GOLD)
	_place(faction_title,Rect2(12,9,138,46))
	var faction_hint := _label(faction_banner,"Faction  ›",13)
	_place(faction_hint,Rect2(12,56,126,21))
	mail_badge = _label(navigation[4], "", 20)
	mail_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var badge_style := _box(Color("#a82e2b"), Color("#e9b89a"))
	badge_style.set_corner_radius_all(14)
	mail_badge.add_theme_stylebox_override("normal", badge_style)

	mission_button = _button("Mission", "", func(): _open_panel("ProgressionUI"))
	mission_button.add_theme_stylebox_override("normal",SKIN.frame("chapter"))
	var chapter_icon := _label(mission_button,"!",38,GOLD)
	chapter_icon.name = "ChapterIcon"
	chapter_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	for source in [game.economy, game.loot_inventory, game.progression, game.player_profile, game.mailbox, game.mission_tracker, game.event_manager, game.retention]:
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
	_place(top, Rect2(area.position, Vector2(area.size.x, 92)))
	_place(profile_button, Rect2(area.position + Vector2(10,4), Vector2(80,88)))
	var cell := (area.size.x - 108.0) / 4.0
	for i in range(resources.size()):
		_place(resource_cells[i],Rect2(100+i*cell,7,cell-3,53))
		_place(resource_cells[i].get_node("ResourceIcon"),Rect2(4,8,44,39))
		_place(resource_cells[i].get_node("ResourceName"),Rect2(51,3,cell-58,18))
		_place(resources[i],Rect2(48,20,cell-60,30))
	_place(top.get_node("Wordmark"), Rect2(108,61,area.size.x*0.55,25))
	_place(top.get_node("Power"), Rect2(area.size.x*0.62,61,area.size.x*0.36-12,25))
	for i in range(left_actions.size()):
		_place(left_actions[i], Rect2(area.position + Vector2(10,106+i*102),Vector2(88,96)))
	faction_banner.visible = area.size.y > area.size.x
	_place(faction_banner,Rect2(area.position+Vector2(area.size.x-258,104),Vector2(248,82)))
	var right_top := 198.0 if faction_banner.visible else 106.0
	for i in range(right_actions.size()):
		_place(right_actions[i], Rect2(area.position + Vector2(area.size.x-98,right_top+i*110),Vector2(88,96)))
	var nav_width := area.size.x / 6.0
	for i in range(navigation.size()):
		_place(navigation[i], Rect2(area.position+Vector2(i*nav_width,area.size.y-116),Vector2(nav_width,116)))
	_place(mail_badge,Rect2(nav_width*0.5+22,4,26,26))
	_place(mission_button,Rect2(area.position+Vector2(12,area.size.y-196),Vector2(area.size.x-24,70)))
	_place(mission_title,Rect2(58,7,mission_button.size.x-110,28))
	_place(mission_detail,Rect2(58,35,mission_button.size.x-110,26))
	_place(mission_button.get_node("ChapterIcon"),Rect2(14,10,36,48))
	_place(mission_button.get_node("Arrow"),Rect2(mission_button.size.x-42,8,32,54))
	_place(modal_shade,Rect2(Vector2.ZERO,root.size))
	_place(inventory,Rect2(area.position+Vector2(24,area.size.y*0.3),Vector2(area.size.x-48,360)))
	for button in navigation:
		_place(button.get_node("Icon"),Rect2((button.size.x-78)*0.5,7,78,78))
		_place(button.get_node("Caption"),Rect2(2,84,button.size.x-4,28))
	for button in left_actions+right_actions:
		_place(button.get_node("Icon"),Rect2((button.size.x-74)*0.5,0,74,74))
		_place(button.get_node("Caption"),Rect2(0,72,button.size.x,24))
	panel_layout.fit()
	# Give the playable estate the space between the resource and mission bars.
	game.city_map.set_estate_content_rect(Rect2((area.position+Vector2(0,96))*ui_scale,Vector2(area.size.x,area.size.y-296)*ui_scale))


func _refresh() -> void:
	identity.text = "LV. %d" % game.progression.account_level
	resources[0].text = "%s" % _compact(game.economy.cash)
	resources[1].text = "%s" % _compact(game.economy.gold)
	resources[2].text = "%s" % _compact(game.loot_inventory.get_count("Parts"))
	resources[3].text = "%s" % _compact(game.loot_inventory.get_count("Intel"))
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
	inventory_text.text = "Cash               %s\nGold               %s\nParts              %s\nIntel               %s\nContraband     %s" % [game.economy.cash,game.economy.gold,game.loot_inventory.get_count("Parts"),game.loot_inventory.get_count("Intel"),game.loot_inventory.get_count("Contraband")]
	_refresh_event_status()


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
	game.city_map.camera.set_controls_blocked(showing)
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
		button.get_node("Caption").add_theme_font_size_override("font_size",(20 if button in navigation else 18)+size_delta)


func _create_inventory() -> void:
	inventory = PanelContainer.new()
	inventory.name = "Inventory"
	inventory.add_theme_stylebox_override("panel",SKIN.frame("panel"))
	root.add_child(inventory)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	inventory.add_child(column)
	_label(column,"INVENTORY",28,GOLD)
	inventory_text = _label(column,"",24)
	inventory_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "Close"
	SKIN.style_button(close)
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
	SKIN.style_button(button)
	if circular:
		button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover",_box(Color(0.8,0.65,0.35,0.12),Color(0,0,0,0)))
		button.add_theme_stylebox_override("pressed",_box(Color(0.8,0.65,0.35,0.24),Color(0,0,0,0)))
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
		var caption := _label(button,title,20,GOLD if not circular else IVORY)
		caption.name = "Caption"
		if circular:
			var backing := _box(Color("#101619",0.78),Color(0,0,0,0))
			backing.set_content_margin_all(0)
			backing.set_corner_radius_all(4)
			caption.add_theme_stylebox_override("normal",backing)
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


func _notification_dot(parent: Control) -> Label:
	var dot := _label(parent,"",12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#c32f37")
	style.border_color = Color("#f0b597")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	dot.add_theme_stylebox_override("normal",style)
	_place(dot,Rect2(65,3,16,16))
	return dot


func _process(delta: float) -> void:
	event_clock += delta
	if game != null and event_clock >= 1.0:
		event_clock = 0.0
		_refresh_event_status()


func _refresh_event_status() -> void:
	var claimable := false
	for milestone in game.event_manager.get_milestones():
		claimable = claimable or game.event_manager.can_claim_milestone(int(milestone.marks))
	event_badge.visible = claimable
	var remaining := int(game.event_manager.get_seconds_remaining())
	right_actions[0].tooltip_text = "%s · %dd %dh remaining" % [game.event_manager.event_name,remaining/86400,(remaining%86400)/3600]
	var daily: Dictionary = game.retention.get_daily_status()
	var weekly: Dictionary = game.retention.get_weekly_status()
	rewards_badge.visible = game.retention.can_claim_login_reward() or bool(game.retention.get_comeback_status().available) or (bool(daily.complete) and not bool(daily.claimed)) or (bool(daily.mastery_complete) and not bool(daily.mastery_claimed)) or (bool(weekly.complete) and not bool(weekly.claimed)) or (bool(weekly.mastery_complete) and not bool(weekly.mastery_claimed))
