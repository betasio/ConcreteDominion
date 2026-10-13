extends Node
var failures: PackedStringArray = []

func _ready() -> void:
	call_deferred("_audit")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _audit() -> void:
	var game = load("res://scenes/core/Main.tscn").instantiate()
	add_child(game)
	game.save_manager.set_process(false)
	game.world_control.set_process(false)
	game.city_map.camera.edge_pan_enabled = false
	var hud = game.get_node("EstateHUD")
	var nav = hud.world_navigator
	var control: WorldControlManager = game.world_control
	await get_tree().process_frame
	_check(not nav.visible, "World navigator leaked into estate")
	game.city_map.set_view_mode(&"world")
	var before: Dictionary = control.get_save_data().duplicate(true)
	var cash_before: int = game.economy.cash
	var loot_before: Dictionary = game.loot_inventory.get_save_data().duplicate(true)
	for index in range(7):
		nav.select_district(index)
	_check(control.get_save_data() == before and game.economy.cash == cash_before and game.loot_inventory.get_save_data() == loot_before and not game.raid_battle.is_active(), "Preview mutated gameplay state")
	_check(nav.primary.disabled and nav.intel.disabled and nav.status.text.contains("level 7"), "Locked district lacks level gate")
	_check(not control.command_scan("industrial_depot") and not control.command_scan("unknown") and control.command_scan_remaining == 0.0, "Rejected scan consumed cooldown or bypassed a level gate")
	var overlay: TurfOverlay = game.city_map.turf_overlay
	var marker: Vector2 = overlay.get_global_transform_with_canvas() * (game.city_map.harbor_bank.position + Vector2(0, -40))
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = marker
	tap.pressed = true
	overlay._unhandled_input(tap)
	tap.pressed = false
	overlay._unhandled_input(tap)
	_check(nav.selected_id == "harbor_bank" and not control.is_discovered("harbor_bank"), "Unscouted map marker did not open a safe preview")
	nav.select_district(0)
	tap.pressed = true
	overlay._unhandled_input(tap)
	var drag := InputEventMouseMotion.new()
	drag.position = marker + Vector2(200, 0)
	overlay._unhandled_input(drag)
	tap.pressed = false
	overlay._unhandled_input(tap)
	_check(nav.selected_id == "downtown_bank", "Dragging opened a district preview")
	game.progression.account_level = 3
	nav.select_district(2)
	game.loot_inventory.items["Intel"] = 0
	nav.refresh()
	_check(not nav.primary.disabled and nav.intel.disabled, "Free scan depends on Intel")
	_check(not control.discover_with_intel("midtown_exchange"), "Scouting allowed unaffordable Intel")
	# Reentrant discovery listeners cannot consume a second free scan.
	var nested_results: Array[bool] = []
	var nested_scan := func(_id: String): nested_results.append(control.command_scan("harbor_bank"))
	control.district_discovered.connect(nested_scan)
	nav.primary.pressed.emit()
	control.district_discovered.disconnect(nested_scan)
	_check(control.is_discovered("midtown_exchange") and not control.is_discovered("harbor_bank"), "Selected free scan revealed the wrong district")
	_check(nested_results == [false] and control.command_scan_remaining > 0.0, "Free scan cooldown was not atomic")
	_check(game.loot_inventory.get_count("Intel") == 0 and not game.raid_battle.is_active(), "Free scan spent Intel or auto-launched a raid")
	game.world_control_ui.victory_close.pressed.emit()
	_check(not game.world_control_ui.panel.visible and not game.world_control_ui.victory_panel.visible and game.city_map.get_view_mode() == &"world", "Enter District did not return to map")
	nav.select_district(1)
	game.loot_inventory.add_item("Intel", 2)
	_check(nav.primary.disabled and not nav.intel.disabled, "Scan cooldown incorrectly blocked Intel discovery")
	nav.intel.pressed.emit()
	_check(control.is_discovered("harbor_bank") and game.loot_inventory.get_count("Intel") == 1, "Intel discovery failed to charge the exact selected cost")
	_check(not control.discover_with_intel("harbor_bank") and game.loot_inventory.get_count("Intel") == 1, "Duplicate scouting charged again")
	hud._close_panels()
	nav.select_district(0)
	nav.primary.pressed.emit()
	_check(game.hud.raid_panel.visible and game.hud.selected_raid_target == game.city_map.downtown_bank and not game.raid_battle.is_active(), "Plan raid failed to open preparation without launching")
	hud._close_panels()
	control.owned["downtown_bank"] = true
	control.production_bank = 42.0
	control.changed.emit()
	cash_before = game.economy.cash
	nav.income.pressed.emit()
	nav.income.pressed.emit()
	_check(game.economy.cash == cash_before + 42 and control.production_bank == 0.0, "Turf income was lost or double-claimed")
	var saved := control.get_save_data()
	control.load_save_data(saved, 0.0)
	_check(control.is_discovered("midtown_exchange") and control.is_discovered("harbor_bank") and control.command_scan_remaining > 0.0, "Discovery/cooldown did not survive save restoration")
	for dimensions in [Vector2i(1280,720), Vector2i(720,1280), Vector2i(360,640), Vector2i(640,360), Vector2i(1080,2340)]:
		get_window().size = dimensions
		nav.select_district(6)
		for frame in range(8):
			await get_tree().process_frame
		var rect: Rect2 = nav.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, nav.size)
		_check(get_viewport().get_visible_rect().encloses(rect), "Navigator clipped at %s" % dimensions)
		_check(rect.end.y < hud.mission_button.get_global_transform_with_canvas().origin.y, "Navigator overlaps chapter bar at %s" % dimensions)
		if dimensions.y > dimensions.x:
			var physical_height: float = nav.primary.size.y * hud.ui_scale * float(dimensions.x) / get_viewport().get_visible_rect().size.x
			_check(physical_height >= 43.9, "Portrait scouting touch target is too small")
			var target_width: float = 136.0 * game.city_map.camera.zoom.x * float(dimensions.x) / get_viewport().get_visible_rect().size.x
			_check(target_width >= 45.0, "Portrait city zoom makes targets unreadably small")
	game.city_map.camera.position = Vector2(99999,99999)
	game.city_map.camera._clamp_camera_to_world()
	_check(game.city_map.camera.position.x < 2000 and game.city_map.camera.position.y < 2000, "World camera can lose the city")
	game.city_map.set_view_mode(&"base")
	_check(not nav.visible and not game.city_map.get_node("DistrictScenery").visible and not game.city_map.get_node("StreetLife").visible, "World scenery leaked into estate")
	if failures.is_empty():
		print("[WORLD MAP AUDIT] PASS — safe previews, level gates, selected scouting, atomic free cooldown, exact costs, raid preparation, income, save restoration and five viewport layouts")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
