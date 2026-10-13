extends VBoxContainer
const SKIN := preload("res://scripts/ui/EstateSkin.gd")
var game: Node
var client: OnlineFactionClient
var selector: OptionButton
var detail: Label
var message: Label
var refresh_button: Button
var plans: HBoxContainer
var mayor_row: HBoxContainer
var candidates: OptionButton
var selected_id := ""
var elapsed := 0.0
var updated_at := 0
var receipt := ""
var pending_site := ""
var pending_strategy := ""
var state: Dictionary = {}
var faction_members: Array = []

func setup(owner_game: Node) -> void:
	game = owner_game
	client = game.online_faction_ui.client
	add_theme_constant_override("separation",7)
	var legend := RichTextLabel.new()
	legend.bbcode_enabled = true
	legend.fit_content = true
	legend.scroll_active = false
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.text = "[color=#78d96c]● You[/color]   [color=#64c5ff]● Faction[/color]   [color=#eda65b]● Other[/color]"
	legend.add_theme_font_size_override("normal_font_size",22)
	add_child(legend)
	selector = OptionButton.new()
	selector.fit_to_longest_item = false
	selector.add_item("My turf / city overview")
	for site in game.city_map.territory.SITES:
		selector.add_item("%s · Day %d" % [site.name,site.day])
	selector.item_selected.connect(_select)
	SKIN.style_button(selector)
	add_child(selector)
	detail = _label()
	message = _label()
	message.add_theme_color_override("font_color",Color("#dfbd76"))
	plans = HBoxContainer.new()
	add_child(plans)
	for strategy in ["muscle","convoy","intel"]:
		_button(plans,String(strategy).capitalize(),func(): _order(strategy))
	mayor_row = HBoxContainer.new()
	add_child(mayor_row)
	candidates = OptionButton.new()
	candidates.fit_to_longest_item = false
	candidates.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SKIN.style_button(candidates)
	mayor_row.add_child(candidates)
	_button(mayor_row,"Appoint mayor",_appoint)
	refresh_button = _button(self,"Connect city",_refresh_or_connect)
	game.city_map.territory.site_selected.connect(func(id: String):
		for i in range(3):
			if game.city_map.territory.SITES[i].id == id: selector.select(i+1); _select(i+1)
	)
	game.city_map.territory.estate_selected.connect(func(estate: Dictionary):
		selector.select(0)
		selected_id = ""
		refresh()
		detail.text = "%s\n%s" % [estate.display_name,"Your turf" if estate.relation == "self" else ("Factionmate" if estate.relation == "ally" else "Other faction / independent")]
	)
	client.request_completed.connect(_completed)
	client.connection_failed.connect(_failed)
	client.session_changed.connect(_clear)
	refresh()

func _label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",20)
	add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	SKIN.style_button(button)
	parent.add_child(button)
	return button

func activate() -> void:
	game.city_map.set_territory_mode(true)
	_select(selector.selected)
	if not client.session_token.is_empty() and not client.is_busy(): client.get_world()

func _select(index: int) -> void:
	selector.release_focus()
	selected_id = "" if index == 0 else String(game.city_map.territory.SITES[index-1].id)
	if index == 0: game.city_map.territory.focus_home()
	else: game.city_map._focus_camera(game.city_map.iso_to_screen(game.city_map.territory.SITES[index-1].cell))
	message.text = ""
	refresh()
	reframe.call_deferred()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	if elapsed >= 30.0:
		elapsed = 0.0
		if not client.session_token.is_empty() and not client.is_busy(): client.get_world()

func _clear() -> void:
	state.clear()
	receipt = ""
	faction_members.clear()
	game.city_map.territory.set_snapshot({})
	message.text = ""
	refresh()

func _refresh_or_connect() -> void:
	if client.session_token.is_empty():
		game.get_node("EstateHUD")._open_panel("OnlineFactionUI")
		game.online_faction_ui._select_hub_section("Account")
	else:
		client.get_world()

func _completed(action: String, code: int, data: Dictionary) -> void:
	if action not in ["world","world_order","world_mayor"]: return
	if code >= 200 and code < 300:
		var first_snapshot := state.is_empty()
		state = data.duplicate(true)
		updated_at = Time.get_ticks_msec()
		game.city_map.territory.set_snapshot(state)
		faction_members = state.get("faction_members",[])
		if action == "world_order":
			receipt = ""
			message.text = "Order recorded on server."
		elif action == "world_mayor": message.text = "Mayor appointed."
		refresh()
		if first_snapshot or action != "world": reframe.call_deferred()
	elif code >= 400 and code < 500:
		if action == "world_order": receipt = ""
		if code == 401: game.online_faction_ui._disconnect()
		message.text = String(data.get("error","Request rejected"))
		refresh()
	else: _failed(action,"Could not confirm the result. Retry the same order.")

func _failed(action: String, reason: String) -> void:
	if action in ["world","world_order","world_mayor"]:
		message.text = reason
		refresh()

func _info() -> Dictionary:
	for site in state.get("landmarks",[]):
		if site.id == selected_id: return site
	return {}

