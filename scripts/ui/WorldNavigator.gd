extends PanelContainer
## District previews never spend resources or launch raids. Explicit actions
## delegate to the same world-control and raid systems used by the main panels.
const SKIN := preload("res://scripts/ui/EstateSkin.gd")
var game: Node
var district_ids: Array[String] = []
var selected_id := "downtown_bank"
var selector: OptionButton
var summary: Label
var status: Label
var primary: Button
var intel: Button
var income: Button
var refresh_elapsed := 0.0
var npc_column: VBoxContainer
var city_panel: VBoxContainer
var mode_buttons: Array[Button] = []
var city_selected := true
var content: VBoxContainer
var body_scroll: ScrollContainer
var max_panel_height := 700.0


func setup(game_root: Node) -> void:
	game = game_root
	name = "WorldNavigator"
	size = Vector2(550, 0)
	minimum_size_changed.connect(func(): size.y = get_combined_minimum_size().y)
	add_theme_stylebox_override("panel", SKIN.frame("panel"))
	body_scroll = ScrollContainer.new()
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(body_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(content)
	content.minimum_size_changed.connect(func(): _fit_height.call_deferred())
	var modes := HBoxContainer.new()
	content.add_child(modes)
	for title in ["Faction city","NPC districts"]:
		var mode_button := _button(modes,func(): show_city(title == "Faction city"))
		mode_button.text = title
		mode_buttons.append(mode_button)
	npc_column = VBoxContainer.new()
	var column := npc_column
	column.add_theme_constant_override("separation", 7)
	content.add_child(column)
	var heading := Label.new()
	heading.text = "CITY OPERATIONS  /  NPC DISTRICTS"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("#e3be73"))
	column.add_child(heading)
	selector = OptionButton.new()
	selector.fit_to_longest_item = false
	selector.custom_minimum_size.y = 44
	selector.add_theme_font_size_override("font_size", 22)
	SKIN.style_button(selector)
	column.add_child(selector)
	for target in game.city_map.get_raid_targets():
		var id: String = target.get_target_id()
		district_ids.append(id)
		selector.add_item(String(game.world_control.districts[id].name))
	selector.item_selected.connect(select_district)
	summary = _label(column, 18)
	status = _label(column, 17)
	status.add_theme_color_override("font_color", Color("#becbd1"))
	var actions := HBoxContainer.new()
	column.add_child(actions)
	primary = _button(actions, _primary_action)
	intel = _button(actions, _intel_action)
	income = _button(column, func(): game.world_control.collect_income(); refresh())
	city_panel = preload("res://scripts/ui/CityTerritoryPanel.gd").new()
	content.add_child(city_panel)
	city_panel.setup(game)
	show_city(true, false)
	game.city_map.view_mode_changed.connect(_on_view_changed)
	game.world_control.changed.connect(refresh)
	game.world_control.district_discovered.connect(func(id: String): select_district(district_ids.find(id)))
	game.city_map.turf_overlay.preview_requested.connect(func(id: String): select_district(district_ids.find(id)))
	game.loot_inventory.changed.connect(refresh)
	game.progression.changed.connect(refresh)
	game.city_map.raid_target_selected.connect(func(target: RaidTarget):
		show_city(false,false)
		selected_id = target.get_target_id()
		selector.select(district_ids.find(selected_id))
		refresh()
	)
	visible = game.city_map.get_view_mode() == &"world"
	refresh()


