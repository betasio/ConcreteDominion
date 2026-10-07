extends Node

var failures: PackedStringArray = []


func _ready() -> void:
	_test_event_rollover()
	_test_resource_caps()
	_test_reward_split_conservation()
	_test_malformed_save_clamps()
	_test_dominion_save_clamps()
	_test_dominion_season_rollover()
	_test_faction_season_rollover()
	_finish()


func _test_event_rollover() -> void:
	var event := EventManager.new()
	add_child(event)

	var now := Time.get_unix_time_from_system()
	event.load_save_data({
		"event_name": "Blackout Week",
		"event_started_unix": now - EventManager.EVENT_DURATION_SECONDS - 60.0,
		"event_ends_unix": now - 60.0,
		"event_marks": 45,
		"claimed_milestones": [5, 12, 25, 45]
	})

	if not event.is_active():
		_fail("Expired event did not roll into a new active cycle.")
	if event.event_marks != 0:
		_fail("New event cycle did not reset event marks.")
	if not event.claimed_milestones.is_empty():
		_fail("New event cycle did not reset milestone claims.")
	if event.event_ends_unix <= now:
		_fail("New event cycle has an invalid end timestamp.")

	event.queue_free()


func _test_resource_caps() -> void:
	var scrap := BuildLot.new()
	scrap.building_name = "Scrapyard"
	scrap.is_built = true
	scrap.level = 5

	var data_hub := BuildLot.new()
	data_hub.building_name = "Data Hub"
	data_hub.is_built = true
	data_hub.level = 5

	var loot := LootInventory.new()
	var manager := ResourceProductionManager.new()
	add_child(scrap)
	add_child(data_hub)
	add_child(loot)
	add_child(manager)
	manager.setup(scrap, data_hub, loot)
	manager.load_save_data({}, 24.0 * 60.0 * 60.0)

	var expected_parts := float(manager.get_parts_per_hour()) * 6.0
	var expected_intel := float(manager.get_intel_per_hour()) * 6.0
	if not is_equal_approx(manager.parts_bank, expected_parts):
		_fail("Parts offline production exceeded or missed the six-hour cap.")
	if not is_equal_approx(manager.intel_bank, expected_intel):
		_fail("Intel offline production exceeded or missed the six-hour cap.")

	manager.queue_free()
	scrap.queue_free()
	data_hub.queue_free()
	loot.queue_free()


func _test_reward_split_conservation() -> void:
	var battle := RaidBattle.new()
	var synergy := SynergyRaid.new()
	add_child(synergy)
	add_child(battle)
	battle.synergy = synergy

	for raw_id in ["frontline", "driver", "spy"]:
		var participant_id: String = String(raw_id)
		synergy.join_raid(participant_id, 1, 1.0, &"frontline", participant_id)

	var participants: Array = [
		{"player_id":"frontline"},
		{"player_id":"driver"},
		{"player_id":"spy"}
	]

	var cases: Array = [
		{"pool":10001, "contributions":{"frontline":8000.0,"driver":1200.0,"spy":1440.0}},
		{"pool":7, "contributions":{"frontline":1.0,"driver":1.0,"spy":1.0}},
		{"pool":13, "contributions":{"frontline":9.0,"driver":1.0,"spy":0.1}},
		{"pool":9999, "contributions":{"frontline":0.0,"driver":0.0,"spy":0.0}}
	]

	for raw_case in cases:
		var case_data: Dictionary = raw_case as Dictionary
		var reward_pool: int = int(case_data["pool"])
		var splits: Dictionary = battle._calculate_reward_splits(
			reward_pool,
			case_data["contributions"],
			participants
		)
		var distributed := 0
		for raw_value in splits.values():
			distributed += int(raw_value)
		if distributed != reward_pool:
			_fail("Raid reward split did not conserve pool %d (distributed %d)." % [
				reward_pool,
				distributed
			])
		for raw_value in splits.values():
			if int(raw_value) < 0:
				_fail("Raid reward split generated a negative participant reward.")

	battle.queue_free()
	synergy.queue_free()


