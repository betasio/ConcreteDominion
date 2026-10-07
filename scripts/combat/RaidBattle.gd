class_name RaidBattle
extends Node

signal changed
signal battle_started(target_id: String, travel_time: float)
signal battle_resolved(result: Dictionary)

@export var launch_countdown_seconds: float = 5.0

var economy: PlayerEconomy
var roster: TroopRoster
var hospital: HospitalQueue
var synergy: SynergyRaid
var loot_inventory: LootInventory
var city_map: Node

var active_battle: Dictionary = {}
var last_result: Dictionary = {}
var _last_displayed_second := -1
var _offline_resolution_overrun := 0.0


func setup(
	player_economy: PlayerEconomy,
	troop_roster: TroopRoster,
	hospital_queue: HospitalQueue,
	synergy_raid: SynergyRaid,
	loot: LootInventory,
	world: Node
) -> void:
	economy = player_economy
	roster = troop_roster
	hospital = hospital_queue
	synergy = synergy_raid
	loot_inventory = loot
	city_map = world


func _process(delta: float) -> void:
	if active_battle.is_empty():
		return

	active_battle["seconds_remaining"] = maxf(
		0.0,
		float(active_battle["seconds_remaining"]) - delta
	)

	var shown := ceili(float(active_battle["seconds_remaining"]))
	if shown != _last_displayed_second:
		_last_displayed_second = shown
		changed.emit()

	if float(active_battle["seconds_remaining"]) <= 0.0:
		_resolve_active_battle()


func is_active() -> bool:
	return not active_battle.is_empty()


func start_battle(target: RaidTarget, driver_count: int, spy_count: int) -> bool:
	if is_active() or target == null or not target.is_available():
		return false

	if economy == null or roster == null or hospital == null or synergy == null:
		return false

	var target_data := target.get_battle_data()
	if target_data.is_empty():
		return false

	driver_count = clampi(driver_count, 0, roster.get_count(&"Driver"))
	spy_count = clampi(spy_count, 0, roster.get_count(&"Spy"))

	synergy.clear()
	synergy.join_raid("AllianceBoss", 45, 6000.0, &"frontline")

	for i in range(driver_count):
		synergy.join_raid("Driver_%d" % (i + 1), 12, 0.0, &"driver")

	for i in range(spy_count):
		synergy.join_raid("Spy_%d" % (i + 1), 14, 0.0, &"spy")

	active_battle = {
		"target_id": String(target_data["id"]),
		"target_name": String(target_data["name"]),
		"target_hp": float(target_data["hp"]),
		"reward_cash": int(target_data["reward_cash"]),
		"difficulty": String(target_data["difficulty"]),
		"loot": (target_data.get("loot", {}) as Dictionary).duplicate(true),
		"drivers": driver_count,
		"spies": spy_count,
		"seconds_remaining": launch_countdown_seconds
	}

	last_result.clear()
	_last_displayed_second = -1
	_offline_resolution_overrun = 0.0
	battle_started.emit(String(active_battle["target_id"]), launch_countdown_seconds)
	changed.emit()
	return true


func _resolve_active_battle() -> void:
	if active_battle.is_empty():
		return

	var raid_math := synergy.calculate_raid_damage()
	var damage := float(raid_math["damage"])
	var target_hp := float(active_battle["target_hp"])
	var victory := damage >= target_hp
	var reward_cash := int(active_battle["reward_cash"]) if victory else 0
	var awarded_loot: Dictionary = {}

	if victory:
		economy.add_cash(reward_cash)
		awarded_loot = (active_battle.get("loot", {}) as Dictionary).duplicate(true)

		if loot_inventory != null:
			loot_inventory.add_loot(awarded_loot)

		var defeated_target: RaidTarget = city_map.get_raid_target_by_id(
			String(active_battle["target_id"])
		)
		if defeated_target != null:
			defeated_target.start_cooldown(_offline_resolution_overrun)

	var enforcers_available := roster.get_count(&"Enforcer")
	var base_wound_rate := 0.10 if victory else 0.22
	var support_protection := minf(
		float(int(active_battle["drivers"]) + int(active_battle["spies"])) * 0.01,
		0.06
	)
	var wound_rate := maxf(0.04, base_wound_rate - support_protection)
	var wounded_enforcers := mini(
		enforcers_available,
		maxi(0, ceili(float(enforcers_available) * wound_rate))
	)

	var wounded_drivers := 0
	var wounded_spies := 0

	if not victory and int(active_battle["drivers"]) > 0:
		wounded_drivers = 1

	if not victory and int(active_battle["spies"]) > 0:
		wounded_spies = 1

	if wounded_enforcers > 0:
		hospital.send_to_hospital(&"Enforcer", wounded_enforcers)

	if wounded_drivers > 0:
		hospital.send_to_hospital(&"Driver", wounded_drivers)

	if wounded_spies > 0:
		hospital.send_to_hospital(&"Spy", wounded_spies)

	last_result = {
		"victory": victory,
		"target_id": String(active_battle["target_id"]),
		"target_name": String(active_battle["target_name"]),
		"target_hp": target_hp,
		"damage": damage,
		"reward_cash": reward_cash,
		"loot": awarded_loot,
		"wounded_enforcers": wounded_enforcers,
		"wounded_drivers": wounded_drivers,
		"wounded_spies": wounded_spies,
		"support_bonus": float(raid_math["support_bonus"])
	}

	active_battle.clear()
	_last_displayed_second = -1
	_offline_resolution_overrun = 0.0
	battle_resolved.emit(last_result)
	changed.emit()


func get_save_data() -> Dictionary:
	return {
		"active": active_battle.duplicate(true),
		"last_result": last_result.duplicate(true)
	}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	active_battle.clear()
	last_result = data.get("last_result", {}).duplicate(true)
	_last_displayed_second = -1
	_offline_resolution_overrun = 0.0

	var saved_active = data.get("active", {})
	if not saved_active is Dictionary or saved_active.is_empty():
		changed.emit()
		return

	active_battle = saved_active.duplicate(true)
	var saved_remaining := float(active_battle.get("seconds_remaining", 0.0))
	_offline_resolution_overrun = maxf(0.0, offline_seconds - saved_remaining)
	active_battle["seconds_remaining"] = maxf(0.0, saved_remaining - maxf(0.0, offline_seconds))

	synergy.clear()
	synergy.join_raid("AllianceBoss", 45, 6000.0, &"frontline")

	for i in range(int(active_battle.get("drivers", 0))):
		synergy.join_raid("Driver_%d" % (i + 1), 12, 0.0, &"driver")

	for i in range(int(active_battle.get("spies", 0))):
		synergy.join_raid("Spy_%d" % (i + 1), 14, 0.0, &"spy")

	if float(active_battle["seconds_remaining"]) <= 0.0:
		_resolve_active_battle()
	else:
		changed.emit()
