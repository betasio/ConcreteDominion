extends Node
## Real physics footprints, construction transactions, save IDs and terrain fallback.
var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_audit")


func _audit() -> void:
	ProjectSettings.set_setting("concrete_dominion/preview_illustrated_terrain", true)
	ProjectSettings.set_setting("concrete_dominion/enable_3d_safehouse", false)
	var packed := load("res://scenes/world/CityMap.tscn") as PackedScene
	var city = packed.instantiate()
	add_child(city)
	city.camera.edge_pan_enabled = false
	var economy := PlayerEconomy.new()
	economy.cash = 1000000
	add_child(economy)
	var queue := ConstructionQueue.new()
	add_child(queue)
	queue.setup(economy)
	queue.set_process(false)
	await get_tree().physics_frame
	await get_tree().process_frame

	var terrain :=  city.get_node("IllustratedEstateTerrain/TerrainIllustration") as Sprite2D
	var layout = preload("res://scripts/world/IllustratedEstateLayout.gd")
	_check(terrain.texture != null, "Continuous estate artwork missing")
	var approach := city.get_node("IllustratedEstateTerrain/SouthApproach") as Sprite2D
	var road_end := approach.position.y + approach.texture.get_height() * approach.scale.y * 0.5
	_check(is_equal_approx(road_end, layout.ROAD_END), "Camera road boundary drifted from approach artwork")
	_check(city.camera.estate_bottom < road_end, "Camera can expose the end of the road")
	_check(terrain.to_global(layout.PAD_CENTERS[&"BuildLotD"]-layout.TEXTURE_SIZE*0.5).distance_to(city.lot_d.global_position) < 0.1,
			"Data Hub interaction no longer aligns with the estate pad")
	for core in [city.safehouse,city.hospital,city.barracks]:
		_check(core.position.distance_to(layout.artwork_to_world(layout.PAD_CENTERS[core.name])) < 0.1,"Core ground anchor drifted")
		var shape: ConvexPolygonShape2D = core.get_node("CollisionShape2D").shape
		_check(shape.points.size() == 4, "Core selection does not follow its courtyard")
		var query := PhysicsPointQueryParameters2D.new()
		query.position = core.global_position
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hits: Array = city.get_world_2d().direct_space_state.intersect_point(query)
		hits = hits.filter(func(hit: Dictionary) -> bool: return hit["collider"].is_visible_in_tree())
		_check(hits.size() == 1 and hits[0]["collider"] == core,"Core footprint overlaps another site")
	var ids := ["lot_garage", "lot_intel", "lot_scrapyard", "lot_datahub"]
	for id in ids:
		var lot := city.get_persistent_target(id) as BuildLot
		_check(lot != null and city.get_target_id(lot) == id, "Stable save identity lost: %s" % id)
		if lot == null:
			continue
		var original_position := lot.position
		_check_pad_hit(city, lot)
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		lot._on_input_event(get_viewport(), touch, 0)
		_check(city.selected_target == lot and lot.is_selected, "Touch selection failed: %s" % id)
		var cash_before := economy.cash
		_check(queue.start_lot_build(lot), "Construction could not start: %s" % id)
		_check(economy.cash == cash_before - lot.build_cash_cost, "Construction cash charged incorrectly")
		_check(lot.is_constructing and not lot.is_built, "Empty construction state lost")
		_check_pad_hit(city, lot)
		var pending := queue.get_save_data()
		_check(pending.get("target_id") == id, "Pending construction save target changed")
		queue.load_save_data(pending, 1.0, city)
		_check(queue.is_target_active(lot), "Pending construction did not restore")
		queue._process(float(queue.active_job["seconds_remaining"]) + 1.0)
		_check(lot.is_built and lot.level == 1 and not lot.is_constructing, "Construction completion failed")
		_check(queue.start_facility_upgrade(lot), "Facility upgrade could not start")
		_check(lot.is_built and lot.is_constructing and lot.pending_level == 2, "Upgrade state lost")
		queue._process(float(queue.active_job["seconds_remaining"]) + 1.0)
		_check(lot.level == 2 and not lot.is_constructing, "Upgrade completion failed")
		_check(lot.position == original_position, "Construction moved the pad")
		_check_pad_hit(city, lot)

	var saved: Dictionary = city.get_save_data()
	for id in ids:
		city.get_persistent_target(id).restore_progress(false)
	city.load_save_data(saved)
	for id in ids:
		var lot := city.get_persistent_target(id) as BuildLot
		_check(lot.is_built and lot.level == 2, "Built facility did not survive save restoration")
	city.set_view_mode(&"world")
	_check(not terrain.is_visible_in_tree(), "Terrain leaks into the raid map")
	city.set_view_mode(&"base")
	_check(terrain.is_visible_in_tree(), "Terrain missing after returning to the estate")

	ProjectSettings.set_setting("concrete_dominion/preview_illustrated_terrain", false)
	var fallback = packed.instantiate()
	add_child(fallback)
	_check(not fallback.lot_a.use_illustrated_pad, "Legacy terrain uses illustrated plot drawing")
	_check(not fallback.get_node("IllustratedEstateTerrain").visible, "Legacy terrain still draws the illustration")
	_check(fallback.get_node("TurfGround").visible, "Legacy ground fallback is hidden")
	_check(fallback.lot_a.position != city.lot_a.position, "Legacy grid positions were lost")
	if failures.is_empty():
		print("[ESTATE AUDIT] PASS — four pad hitboxes, touch routing, construction/upgrade transactions, saves, continuous terrain and fallback")
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _check_pad_hit(city: Node2D, lot: BuildLot) -> void:
	# Independent samples measured inside the painted courtyards. A rotated
	# plot does not contain the tips of the former axis-aligned diamond.
	var samples := {
		&"BuildLotA": [Vector2(775,270),Vector2(735,266),Vector2(815,270),Vector2(781,247)],
		&"BuildLotB": [Vector2(346,406),Vector2(291,407),Vector2(414,415),Vector2(320,388)],
		&"BuildLotC": [Vector2(831,697),Vector2(770,680),Vector2(901,723)],
		&"BuildLotD": [Vector2(815,418),Vector2(755,408),Vector2(870,419),Vector2(831,391)],
	}
	var layout = preload("res://scripts/world/IllustratedEstateLayout.gd")
	for pixel in samples[lot.name]:
		var offset: Vector2 = layout.artwork_to_world(pixel) - lot.position
		var query := PhysicsPointQueryParameters2D.new()
		query.position = lot.to_global(offset)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hits: Array = city.get_world_2d().direct_space_state.intersect_point(query)
		# Physics queries include hidden raid targets; viewport input picking
		# excludes them in base view. Compare the visible interactive sites.
		hits = hits.filter(func(hit: Dictionary) -> bool: return hit["collider"].is_visible_in_tree())
		_check(hits.size() == 1 and hits[0]["collider"] == lot,
				"Pad is unclickable or overlaps another facility: %s / %s" % [lot.name, offset])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("[ESTATE AUDIT] %s" % message)
