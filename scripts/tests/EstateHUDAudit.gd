extends Node
## Exercise live UI routing and physical touch targets across window sizes.
var failures: PackedStringArray = []

func _ready() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var game = load("res://scenes/core/Main.tscn").instantiate()
	add_child(game)
	game.save_manager.set_process(false)
	game.city_map.camera.edge_pan_enabled = false
	var hud = game.get_node("EstateHUD")
	await get_tree().process_frame
	game.loot_inventory.add_item("Parts", 17)
	_check(hud.resources[1].text.begins_with(str(game.loot_inventory.get_count("Parts"))), "Resource header did not update")
	_check(hud.resource_cells[3].tooltip_text == "Diamonds", "Diamonds must occupy the rightmost resource slot")
	game.mailbox.add_mail("HUD audit", "Test reward", {"cash": 1})
	_check(hud.mail_badge.visible and hud.mail_badge.text == str(game.mailbox.get_unclaimed_count()), "Mail count did not update")
	# Resource counters open the actual balances, and event badges follow claims.
	hud.resource_cells[0].pressed.emit()
	_check(hud.inventory.visible and hud.inventory_text.text.contains(str(game.economy.cash)), "Resource counter did not open live balances")
	hud._close_panels()
	game.event_manager.event_marks = 5
	game.event_manager.changed.emit()
	_check(hud.event_badge.visible, "Earned milestone did not show event badge")
	hud.right_actions[0].pressed.emit()
	await get_tree().process_frame
	_check(game.event_ui.panel.visible, "Events shortcut did not open event panel")
	var milestone_button: Button = game.event_ui.milestones_box.get_child(0)
	_check(milestone_button.get_theme_stylebox("normal") is StyleBoxTexture, "Dynamic event row lost its skin")
	var cash_before: int = game.economy.cash
	milestone_button.pressed.emit()
	await get_tree().process_frame
	_check(game.economy.cash == cash_before+2500 and game.event_manager.claimed_milestones.has(5), "Event row did not claim its actual reward")
	_check(not hud.event_badge.visible, "Claimed milestone left a stale event badge")
	_check(game.event_ui.milestones_box.get_child(0).disabled, "Claimed event reward is still enabled")
	hud._close_panels()
	# Exercise the live production → contract → chosen payout wiring.
	game.retention.daily_claimed = false
	game.retention.daily_progress = {"recruit":3,"raid_win":0,"construction":0,"production":0}
	game.resource_production.parts_bank = 2
	game.resource_production.changed.emit()
	game.retention_ui.daily_choice.select(1)
	game.retention_ui.daily_choice.item_selected.emit(1)
	game.retention_ui.collect_button.pressed.emit()
	_check(game.retention.get_daily_status().production == 2 and not game.retention_ui.daily_button.disabled,"Production contract did not update the live claim button")
	var supplies_before: int = game.loot_inventory.get_count("Parts")
	game.retention_ui.daily_button.pressed.emit()
	_check(game.loot_inventory.get_count("Parts") == supplies_before+3 and game.retention_ui.daily_choice.disabled,"Chosen supply shipment was not paid or locked after claiming")
	game.construction_queue.set_process(false)
	_check(game.construction_queue.start_upgrade(game.city_map.safehouse), "Could not start live construction for HUD audit")
	for dimensions in [Vector2i(1280,720), Vector2i(720,1280), Vector2i(360,640), Vector2i(640,360), Vector2i(1080,2340)]:
		get_window().size = dimensions
		for frame in range(4):
			await get_tree().process_frame
		var viewport := get_viewport().get_visible_rect()
		var camera = game.city_map.camera
		var portrait_zoom: float = camera.zoom.x
		for test_zoom in [camera.min_zoom,portrait_zoom,camera.max_zoom]:
			camera._set_camera_zoom(test_zoom)
			camera.position.y = 9999
			camera._clamp_camera_to_world()
			camera.reset_smoothing()
			camera.force_update_scroll()
			var visible_bottom: float = camera.get_screen_center_position().y+viewport.size.y*0.5/camera.zoom.y
			_check(visible_bottom <= camera.estate_bottom+0.1,"Full viewport exposes water beneath southern road at %s" % dimensions)
		game.city_map.set_view_mode(&"base")
		_check(is_equal_approx(camera.zoom.x,portrait_zoom),"Default zoom changed during boundary clamp")

		var tutorial_panel: Control = game.tutorial_ui.panel
		var tutorial_bounds := tutorial_panel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,tutorial_panel.size)
		_check(viewport.grow(1).encloses(tutorial_bounds), "Tutorial clipped at %s" % dimensions)
		_check(tutorial_bounds.end.y < hud.mission_button.get_global_transform_with_canvas().origin.y, "Tutorial covers navigation")
		var construction: Control = game.hud.construction_bar
		var construction_bounds := construction.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,construction.size)
		_check(construction.visible and not hud.mission_button.visible, "Construction did not replace chapter bar")
		_check(viewport.grow(1).encloses(construction_bounds), "Construction bar clipped")
		_check(construction_bounds.encloses(game.hud.finish_button.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,game.hud.finish_button.size)), "Finish button clipped inside construction bar")
		_check(construction_bounds.end.y <= hud.navigation[0].get_global_transform_with_canvas().origin.y, "Construction bar covers navigation")
		var physical_scale := Vector2(dimensions) / viewport.size
		for button in hud.navigation + hud.left_actions + hud.right_actions:
			var bounds: Rect2 = button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,button.size)
			_check(viewport.grow(1).encloses(bounds), "Chrome outside viewport at %s: %s" % [dimensions,button.name])
			_check(bounds.size.x*physical_scale.x >= 43.9 and bounds.size.y*physical_scale.y >= 43.9, "Touch target smaller than 44px: %s at %s" % [button.name,dimensions])
		for entry in [[1,"ProgressionUI/Root/Panel"],[3,"HUD/Root/BarracksPanel"],[4,"ProfileUI/Root/Panel"],[5,"FactionUI/Root/Panel"],[6,"EventUI/Root/Panel"]]:
			if entry[0] == 6:
				hud.right_actions[0].pressed.emit()
			else:
				hud.navigation[entry[0]].pressed.emit()
			await get_tree().process_frame
			var panel: Control = game.get_node(entry[1])
			_check(game.city_map.camera.controls_blocked, "Open modal does not block camera")
			_check(panel.visible and hud.modal_shade.visible, "Navigation did not open modal: %s" % entry[1])
			var bounds := panel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,panel.size)
			_check(viewport.grow(1).encloses(bounds), "Dialog clipped at %s: %s (%s)" % [dimensions,entry[1],bounds])
			_check(panel.get_node("Margin") is ScrollContainer or panel.get_node_or_null("Margin/Scroll") is ScrollContainer, "Dialog has no accessible scrolling: %s" % entry[1])
			hud._close_panels()
		_check(not game.city_map.camera.controls_blocked, "Camera remains blocked after close")
		_check(not hud.modal_shade.visible, "Closing dialogs left input blocked")
		hud.right_actions[2].pressed.emit()
		await get_tree().process_frame
		var menu: Control = game.get_node("SecondaryMenu").list_panel
		_check(menu.visible and hud.modal_shade.visible, "More menu did not open")
		_check(viewport.grow(1).encloses(menu.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,menu.size)), "More menu clipped")
		var options := menu.get_node("MenuScroll/MenuOptions").get_children()
		_check(options.size() == 9, "Secondary actions were lost")
		options[-1].pressed.emit()
		_check(game.settings_ui.panel.visible and not menu.visible, "Settings route failed")
		hud._close_panels()
		# Send actual GUI input so an invisible overlay cannot silently steal taps.
		var tap_position: Vector2 = hud.navigation[2].get_global_transform_with_canvas() * (hud.navigation[2].size*0.5)
		for down in [true,false]:
			var tap := InputEventScreenTouch.new()
			tap.position = tap_position
			tap.pressed = down
			get_viewport().push_input(tap,true)
			await get_tree().process_frame
		_check(hud.inventory.visible, "Touch tap did not open inventory at %s" % dimensions)

		_check(hud.inventory.visible and hud.inventory_text.text.contains(str(game.loot_inventory.get_count("Parts"))), "Inventory did not display actual loot")
		var outside := InputEventScreenTouch.new()
		outside.position = Vector2(2,2)
		outside.pressed = true
		get_viewport().push_input(outside,true)
		await get_tree().process_frame
		outside.pressed = false
		get_viewport().push_input(outside,true)
		_check(not hud.inventory.visible and not hud.modal_shade.visible, "Outside touch did not dismiss inventory")
		hud.navigation[0].pressed.emit()
		_check(game.city_map.get_view_mode() == &"world", "World navigation failed")
		hud.navigation[0].pressed.emit()
		_check(game.city_map.get_view_mode() == &"base", "Estate return failed")
		hud.left_actions[0].pressed.emit()
		_check(game.hud.selection_panel.visible and game.city_map.selected_target != null, "Build did not select a site")
		hud._close_panels()
	game.construction_queue._process(float(game.construction_queue.active_job["seconds_remaining"])+1.0)
	_check(hud.mission_button.visible and not game.hud.construction_bar.visible, "Chapter bar did not return after construction")
	game.settings.set_large_text(true)
	await get_tree().process_frame
	_check(game.hud.recruit_enforcer_button.get_theme_font_size("font_size") == 25, "Large text did not reach legacy dialogs")
	_check(hud.resources[0].get_theme_font_size("font_size") == 27, "Large text did not reach header")
	game.settings.set_large_text(false)
	var backdrop = game.city_map.get_node("GoldenBayBackdrop")
	game.settings.set_reduced_motion(true)
	var activity = game.city_map.get_node("EstateActivity")
	var activity_before: float = activity.clock
	var clock_before: float = backdrop.animation_time
	var boat_before: Vector2 = backdrop.boat_position(0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(backdrop.animation_time == clock_before, "Reduced Motion does not freeze scenery")
	_check(activity.clock == activity_before, "Reduced Motion does not freeze traffic")
	_check(backdrop.boat_position(0) == boat_before, "Reduced Motion does not freeze boats")
	game.settings.set_reduced_motion(false)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(backdrop.animation_time > clock_before, "Scenery clock did not resume")
	_check(activity.clock > activity_before, "Traffic did not resume")
	_check(backdrop.boat_position(0) != boat_before, "Boats did not resume")
	game.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[ESTATE HUD AUDIT] PASS — live state, navigation, scrollable dialogs and five viewport sizes")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[ESTATE HUD AUDIT] " + failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
