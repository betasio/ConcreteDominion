extends Node
var failures: PackedStringArray = []

func _ready() -> void:
	var game = load("res://scenes/core/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.set_process(false)
	game.save_manager.set_process(false)
	var skins: StoreManager = game.store_manager
	game.city_map.safehouse.restore_progress(1)
	_check(skins.appearance()==0,"HQ 1 must use the villa")
	_check(not skins.equip_skin("vanguard") and not skins.equip_skin("crimson"),"Locked skins equipped")
	skins.load_save_data({"selected_skin":"crimson","owned":["crimson"],"skin_entitlements":["crimson"]})
	_check(skins.active_skin()=="default" and skins.attack_multiplier()==1.0,"Save forged premium ownership")
	game.city_map.safehouse.restore_progress(3)
	_check(skins.appearance()==1,"HQ 3 must use the mansion")
	var target = game.city_map.get_raid_targets()[0]
	var baseline: Dictionary = game.raid_battle.preview_battle(target,1,1)
	_check(not baseline.is_empty(),"Missing actual raid preview")
	_check(skins.equip_skin("vanguard"),"Earned attack skin unavailable")
	var boosted: Dictionary = game.raid_battle.preview_battle(target,1,1)
	_check(is_equal_approx(float(boosted.get("damage",0)),float(baseline.get("damage",-1))*1.1),"Skin did not increase real raid damage by 10%")
	game.city_map.safehouse.restore_progress(5)
	skins.equip_skin("default")
	_check(skins.appearance()==2,"HQ 5 must use the palace")
	skins.equip_skin("founder")
	_check(skins.attack_multiplier()==1.0 and skins.production_multiplier()==1.1,"Skin bonuses stacked")
	game.city_map.lot_d.restore_progress(true,1)
	game.city_map.lot_c.restore_progress(true,1)
	game.resource_production.load_save_data({},3600)
	_check(is_equal_approx(game.resource_production.intel_bank,1.1),"Fractional offline production bonus lost")
	game.resource_production.collect()
	_check(is_equal_approx(game.resource_production.intel_bank,0.1),"Collect discarded fractional production")
	game.resource_production.load_save_data({},86400)
	_check(is_equal_approx(game.resource_production.intel_bank,6.6),"Offline production exceeded six-hour boosted cap")
	skins.equip_skin("default")
	game.resource_production._process(1.0)
	_check(is_equal_approx(game.resource_production.intel_bank,6.6),"Changing skins destroyed stored resources")
	skins.equip_skin("founder")
	var districts = game.city_map.get_node("EstateDistricts")
	var lot = districts.plots[0]
	districts.configure(lot,"cash",true)
	lot.restore_progress(true,1)
	_check(is_equal_approx(districts.get_cash_per_hour(),1320),"Cash production missing skin multiplier")
	game.save_manager.save_game()
	skins.equip_skin("default")
	game.save_manager.load_game()
	_check(skins.active_skin()=="founder","Equipped earned skin not restored")
	_check(not skins.purchases_enabled(),"Unverified checkout enabled")
	# Authenticated entitlements unlock only until revoked/disconnected; no local save ownership.
	var client: OnlineFactionClient = game.online_faction_ui.client
	client.request_completed.emit("world",200,{"sector":0,"server_time":1,"opened_at":1,"skin_entitlements":["crimson"]})
	_check(skins.equip_skin("crimson") and skins.appearance()==3,"Verified skin not available")
	client.request_completed.emit("world",200,{"sector":0,"server_time":1,"opened_at":1,"skin_entitlements":[]})
	_check(skins.active_skin()=="default","Revoked premium skin stayed active")
	client.request_completed.emit("world",200,{"sector":0,"server_time":1,"opened_at":1,"skin_entitlements":["emerald"]})
	skins.equip_skin("emerald")
	client.session_changed.emit()
	_check(skins.production_multiplier()==1.0,"Disconnected account retained premium benefit")
	var territory = game.city_map.territory
	_check(territory.cells.size()==24,"City lost player slots")
	for cell in territory.cells:
		for site in territory.SITES:
			_check(not Rect2(game.city_map.iso_to_screen(cell)+Vector2(-145,-220),Vector2(290,285)).intersects(territory.site_rect(site)),"Player estate overlaps landmark reserve")
	if DisplayServer.get_name() != "headless":
		game.get_node("EstateHUD")._close_panels()
		game.city_map.set_view_mode(&"world")
		game.get_node("EstateHUD").world_navigator.show_city(true)
		skins.equip_skin("default")
		get_window().size = Vector2i(390,844)
		for frame in range(10): await get_tree().process_frame
		game.get_node("EstateHUD")._open_panel("StoreUI")
		for frame in range(10): await get_tree().process_frame
		var bounds: Rect2 = game.store_ui.panel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,game.store_ui.panel.size)
		_check(get_viewport().get_visible_rect().encloses(bounds),"Turf collection clipped on portrait")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/previews/turf_collection_390x844.png")
	game.queue_free()
	await get_tree().process_frame
	if failures.is_empty(): print("[TURF SKIN AUDIT] PASS — HQ tiers, real damage, exclusive bonuses, fractional production, saves and ownership")
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
