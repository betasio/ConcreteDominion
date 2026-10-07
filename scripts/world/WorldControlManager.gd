class_name WorldControlManager
extends Node

signal changed
signal district_discovered(district_id: String)
signal district_captured(district_id: String)
signal patrol_spawned(district_id: String)
signal patrol_resolved(district_id: String, victory: bool)
signal alliance_task_completed(task_id: String)

const PRODUCTION_CAP_SECONDS := 8.0 * 60.0 * 60.0
const PATROL_INTERVAL_SECONDS := 90.0
const COMMAND_SCAN_COOLDOWN_SECONDS := 10.0 * 60.0

var economy: PlayerEconomy
var loot: LootInventory
var progression: PlayerProgression
var roster: TroopRoster
var hospital: HospitalQueue
var alliance: AllianceManager
var city_map: Node
var core_effects: CoreBuildingEffects

var discovered: Dictionary = {"downtown_bank": true}
var owned: Dictionary = {}
var production_bank: float = 0.0
var production_elapsed: float = 0.0
var patrol_elapsed: float = 0.0
var command_scan_remaining: float = 0.0
var active_patrol: Dictionary = {}

var alliance_tasks: Dictionary = {
	"raid_wins": {
		"title": "Hit the Streets",
		"goal": 3,
		"progress": 0,
		"completed": false,
		"alliance_xp": 70,
		"cash": 4000
	},
	"collect_income": {
		"title": "Keep It Moving",
		"goal": 2,
		"progress": 0,
		"completed": false,
		"alliance_xp": 55,
		"cash": 3000
	},
	"clear_patrols": {
		"title": "Clean the Block",
		"goal": 2,
		"progress": 0,
		"completed": false,
		"alliance_xp": 85,
		"cash": 5000
	}
}

var districts: Dictionary = {
	"downtown_bank": {"name":"Downtown Core","level":1,"intel":0,"cash_per_hour":600,"patrol_power":700},
	"harbor_bank": {"name":"Harbor District","level":2,"intel":1,"cash_per_hour":850,"patrol_power":1050},
	"midtown_exchange": {"name":"Midtown","level":3,"intel":1,"cash_per_hour":1100,"patrol_power":1350},
	"northside_hq": {"name":"Northside","level":4,"intel":2,"cash_per_hour":1450,"patrol_power":1700},
	"casino_vault": {"name":"High Roller Strip","level":5,"intel":2,"cash_per_hour":1800,"patrol_power":2150},
	"financial_tower": {"name":"Financial District","level":6,"intel":3,"cash_per_hour":2300,"patrol_power":2600},
	"industrial_depot": {"name":"Industrial Belt","level":7,"intel":3,"cash_per_hour":2900,"patrol_power":3200}
}


func setup(
	player_economy: PlayerEconomy,
	loot_inventory: LootInventory,
	player_progression: PlayerProgression,
	troop_roster: TroopRoster,
	hospital_queue: HospitalQueue,
	alliance_manager: AllianceManager,
	world: Node,
	building_effects: CoreBuildingEffects,
	raid_battle: RaidBattle
) -> void:
	economy = player_economy
	loot = loot_inventory
	progression = player_progression
	roster = troop_roster
	hospital = hospital_queue
	alliance = alliance_manager
	city_map = world
	core_effects = building_effects

	raid_battle.battle_resolved.connect(_on_raid_resolved)
	progression.leveled_up.connect(_on_progression_changed)
	_apply_discovery_visibility()
	changed.emit()


func _process(delta: float) -> void:
	if economy == null:
		return

	var did_change := false
	if command_scan_remaining > 0.0:
		command_scan_remaining = maxf(0.0, command_scan_remaining - delta)

	if not owned.is_empty():
		var before_bank := production_bank
		var cap_amount := float(get_income_per_hour()) * (PRODUCTION_CAP_SECONDS / 3600.0)
		production_bank = minf(
			cap_amount,
			production_bank + float(get_income_per_hour()) * (delta / 3600.0)
		)
		production_elapsed = minf(PRODUCTION_CAP_SECONDS, production_elapsed + delta)
		if floori(before_bank) != floori(production_bank):
			did_change = true

		if active_patrol.is_empty():
			patrol_elapsed += delta
			if patrol_elapsed >= PATROL_INTERVAL_SECONDS:
				_spawn_patrol()
				patrol_elapsed = 0.0
				did_change = true

	if did_change:
		changed.emit()


func is_discovered(target_id: String) -> bool:
	return bool(discovered.get(target_id, false))


func is_owned(target_id: String) -> bool:
	return bool(owned.get(target_id, false))


