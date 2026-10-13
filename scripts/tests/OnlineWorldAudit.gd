extends Node
var failures: PackedStringArray = []
func _ready() -> void: call_deferred("_audit")
func _check(value: bool, reason: String) -> void:
	if not value: failures.append(reason)
func _idle(client: OnlineFactionClient) -> void:
	var deadline := Time.get_ticks_msec()+10000
	while client.is_busy() and Time.get_ticks_msec()<deadline:
		await get_tree().create_timer(0.05).timeout
	_check(not client.is_busy(),"World API timed out")
func _audit() -> void:
	if OS.get_environment("CD_AUDIT_TOKEN").is_empty():
		push_error("Run tools/online_world_probe.py")
		get_tree().quit(1)
		return
	var game = load("res://scenes/core/Main.tscn").instantiate()
	add_child(game)
	game.save_manager.set_process(false)
	game.city_map.camera.edge_pan_enabled = false
	game.online_faction_ui.set_process(false)
	var hud = game.get_node("EstateHUD")
	var nav = hud.world_navigator
	var panel = nav.city_panel
	var client: OnlineFactionClient = panel.client
	client.configure_server(OS.get_environment("CD_AUDIT_URL"),"")
	client.set_session(OS.get_environment("CD_AUDIT_TOKEN"))
	hud._close_panels()
	game.tutorial_ui.hide()
	game.city_map.set_view_mode(&"world")
	await _idle(client)
	_check(panel.state.get("players",[]).size()==9,"World snapshot did not reach the city map")
	var relations := {}
	for player in panel.state.get("players",[]): relations[player.relation]=true
	_check(relations.has("self") and relations.has("ally") and relations.has("other"),"Online map lacks own/allied/other identities")
	_check(game.city_map.territory.active and not game.city_map.raid_targets_layer.visible,"NPC raid targets overlap online estates")
	var cash_before: int = game.economy.cash
	var loot_before: Dictionary = game.loot_inventory.get_save_data().duplicate(true)
	panel.selector.select(3)
	panel._select(3)
	_check(panel.plans.visible and not panel.plans.get_child(2).disabled,"Open City Hall contest cannot be played")
	panel.plans.get_child(2).pressed.emit()
	var receipt: String = panel.receipt
	await _idle(client)
	_check(int(panel._info().get("orders_left",-1))==2 and int(panel.state.get("order_result",{}).get("points",0))==150,"Server did not record the selected tactical order")
	client.world_order("city_hall","intel",receipt)
	await _idle(client)
	_check(int(panel._info().get("orders_left",-1))==2,"Retried order was charged twice")
	_check(game.economy.cash==cash_before and game.loot_inventory.get_save_data()==loot_before,"Online contest changed offline resources")
	for dimensions in [Vector2i(1280,720),Vector2i(390,844),Vector2i(640,360)]:
		get_window().size=dimensions
		for frame in range(8): await get_tree().process_frame
		var bounds: Rect2 = nav.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,nav.size)
		_check(get_viewport().get_visible_rect().encloses(bounds),"City UI clipped at %s"%dimensions)
		_check(bounds.end.y<hud.mission_button.get_global_transform_with_canvas().origin.y,"City UI overlaps chapter bar at %s"%dimensions)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
			get_viewport().get_texture().get_image().save_png("res://build/previews/online_city_%dx%d.png"%[dimensions.x,dimensions.y])
	nav.select_district(0)
	_check(not game.city_map.territory.active and game.city_map.raid_targets_layer.visible,"NPC mode did not restore solo targets")
	nav.show_city(true)
	await _idle(client)
	client.set_session("revoked-test-session")
	client.get_world()
	await _idle(client)
	_check(client.session_token.is_empty(),"Rejected credentials did not restore the Connect action")
	client.clear_session()
	_check(panel.state.is_empty() and game.city_map.territory.world_state.is_empty(),"Disconnected city retained another account's data")
	game.city_map.set_view_mode(&"base")
	_check(not nav.visible and game.city_map.buildings_layer.visible,"City mode broke the estate")
	if failures.is_empty():
		print("[ONLINE WORLD AUDIT] PASS — actual HTTP players, relation colors, landmark order/retry, local economy isolation, responsive layouts, mode switch and session clearing")
		get_tree().quit(0)
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)
