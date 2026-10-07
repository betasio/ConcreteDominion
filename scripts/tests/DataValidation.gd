extends Node

const RAID_PATHS := [
	"res://data/raids/downtown_bank.tres",
	"res://data/raids/harbor_bank.tres",
	"res://data/raids/midtown_exchange.tres",
	"res://data/raids/northside_hq.tres",
	"res://data/raids/casino_vault.tres",
	"res://data/raids/financial_tower.tres",
	"res://data/raids/industrial_depot.tres"
]
const VALID_LOOT := ["Parts", "Intel", "Contraband"]

var failures: PackedStringArray = []


func _ready() -> void:
	_validate_raid_data()
	_validate_building_scenes()
	_validate_required_resources()
	_finish()


func _validate_raid_data() -> void:
	var seen_ids := {}
	var previous_level := 0
	var previous_effective_hp := 0.0

	for path in RAID_PATHS:
		var data := load(path) as RaidTargetData
		if data == null:
			_fail("Could not load raid resource: %s" % path)
			continue

		if data.target_id.strip_edges() == "":
			_fail("%s has an empty target_id." % path)
		elif seen_ids.has(data.target_id):
			_fail("Duplicate raid target_id: %s" % data.target_id)
		else:
			seen_ids[data.target_id] = true

		if data.display_name.strip_edges() == "" or data.district_name.strip_edges() == "":
			_fail("%s is missing display/district text." % data.target_id)

		if data.required_account_level <= previous_level:
			_fail("%s account-level gate is not strictly increasing." % data.target_id)
		previous_level = data.required_account_level

		var effective_hp := data.max_hp * data.hp_multiplier
		if effective_hp <= previous_effective_hp:
			_fail("%s effective HP is not above the previous tier." % data.target_id)
		previous_effective_hp = effective_hp

		if data.reward_cash <= 0 or data.reward_xp <= 0:
			_fail("%s has a non-positive Cash/XP reward." % data.target_id)
		if data.cooldown_seconds <= 0.0:
			_fail("%s has a non-positive cooldown." % data.target_id)
		if data.weakness_bonus < 0.0 or data.weakness_bonus > 0.30:
			_fail("%s weakness bonus is outside the QA range." % data.target_id)

		for item_name in data.guaranteed_loot.keys():
			if not VALID_LOOT.has(String(item_name)):
				_fail("%s uses unknown loot key %s." % [data.target_id, String(item_name)])
			if int(data.guaranteed_loot[item_name]) <= 0:
				_fail("%s has non-positive loot amount for %s." % [data.target_id, String(item_name)])

	if seen_ids.size() != RAID_PATHS.size():
		_fail("Raid ID count does not match raid resource count.")


func _validate_building_scenes() -> void:
	var paths := [
		"res://scenes/buildings/Safehouse.tscn",
		"res://scenes/buildings/Hospital.tscn",
		"res://scenes/buildings/Barracks.tscn"
	]

	for path in paths:
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("Could not load building scene: %s" % path)
			continue
		var building := packed.instantiate() as Building
		if building == null:
			_fail("%s does not instantiate as Building." % path)
			continue
		if building.max_level < 5:
			_fail("%s max level is below the endgame requirement." % building.display_name)
		if building.base_upgrade_cash_cost <= 0 or building.base_upgrade_duration <= 0.0:
			_fail("%s has invalid upgrade cost/duration." % building.display_name)
		if building.base_upgrade_duration < 180.0:
			_fail("%s upgrade duration is still prototype-compressed." % building.display_name)
		building.free()

	var city_scene := load("res://scenes/world/CityMap.tscn") as PackedScene
	if city_scene == null:
		_fail("CityMap scene cannot be loaded.")
		return

	var city := city_scene.instantiate()
	for path in [
		"Buildings/BuildLotA",
		"Buildings/BuildLotB",
		"Buildings/BuildLotC",
		"Buildings/BuildLotD"
	]:
		var lot := city.get_node_or_null(path) as BuildLot
		if lot == null:
			_fail("Missing build lot: %s" % path)
			continue
		if lot.build_cash_cost <= 0 or lot.base_upgrade_cash_cost <= 0:
			_fail("%s has invalid Cash costs." % lot.building_name)
		if lot.build_duration < 300.0 or lot.base_upgrade_duration < 240.0:
			_fail("%s timing is below the production pacing floor." % lot.building_name)
		if lot.max_level < 5:
			_fail("%s max level is below 5." % lot.building_name)
	city.free()


func _validate_required_resources() -> void:
	for path in [
		"res://scenes/core/Boot.tscn",
		"res://scenes/core/Main.tscn",
		"res://scenes/tests/SmokeTest.tscn",
		"res://scenes/tests/BalanceAudit.tscn",
		"res://scripts/core/GameBalance.gd",
		"res://scripts/world/FactionRules.gd",
		"res://scripts/content/LocalizedText.gd"
	]:
		if not ResourceLoader.exists(path):
			_fail("Required resource is missing: %s" % path)

	if SaveManager.SAVE_VERSION < 17:
		_fail("Save schema unexpectedly regressed below v17.")


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[DATA] %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("[DATA] PASS — raid, building, loot, and required-resource validation passed.")
		get_tree().quit(0)
	else:
		print("[DATA] FAIL — %d issue(s)." % failures.size())
		get_tree().quit(1)