func can_discover(target_id: String) -> bool:
	if is_discovered(target_id) or not districts.has(target_id) or progression == null:
		return false
	var data: Dictionary = districts[target_id]
	return progression.account_level >= int(data["level"])


func discover_with_intel(target_id: String) -> bool:
	if not can_discover(target_id) or loot == null:
		return false
	var cost := int((districts[target_id] as Dictionary)["intel"])
	if cost > 0 and not loot.spend_loot({"Intel": cost}):
		return false
	_discover(target_id)
	return true


func command_scan() -> bool:
	if command_scan_remaining > 0.0:
		return false
	var next_id := _get_next_discoverable_target()
	if next_id == "":
		return false

	_discover(next_id)
	var safehouse_level := core_effects.safehouse.level if core_effects != null and core_effects.safehouse != null else 1
	command_scan_remaining = maxf(180.0, COMMAND_SCAN_COOLDOWN_SECONDS - float(safehouse_level - 1) * 60.0)
	changed.emit()
	return true


func collect_income() -> int:
	var amount := floori(production_bank)
	if amount <= 0 or economy == null:
		return 0
	economy.add_cash(amount)
	production_bank = 0.0
	production_elapsed = 0.0
	_add_task_progress("collect_income", 1)
	changed.emit()
	return amount


func get_income_per_hour() -> int:
	var total := 0
	for target_id in owned.keys():
		if bool(owned[target_id]) and districts.has(target_id):
			total += int((districts[target_id] as Dictionary)["cash_per_hour"])
	return total


func resolve_patrol() -> Dictionary:
	if active_patrol.is_empty() or roster == null:
		return {}

	var target_id := String(active_patrol["district_id"])
	var required_power := float(active_patrol["power"])
	var available := roster.get_count(&"Enforcer")
	var enforcer_power_each := 100.0
	if progression != null:
		enforcer_power_each = progression.get_enforcer_power_each()
	var player_power := float(available) * enforcer_power_each
	var victory := player_power >= required_power
	var cash_reward := int(active_patrol.get("cash_reward", 0)) if victory else 0

	if victory:
		economy.add_cash(cash_reward)
		if loot != null and bool(active_patrol.get("intel_drop", false)):
			loot.add_item("Intel", 1)
		_add_task_progress("clear_patrols", 1)
	else:
		var wounded := mini(1, available)
		if wounded > 0 and hospital != null:
			hospital.send_to_hospital(&"Enforcer", wounded, 1.1, "Standard")

	active_patrol.clear()
	patrol_elapsed = 0.0
	patrol_resolved.emit(target_id, victory)
	changed.emit()

	return {
		"victory": victory,
		"district_id": target_id,
		"player_power": player_power,
		"required_power": required_power,
		"cash_reward": cash_reward
	}


func get_district_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for target_id in _ordered_ids():
		var data: Dictionary = districts[target_id]
		var state := "FOG"
		if is_owned(target_id):
			state = "OWNED"
		elif is_discovered(target_id):
			state = "DISCOVERED"
		lines.append("%s — %s — $%d/hr" % [
			String(data["name"]),
			state,
			int(data["cash_per_hour"])
		])
	return lines


func get_task_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for task_id in alliance_tasks.keys():
		var task: Dictionary = alliance_tasks[task_id]
		var state := "DONE" if bool(task["completed"]) else "%d/%d" % [
			int(task["progress"]),
			int(task["goal"])
		]
		lines.append("%s — %s" % [String(task["title"]), state])
	return lines


func get_next_discovery_summary() -> String:
	var target_id := _get_next_discoverable_target()
	if target_id == "":
		return "No eligible fogged district."
	var data: Dictionary = districts[target_id]
	return "%s — Intel x%d" % [String(data["name"]), int(data["intel"])]


func discover_next_with_intel() -> bool:
	var target_id := _get_next_discoverable_target()
	return target_id != "" and discover_with_intel(target_id)


func _on_raid_resolved(result: Dictionary) -> void:
	if not bool(result.get("victory", false)):
		return
	var target_id := String(result.get("target_id", ""))
	if not districts.has(target_id):
		return

	_add_task_progress("raid_wins", 1)
	if not is_owned(target_id):
		owned[target_id] = true
		if not is_discovered(target_id):
			discovered[target_id] = true
		district_captured.emit(target_id)
	_apply_discovery_visibility()
	changed.emit()


func _spawn_patrol() -> void:
	var owned_ids: Array[String] = []
	for target_id in _ordered_ids():
		if is_owned(target_id):
			owned_ids.append(target_id)
	if owned_ids.is_empty():
		return

	var target_id := owned_ids[int(Time.get_ticks_msec() / 1000) % owned_ids.size()]
	var data: Dictionary = districts[target_id]
	active_patrol = {
		"district_id": target_id,
		"district_name": String(data["name"]),
		"power": int(data["patrol_power"]),
		"cash_reward": roundi(float(data["cash_per_hour"]) * 0.75),
		"intel_drop": int(data["level"]) >= 4
	}
	patrol_spawned.emit(target_id)


