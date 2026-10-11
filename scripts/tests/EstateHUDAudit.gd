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
	_check(hud.resources[2].text.begins_with(str(game.loot_inventory.get_count("Parts"))), "Resource header did not update")
	game.mailbox.add_mail("HUD audit", "Test reward", {"cash": 1})
	_check(hud.mail_badge.visible and hud.mail_badge.text == str(game.mailbox.get_unclaimed_count()), "Mail count did not update")
	game.construction_queue.set_process(false)
	_check(game.construction_queue.start_upgrade(game.city_map.safehouse), "Could not start live construction for HUD audit")
	for dimensions in [Vector2i(1280,720), Vector2i(720,1280), Vector2i(360,640), Vector2i(640,360), Vector2i(1080,2340)]:
		get_window().size = dimensions
		for frame in range(4):
			await get_tree().process_frame
		var viewport := get_viewport().get_visible_rect()
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
		for entry in [[1,"ProgressionUI/Root/Panel"],[3,"HUD/Root/BarracksPanel"],[4,"ProfileUI/Root/Panel"],[5,"FactionUI/Root/Panel"]]:
			hud.navigation[entry[0]].pressed.emit()
			await get_tree().process_frame
			var panel: Control = game.get_node(entry[1])
			_check(panel.visible and hud.modal_shade.visible, "Navigation did not open modal: %s" % entry[1])
			var bounds := panel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,panel.size)
			_check(viewport.grow(1).encloses(bounds), "Dialog clipped at %s: %s (%s)" % [dimensions,entry[1],bounds])
			_check(panel.get_node("Margin") is ScrollContainer or panel.get_node_or_null("Margin/Scroll") is ScrollContainer, "Dialog has no accessible scrolling: %s" % entry[1])
			hud._close_panels()
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