func refresh() -> void:
	if game == null: return
	message.visible = not message.text.is_empty()
	var connected := not client.session_token.is_empty()
	refresh_button.text = "Refresh city" if connected else "Connect city"
	plans.visible = false
	mayor_row.visible = false
	if selected_id.is_empty():
		detail.text = "City landmarks open on days 30, 45 and 60.\nFaction contests last 2 hours and return weekly."
		if state.is_empty(): detail.text += "\nConnect to see players and the server schedule."
		else: detail.text = "SECTOR %d · SERVER DAY %d\n%s" % [int(state.sector)+1,1+int((int(state.server_time)-int(state.opened_at))/86400),detail.text]
		return
	var info := _info()
	if info.is_empty():
		detail.text = "Protected landmark · Day %d\nConnect for its server opening time and current owner." % game.city_map.territory.SITES[selector.selected-1].day
		return
	var now: int = int(state.server_time) + int((Time.get_ticks_msec()-updated_at)/1000)
	var remaining := maxi(0,int(info.ends_at if info.phase == "contested" else info.opens_at)-now)
	var clock := "%dd %dh" % [remaining/86400,(remaining%86400)/3600] if remaining>=86400 else "%dh %dm" % [remaining/3600,(remaining%3600)/60]
	detail.text = "%s · %s %s\nOwner: %s" % [String(info.phase).to_upper(),"Ends in" if info.phase == "contested" else "Opens in",clock,info.owner_name]
	if not String(info.mayor).is_empty(): detail.text += " · Mayor: " + String(info.mayor)
	if info.phase == "contested":
		detail.text += "\nGarrison: %s · Orders left: %d/3" % [String(info.defense).capitalize(),info.orders_left]
		var counter: String = {"muscle":"Intel","convoy":"Muscle","intel":"Convoy"}.get(info.defense,"")
		detail.text += "\n%s counters for 150 points. Max 6 commanders/faction." % counter
		if not String(info.blocker).is_empty(): detail.text += "\n"+String(info.blocker)
		plans.visible = true
		for button in plans.get_children():
			button.disabled = not connected or not String(info.blocker).is_empty() or now>=int(info.ends_at) or client.is_busy()
		for rank in info.rankings.slice(0,3): detail.text += "\n[%s] %s · %d" % [rank.tag,rank.name,rank.points]
	mayor_row.visible = bool(info.can_appoint)
	if mayor_row.visible:
		var old := candidates.selected
		candidates.clear()
		for member in faction_members: candidates.add_item(String(member.display_name))
		if candidates.item_count>0: candidates.select(clampi(old,0,candidates.item_count-1))

func _order(strategy: String) -> void:
	if client.is_busy(): return
	if not receipt.is_empty() and (pending_site!=selected_id or pending_strategy!=strategy):
		message.text = "Retry the previous order first to confirm its result."
		return
	if receipt.is_empty():
		receipt = Crypto.new().generate_random_bytes(16).hex_encode()
		pending_site = selected_id
		pending_strategy = strategy
	client.world_order(selected_id,strategy,receipt)
	refresh()

func _appoint() -> void:
	if candidates.selected>=0 and candidates.selected<faction_members.size():
		client.appoint_mayor(String(faction_members[candidates.selected].player_id))

func fit(portrait: bool) -> void:
	for button in [selector,refresh_button,candidates]+plans.get_children()+[mayor_row.get_child(1)]:
		button.custom_minimum_size.y = 88 if portrait else 48
		button.add_theme_font_size_override("font_size",24 if portrait else 20)
	for label in [detail,message]: label.add_theme_font_size_override("font_size",24 if portrait else 18)


func reframe() -> void:
	# Keep the selected architecture in the playable space beside/below the card.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_visible_in_tree() or game.city_map.get_view_mode()!=&"world" or not game.city_map.territory.active: return
	var target := Vector2.ZERO
	if selected_id.is_empty():
		for estate in game.city_map.territory.get_estates():
			if estate.relation == "self": target = game.city_map.territory.estate_position(estate)
	else:
		for site in game.city_map.territory.SITES:
			if site.id == selected_id: target = game.city_map.iso_to_screen(site.cell)
	var hud = game.get_node("EstateHUD")
	var nav = hud.world_navigator
	var rect: Rect2 = nav.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,nav.size)
	var viewport := get_viewport_rect().size
	var lower: float = hud.mission_button.get_global_transform_with_canvas().origin.y-16*hud.ui_scale
	var desired := Vector2(viewport.x/2,(rect.end.y+16*hud.ui_scale+lower)/2)
	if viewport.x>viewport.y:
		desired = Vector2((rect.end.x+viewport.x-92*hud.ui_scale)/2,(108*hud.ui_scale+lower)/2)
	var camera = game.city_map.camera
	game.city_map._focus_camera(target)
	camera.position = target+Vector2(0,-100)-(desired-viewport/2)/camera.zoom.x
	camera._clamp_camera_to_world()
	camera.reset_smoothing()