func _calculate_banked_income(elapsed: float) -> float:
	return float(get_income_per_hour()) * (elapsed / 3600.0)


func _discover(target_id: String) -> void:
	discovered[target_id] = true
	_apply_discovery_visibility()
	district_discovered.emit(target_id)
	changed.emit()


func _get_next_discoverable_target() -> String:
	for target_id in _ordered_ids():
		if can_discover(target_id):
			return target_id
	return ""


func _ordered_ids() -> Array[String]:
	return [
		"downtown_bank",
		"harbor_bank",
		"midtown_exchange",
		"northside_hq",
		"casino_vault",
		"financial_tower",
		"industrial_depot"
	]


func refresh_visibility() -> void:
	_apply_discovery_visibility()


func _apply_discovery_visibility() -> void:
	if city_map == null:
		return
	for target in city_map.get_raid_targets():
		target.visible = is_discovered(target.get_target_id()) and city_map.get_view_mode() == &"world"


func _on_progression_changed(_new_level: int) -> void:
	changed.emit()


func _add_task_progress(task_id: String, amount: int) -> void:
	if not alliance_tasks.has(task_id):
		return
	var task: Dictionary = alliance_tasks[task_id]
	if bool(task["completed"]):
		return
	task["progress"] = mini(int(task["goal"]), int(task["progress"]) + maxi(0, amount))
	if int(task["progress"]) >= int(task["goal"]):
		task["completed"] = true
		if alliance != null:
			alliance.award_alliance_xp(int(task["alliance_xp"]))
		if economy != null:
			economy.add_cash(int(task["cash"]))
		alliance_task_completed.emit(task_id)


func get_save_data() -> Dictionary:
	return {
		"discovered": discovered.duplicate(true),
		"owned": owned.duplicate(true),
		"production_elapsed": production_elapsed,
		"production_bank": production_bank,
		"patrol_elapsed": patrol_elapsed,
		"command_scan_remaining": command_scan_remaining,
		"active_patrol": active_patrol.duplicate(true),
		"alliance_tasks": _get_task_save()
	}


func _get_task_save() -> Dictionary:
	var saved := {}
	for task_id in alliance_tasks.keys():
		var task: Dictionary = alliance_tasks[task_id]
		saved[task_id] = {
			"progress": int(task["progress"]),
			"completed": bool(task["completed"])
		}
	return saved


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	var saved_discovered = data.get("discovered", {})
	if saved_discovered is Dictionary and not saved_discovered.is_empty():
		discovered = saved_discovered.duplicate(true)
	discovered["downtown_bank"] = true

	var saved_owned = data.get("owned", {})
	if saved_owned is Dictionary:
		owned = saved_owned.duplicate(true)

	production_elapsed = minf(
		PRODUCTION_CAP_SECONDS,
		float(data.get("production_elapsed", 0.0)) + maxf(0.0, offline_seconds)
	)
	production_bank = maxf(0.0, float(data.get("production_bank", 0.0)))
	var offline_income := float(get_income_per_hour()) * (minf(PRODUCTION_CAP_SECONDS, maxf(0.0, offline_seconds)) / 3600.0)
	var cap_amount := float(get_income_per_hour()) * (PRODUCTION_CAP_SECONDS / 3600.0)
	production_bank = minf(cap_amount, production_bank + offline_income)
	patrol_elapsed = fmod(float(data.get("patrol_elapsed", 0.0)) + maxf(0.0, offline_seconds), PATROL_INTERVAL_SECONDS)
	command_scan_remaining = maxf(0.0, float(data.get("command_scan_remaining", 0.0)) - maxf(0.0, offline_seconds))

	var saved_patrol = data.get("active_patrol", {})
	active_patrol = saved_patrol.duplicate(true) if saved_patrol is Dictionary else {}

	var saved_tasks = data.get("alliance_tasks", {})
	if saved_tasks is Dictionary:
		for task_id in alliance_tasks.keys():
			if saved_tasks.has(task_id) and saved_tasks[task_id] is Dictionary:
				alliance_tasks[task_id]["progress"] = int(saved_tasks[task_id].get("progress", alliance_tasks[task_id]["progress"]))
				alliance_tasks[task_id]["completed"] = bool(saved_tasks[task_id].get("completed", alliance_tasks[task_id]["completed"]))

	_apply_discovery_visibility()
	changed.emit()