func _test_malformed_save_clamps() -> void:
	var economy := PlayerEconomy.new()
	economy.load_save_data({"cash":-500,"gold":-20})
	if economy.cash != 0 or economy.gold != 0:
		_fail("Malformed economy save produced negative balances.")

	var loot := LootInventory.new()
	loot.load_save_data({"Parts":-3,"Intel":-2,"Contraband":-1})
	for raw_key in ["Parts","Intel","Contraband"]:
		var item_key: String = String(raw_key)
		if loot.get_count(item_key) != 0:
			_fail("Malformed loot save produced negative %s." % item_key)

	economy.free()
	loot.free()


func _test_dominion_save_clamps() -> void:
	var endgame := EndgameManager.new()
	add_child(endgame)
	var current_week := floori(float(floori(Time.get_unix_time_from_system() / 86400.0)) / 7.0)
	var current_season := floori(float(current_week) / float(EndgameManager.SEASON_WEEKS))
	endgame.load_save_data({
		"weekly_period": current_week,
		"season_period": current_season,
		"family_operation_wins": 999,
		"boss_rematch_wins": 99,
		"faction_war_wins": 99,
		"dominion_marks": -500,
		"cycles_completed": -2,
		"season_points": -900,
		"featured_wins": -3,
		"scored_operation_wins": 999,
		"claimed_season_tiers": ["SILVER","INVALID","SILVER"],
		"pending_season_tiers": ["GOLD","INVALID","GOLD"],
		"operation_cursor": -999,
		"boss_cursor": 999
	})
	if endgame.family_operation_wins != EndgameManager.FAMILY_OPERATION_GOAL:
		_fail("Dominion Family operation progress was not clamped.")
	if endgame.boss_rematch_wins != EndgameManager.BOSS_REMATCH_GOAL:
		_fail("Dominion boss rematch progress was not clamped.")
	if endgame.faction_war_wins != EndgameManager.FACTION_WAR_GOAL:
		_fail("Dominion Faction War progress was not clamped.")
	if endgame.dominion_marks != 0 or endgame.cycles_completed != 0 or endgame.season_points != 0:
		_fail("Malformed Dominion save produced negative progression.")
	if endgame.featured_wins != 0:
		_fail("Malformed Dominion save produced negative featured wins.")
	if endgame.scored_operation_wins != 5:
		_fail("Dominion weekly seasonal scoring cap was not enforced.")
	if endgame.claimed_season_tiers != ["SILVER"] or endgame.pending_season_tiers != ["GOLD"]:
		_fail("Dominion seasonal tier save sanitization failed.")
	endgame.queue_free()


func _test_dominion_season_rollover() -> void:
	var endgame := EndgameManager.new()
	add_child(endgame)
	var current_week := floori(float(floori(Time.get_unix_time_from_system() / 86400.0)) / 7.0)
	var current_season := floori(float(current_week) / float(EndgameManager.SEASON_WEEKS))
	endgame.load_save_data({
		"weekly_period": current_week - 1,
		"season_period": current_season - 1,
		"season_points": 500,
		"claimed_season_tiers": ["SILVER"],
		"pending_season_tiers": []
	})
	if endgame.season_points != 0:
		_fail("Dominion season rollover did not reset current-season influence.")
	if endgame.pending_season_tiers != ["GOLD"]:
		_fail("Dominion season rollover did not preserve an earned unclaimed tier.")
	endgame.queue_free()


func _test_faction_season_rollover() -> void:
	var faction := FactionManager.new()
	add_child(faction)
	var current_week := floori(float(floori(Time.get_unix_time_from_system() / 86400.0)) / 7.0)
	var current_season := floori(float(current_week) / float(FactionManager.SEASON_WEEKS))
	faction.load_save_data({
		"faction_id":"test",
		"faction_name":"Test Faction",
		"faction_tag":"TEST",
		"season_period":current_season - 1,
		"season_points":600,
		"season_wins":8,
		"faction_territory":{
			"dockyard_exchange":{"owned":true},
			"midtown_signal":{"owned":true},
			"financial_courthouse":{"owned":true}
		}
	})
	if faction.season_points != 0 or faction.season_wins != 0:
		_fail("Faction seasonal competition did not reset on Dominion season rollover.")
	if faction.get_owned_territory_count() != 0:
		_fail("Faction seasonal territory objectives did not reset on season rollover.")
	faction.queue_free()


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[REGRESSION] %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("[REGRESSION] PASS — long-horizon state invariants are intact.")
		get_tree().quit(0)
	else:
		print("[REGRESSION] FAIL — %d issue(s)." % failures.size())
		get_tree().quit(1)
