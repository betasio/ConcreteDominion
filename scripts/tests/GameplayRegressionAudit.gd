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
	_test_operation_report_grade_rules()
	_test_battle_report_history_invariants()
	_test_faction_war_strategy_counters()
	_test_faction_war_preparation_snapshot()
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
		"pending_season_prestige": {"GOLD":"STEEL GOLD","INVALID":"BAD"},
		"prestige_badges": ["VELVET SILVER","VELVET SILVER",""],
		"equipped_prestige_badge": "NOT OWNED",
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
	if String(endgame.pending_season_prestige.get("GOLD", "")) != "STEEL GOLD":
		_fail("Dominion delayed prestige mapping was not restored.")
	if endgame.prestige_badges != ["VELVET SILVER"]:
		_fail("Dominion prestige badge save sanitization failed.")
	if endgame.equipped_prestige_badge != "VELVET SILVER":
		_fail("Dominion equipped prestige badge fallback failed.")
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
	if String(endgame.pending_season_prestige.get("GOLD", "")).is_empty():
		_fail("Dominion season rollover did not preserve the prior season prestige identity.")
	if String(endgame.last_season_result.get("season_name", "")).is_empty():
		_fail("Dominion season rollover did not preserve the prior season result summary.")
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


func _test_operation_report_grade_rules() -> void:
	var report := OperationResultUI.new()
	if report._grade_from_ratio(1.40, true) != "S":
		_fail("Operation report S-grade threshold is invalid.")
	if report._grade_from_ratio(1.16, true) != "A":
		_fail("Operation report A-grade threshold is invalid.")
	if report._grade_from_ratio(1.01, true) != "B":
		_fail("Operation report B-grade threshold is invalid.")
	if report._grade_from_ratio(0.90, false) != "C":
		_fail("Operation report close-defeat grade is invalid.")
	if report._grade_from_ratio(0.50, false) != "D":
		_fail("Operation report defeat grade is invalid.")
	report.free()


func _test_battle_report_history_invariants() -> void:
	var manager := BattleReportManager.new()
	add_child(manager)
	var saved_reports: Array = []
	for i in range(30):
		saved_reports.append({
			"source":"raid" if i % 2 == 0 else "family_operation",
			"timestamp":-50 if i == 0 else i,
			"target_name":"Target %d" % i,
			"victory":i % 3 != 0,
			"advice":"x".repeat(500)
		})
	saved_reports.append({"source":"invalid"})
	manager.load_save_data({"reports":saved_reports})
	if manager.get_report_count() != BattleReportManager.MAX_REPORTS:
		_fail("Battle report history cap was not enforced on load.")
	var first := manager.get_report(0)
	if float(first.get("timestamp", -1.0)) < 0.0:
		_fail("Battle report timestamp sanitization failed.")
	if String(first.get("advice", "")).length() > 300:
		_fail("Battle report tactical advice sanitization failed.")
	var close_loss := {
		"victory":false,
		"damage":90.0,
		"target_hp":100.0,
		"weakness_matched":false,
		"weakness_role":"Driver"
	}
	if not manager._build_raid_advice(close_loss).contains("Close loss"):
		_fail("Battle report close-loss advice is missing.")
	manager.queue_free()


func _test_faction_war_strategy_counters() -> void:
	var faction := FactionManager.new()
	add_child(faction)
	faction.faction_id = "test"
	faction.faction_name = "Test"
	faction.faction_tag = "TEST"
	faction.members = [
		{"id":"local_player","name":"You","role":FactionManager.ROLE_LEADER,"power":10000,"contribution":50,"online":true}
	]
	faction.active_war = {
		"opponent_id":"prototype_test",
		"opponent_name":"Test Rival",
		"opponent_rating":500,
		"seconds_remaining":1000.0,
		"our_score":0,
		"their_score":0,
		"attacks_remaining":3,
		"status":"active",
		"result":"",
		"reward_tier":"",
		"attack_cursor":0,
		"attack_history":[],
		"last_attack":{}
	}
	var defense := faction.get_current_war_defense()
	var strategy_id := ""
	for candidate in ["muscle", "convoy", "intel"]:
		var strategy: Dictionary = FactionManager.WAR_STRATEGIES[candidate]
		if String(strategy.get("counter", "")) == defense:
			strategy_id = candidate
			break
	if strategy_id.is_empty():
		_fail("Faction War defense has no valid counter strategy.")
	else:
		var result := faction.perform_war_attack(strategy_id)
		if not bool(result.get("countered", false)):
			_fail("Faction War counter strategy did not register.")
		if int(faction.active_war.get("attacks_remaining", 3)) != 2:
			_fail("Faction War attack did not consume exactly one attack.")
		if (faction.active_war.get("attack_history", []) as Array).size() != 1:
			_fail("Faction War attack history was not recorded.")
	faction.queue_free()


func _test_faction_war_preparation_snapshot() -> void:
	var faction := FactionManager.new()
	add_child(faction)
	faction.faction_id = "test"
	faction.faction_name = "Test"
	faction.faction_tag = "TEST"
	faction.faction_level = 4
	faction.members = [
		{"id":"boss","name":"Boss","role":FactionManager.ROLE_LEADER,"power":12000,"contribution":500,"online":true},
		{"id":"local_player","name":"You","role":FactionManager.ROLE_UNDERBOSS,"power":7000,"contribution":150,"online":true}
	]
	faction.research["raid_coordination"] = 3
	faction.war_preparation = {
		"captain_id":"boss",
		"defense":"watchful",
		"doctrine":"aggressive"
	}
	var readiness := faction.get_war_readiness_score()
	if readiness < 70 or readiness > 100:
		_fail("Faction War readiness does not reflect captain/research preparation.")
	if not faction.start_prototype_war():
		_fail("Prepared Faction War could not start.")
	else:
		if String(faction.active_war.get("captain_id", "")) != "boss":
			_fail("Faction War captain was not snapshotted at war start.")
		if String(faction.active_war.get("defense_stance", "")) != "watchful":
			_fail("Faction War defense stance was not snapshotted.")
		if String(faction.active_war.get("doctrine", "")) != "aggressive":
			_fail("Faction War doctrine was not snapshotted.")
		var before_doctrine := String(faction.active_war.get("doctrine", ""))
		if faction.cycle_war_doctrine():
			_fail("Faction War doctrine changed after war start.")
		if String(faction.active_war.get("doctrine", "")) != before_doctrine:
			_fail("Active Faction War doctrine mutated after preparation lock.")
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
