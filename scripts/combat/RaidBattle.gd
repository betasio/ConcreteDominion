class_name RaidBattle
extends Node

signal changed
signal battle_started(target_id: String, travel_time: float)
signal battle_resolved(result: Dictionary)

@export var launch_countdown_seconds: float = 5.0
@export_range(0.0, 1.0, 0.05) var equal_reward_pool_share: float = 0.50

var economy: PlayerEconomy
var roster: TroopRoster
var hospital: HospitalQueue
var synergy: SynergyRaid
var loot_inventory: LootInventory
var alliance: AllianceManager
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
	alliance_manager: AllianceManager,
	world: Node
) -> void:
	economy = player_economy
	roster = troop_roster
	hospital = hospital_queue
	synergy = synergy_raid
	loot_inventory = loot
	alliance = alliance_manager
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


func start_battle(target: RaidTarget, local_driver_count: int, local_spy_count: int) -> bool:
	if is_active() or target == null or not target.is_available():
		return false

	if economy == null or roster == null or hospital == null or synergy == null or alliance == null:
		return false

	var target_data := target.get_battle_data()
	if target_data.is_empty():
		return false

	local_driver_count = clampi(local_driver_count, 0, roster.get_count(&"Driver"))
	local_spy_count = clampi(local_spy_count, 0, roster.get_count(&"Spy"))

	var participant_snapshot := alliance.build_participant_snapshot(
		local_driver_count,
		local_spy_count
	)

	if participant_snapshot.is_empty():
		return false

	synergy.clear()

	for participant in participant_snapshot:
		var role := StringName(participant["role"])

		if bool(participant["is_local"]):
			if role == &"driver" and int(participant["unit_count"]) <= 0:
				continue
			if role == &"spy" and int(participant["unit_count"]) <= 0:
				continue

		synergy.join_raid(
			String(participant["player_id"]),
			int(participant["level"]),
			float(participant["base_power"]),
			role,
			String(participant["name"])
		)

	var raid_preview := synergy.calculate_raid_damage()
	if float(raid_preview["frontline_power"]) <= 0.0:
		return false

	active_battle = {
		"target_id": String(target_data["id"]),
		"target_name": String(target_data["name"]),
		"target_hp": float(target_data["hp"]),
		"reward_cash": int(target_data["reward_cash"]),
		"difficulty": String(target_data["difficulty"]),
		"loot": (target_data.get("loot", {}) as Dictionary).duplicate(true),
		"local_drivers": local_driver_count,
		"local_spies": local_spy_count,
		"participants": participant_snapshot,
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
	var reward_pool := int(active_battle["reward_cash"]) if victory else 0
	var awarded_loot: Dictionary = {}

	var reward_splits := _calculate_reward_splits(
		reward_pool,
		raid_math.get("contributions", {}),
		active_battle.get("participants", [])
	)

	var local_cash_reward := int(reward_splits.get("local_player", 0))

	if victory:
		if local_cash_reward > 0:
			economy.add_cash(local_cash_reward)

		awarded_loot = (active_battle.get("loot", {}) as Dictionary).duplicate(true)

		if _local_player_participated() and loot_inventory != null:
			loot_inventory.add_loot(awarded_loot)
		else:
			awarded_loot.clear()

		var defeated_target: RaidTarget = city_map.get_raid_target_by_id(
			String(active_battle["target_id"])
		)
		if defeated_target != null:
			defeated_target.start_cooldown(_offline_resolution_overrun)

	var local_role := _get_local_role()
	var wounded_enforcers := 0
	var wounded_drivers := 0
	var wounded_spies := 0
	var elite_target := String(active_battle.get("difficulty", "")) == "Elite"

	if local_role == &"driver" and int(active_battle.get("local_drivers", 0)) > 0:
		if not victory or elite_target:
			wounded_drivers = 1

	if local_role == &"spy" and int(active_battle.get("local_spies", 0)) > 0:
		if not victory or elite_target:
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
		"reward_pool": reward_pool,
		"local_cash_reward": local_cash_reward,
		"reward_splits": reward_splits,
		"contributions": raid_math.get("contributions", {}).duplicate(true),
		"participants": (active_battle.get("participants", []) as Array).duplicate(true),
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


func _calculate_reward_splits(
	reward_pool: int,
	contributions: Dictionary,
	participants: Array
) -> Dictionary:
	var splits := {}

	if reward_pool <= 0 or participants.is_empty():
		return splits

	var participant_ids: Array[String] = []
	var total_contribution := 0.0

	for participant in participants:
		var player_id := String(participant.get("player_id", ""))

		if player_id == "" or not synergy.participants.has(player_id):
			continue

		participant_ids.append(player_id)
		total_contribution += maxf(
			0.0,
			float(contributions.get(player_id, 0.0))
		)

	if participant_ids.is_empty():
		return splits

	var equal_pool := float(reward_pool) * equal_reward_pool_share
	var performance_pool := float(reward_pool) - equal_pool
	var equal_each := equal_pool / float(participant_ids.size())
	var distributed := 0

	for i in range(participant_ids.size()):
		var player_id := participant_ids[i]
		var performance_share := 0.0

		if total_contribution > 0.0:
			performance_share = performance_pool * (
				float(contributions.get(player_id, 0.0)) / total_contribution
			)

		var share := roundi(equal_each + performance_share)

		if i == participant_ids.size() - 1:
			share = maxi(0, reward_pool - distributed)

		splits[player_id] = share
		distributed += share

	return splits


func _local_player_participated() -> bool:
	for participant in active_battle.get("participants", []):
		if String(participant.get("player_id", "")) == "local_player":
			return synergy.participants.has("local_player")
	return false


func _get_local_role() -> StringName:
	for participant in active_battle.get("participants", []):
		if String(participant.get("player_id", "")) == "local_player":
			return StringName(participant.get("role", ""))
	return &""


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
	active_battle["seconds_remaining"] = maxf(
		0.0,
		saved_remaining - maxf(0.0, offline_seconds)
	)

	synergy.clear()

	for participant in active_battle.get("participants", []):
		var role := StringName(participant.get("role", "frontline"))
		var player_id := String(participant.get("player_id", ""))

		if player_id == "":
			continue

		if bool(participant.get("is_local", false)):
			if role == &"driver" and int(participant.get("unit_count", 0)) <= 0:
				continue
			if role == &"spy" and int(participant.get("unit_count", 0)) <= 0:
				continue

		synergy.join_raid(
			player_id,
			int(participant.get("level", 1)),
			float(participant.get("base_power", 0.0)),
			role,
			String(participant.get("name", player_id))
		)

	if float(active_battle["seconds_remaining"]) <= 0.0:
		_resolve_active_battle()
	else:
		changed.emit()