func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Node, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	SKIN.style_button(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _process(delta: float) -> void:
	if not visible:
		return
	refresh_elapsed += delta
	if refresh_elapsed >= 1.0:
		refresh_elapsed = 0.0
		refresh()


func _on_view_changed(mode: StringName) -> void:
	visible = mode == &"world"
	if visible:
		if city_selected: city_panel.activate()
		else: select_district(district_ids.find(selected_id))


func select_district(index: int) -> void:
	if index < 0 or index >= district_ids.size():
		return
	show_city(false,false)
	selected_id = district_ids[index]
	selector.select(index)
	selector.release_focus()
	var target: RaidTarget = game.city_map.get_raid_target_by_id(selected_id)
	game.city_map._focus_camera(target.position)
	game.city_map.turf_overlay.preview_id = selected_id
	game.city_map.turf_overlay.queue_redraw()
	refresh()


func refresh() -> void:
	if game == null or not visible:
		return
	var control: WorldControlManager = game.world_control
	var district: Dictionary = control.districts[selected_id]
	var discovered := control.is_discovered(selected_id)
	var owned := control.is_owned(selected_id)
	var eligible := control.can_discover(selected_id)
	var target: RaidTarget = game.city_map.get_raid_target_by_id(selected_id)
	for index in range(district_ids.size()):
		var id := district_ids[index]
		var tag := "YOUR TURF" if control.is_owned(id) else ("SCOUTED" if control.is_discovered(id) else "LV. %d" % int(control.districts[id].level))
		selector.set_item_text(index, "%s  ·  %s" % [control.districts[id].name, tag])
	summary.text = "%s · Base income $%d/h" % [control.get_owner_label(selected_id) if discovered else "UNSCOUTED", district.cash_per_hour]
	if discovered:
		if owned:
			status.text = "Contested: clear rivals to restore income." if control.is_contested(selected_id) else "Pressure %d%% · Patrols can contest your income." % roundi(control.get_pressure(selected_id) * 100.0)
		else:
			status.text = "Solo NPC target · Win a raid to claim this district."
		if target.cooldown_remaining > 0.0:
			status.text += " Ready in %ds." % ceili(target.cooldown_remaining)
		primary.text = "Manage turf" if owned else "Plan raid"
		primary.disabled = false
	elif not eligible:
		status.text = "Reach account level %d to scout. No resources spent." % district.level
		primary.text = "Unlocks at level %d" % district.level
		primary.disabled = true
	else:
		var seconds := ceili(control.command_scan_remaining)
		status.text = "Scout with a free scan or spend Intel to reveal this rival."
		primary.text = "Free scan" if seconds <= 0 else "Scan %d:%02d" % [seconds / 60, seconds % 60]
		primary.disabled = seconds > 0
	intel.visible = not discovered
	intel.text = "Scout · %d Intel" % district.intel
	intel.disabled = not eligible or game.loot_inventory.get_count("Intel") < int(district.intel)
	income.text = "Collect $%d  ·  Turf earns $%d/h" % [floori(control.production_bank), control.get_income_per_hour()]
	income.disabled = floori(control.production_bank) <= 0
	income.visible = control.get_base_income_per_hour() > 0 or control.production_bank >= 1.0


func _primary_action() -> void:
	var control: WorldControlManager = game.world_control
	if control.is_owned(selected_id):
		game.get_node("EstateHUD")._open_panel("WorldControlUI")
	elif control.is_discovered(selected_id):
		game.get_node("EstateHUD")._close_panels()
		game.city_map.focus_raid_target_by_id(selected_id)
	else:
		control.command_scan(selected_id)
	refresh()


func _intel_action() -> void:
	game.world_control.discover_with_intel(selected_id)
	refresh()


func fit(portrait: bool, available_height: float = 700.0) -> void:
	max_panel_height = available_height
	_fit_height.call_deferred()
	city_panel.fit(portrait)
	for button in [selector, primary, intel, income]+mode_buttons:
		button.custom_minimum_size.y = 88 if portrait else 48
		button.add_theme_font_size_override("font_size", 24 if portrait else 20)
	for label in [summary, status]:
		label.add_theme_font_size_override("font_size", 24 if portrait else 18)


func show_city(enabled: bool, focus: bool = true) -> void:
	city_selected = enabled
	npc_column.visible = not enabled
	city_panel.visible = enabled
	game.city_map.set_territory_mode(enabled)
	for i in range(mode_buttons.size()):
		mode_buttons[i].add_theme_color_override("font_color",Color("#e8c782") if (i==0)==enabled else Color("#acb6bc"))
	if focus:
		if enabled: city_panel.activate()
		else: select_district(district_ids.find(selected_id))


func _fit_height() -> void:
	body_scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, maxf(100.0,max_panel_height-32.0))
	size.y = get_combined_minimum_size().y
