class_name RecruitmentQueue
extends Node

signal queue_changed
signal recruitment_completed(troop_type: StringName, amount: int)

@export var gold_per_minute: int = 2

var economy: PlayerEconomy
var roster: TroopRoster
var balance: GameBalance
var facilities: FacilityEffects
var core_effects: CoreBuildingEffects
var active_job: Dictionary = {}
var queued_jobs: Array[Dictionary] = []
var _last_displayed_second := -1

var definitions := {
	&"Enforcer": {"cash_each": 250, "seconds_each": 1.4},
	&"Driver": {"cash_each": 400, "seconds_each": 2.0},
	&"Spy": {"cash_each": 500, "seconds_each": 2.4}
}


func setup(player_economy: PlayerEconomy, troop_roster: TroopRoster, game_balance: GameBalance = null, facility_effects: FacilityEffects = null, building_effects: CoreBuildingEffects = null) -> void:
	economy = player_economy
	roster = troop_roster
	balance = game_balance
	facilities = facility_effects
	core_effects = building_effects
	if balance != null:
		definitions = balance.recruitment.duplicate(true)
		gold_per_minute = balance.get_speedup_rate("recruitment_gold_per_minute", gold_per_minute)


func _process(delta: float) -> void:
	if active_job.is_empty():
		return
	active_job["seconds_remaining"] = maxf(0.0, float(active_job["seconds_remaining"]) - delta)
	var second := ceili(float(active_job["seconds_remaining"]))
	if second != _last_displayed_second:
		_last_displayed_second = second
		queue_changed.emit()
	if float(active_job["seconds_remaining"]) <= 0.0:
		_complete_job()


func is_busy() -> bool:
	return not active_job.is_empty()


func get_cash_cost(troop_type: StringName, amount: int) -> int:
	if not definitions.has(troop_type):
		return 0
	return int(definitions[troop_type]["cash_each"]) * maxi(0, amount)


func get_duration(troop_type: StringName, amount: int) -> float:
	if not definitions.has(troop_type):
		return 0.0
	var base_duration := float(definitions[troop_type]["seconds_each"]) * float(maxi(0, amount))
	var multiplier := facilities.get_training_time_multiplier(troop_type) if facilities != null else 1.0
	if troop_type == &"Enforcer" and core_effects != null:
		multiplier *= core_effects.get_enforcer_training_multiplier()
	return base_duration * multiplier


func get_queue_capacity() -> int:
	return core_effects.get_recruitment_queue_capacity() if core_effects != null else 1


func get_queue_size() -> int:
	return (0 if active_job.is_empty() else 1) + queued_jobs.size()


func recruit(troop_type: StringName, amount: int) -> bool:
	if amount <= 0 or not definitions.has(troop_type) or get_queue_size() >= get_queue_capacity():
		return false
	var cash_cost := get_cash_cost(troop_type, amount)
	if economy == null or not economy.spend_cash(cash_cost):
		return false
	var job := {
		"troop_type": troop_type,
		"amount": amount,
		"cash_cost": cash_cost,
		"seconds_remaining": maxf(1.0, get_duration(troop_type, amount))
	}
	if active_job.is_empty():
		active_job = job
		_last_displayed_second = -1
	else:
		queued_jobs.append(job)
	queue_changed.emit()
	return true


func get_finish_now_cost() -> int:
	if active_job.is_empty():
		return 0
	return ceili(float(active_job["seconds_remaining"]) / 60.0) * gold_per_minute


func finish_now() -> bool:
	if active_job.is_empty() or economy == null:
		return false
	if not economy.spend_gold(get_finish_now_cost()):
		return false
	_complete_job()
	return true


func _complete_job() -> void:
	if active_job.is_empty() or roster == null:
		return
	var troop_type := StringName(active_job["troop_type"])
	var amount := int(active_job["amount"])
	roster.add_troops(troop_type, amount)
	active_job.clear()
	if not queued_jobs.is_empty():
		active_job = queued_jobs.pop_front()
	_last_displayed_second = -1
	recruitment_completed.emit(troop_type, amount)
	queue_changed.emit()


func get_save_data() -> Dictionary:
	var saved_active := {}
	if not active_job.is_empty():
		saved_active = {
			"troop_type": String(active_job["troop_type"]),
			"amount": int(active_job["amount"]),
			"cash_cost": int(active_job.get("cash_cost", 0)),
			"seconds_remaining": float(active_job["seconds_remaining"])
		}
	var saved_queue: Array = []
	for job in queued_jobs:
		saved_queue.append({
			"troop_type": String(job["troop_type"]),
			"amount": int(job["amount"]),
			"cash_cost": int(job.get("cash_cost", 0)),
			"seconds_remaining": float(job["seconds_remaining"])
		})
	return {"active": saved_active, "queued": saved_queue}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	active_job.clear()
	queued_jobs.clear()
	_last_displayed_second = -1

	var saved_active: Dictionary = {}
	if data.has("active"):
		var raw_active = data.get("active", {})
		if raw_active is Dictionary:
			saved_active = raw_active
	elif data.has("troop_type"):
		saved_active = data

	for raw_job in data.get("queued", []):
		if raw_job is Dictionary:
			queued_jobs.append({
				"troop_type": StringName(raw_job.get("troop_type", "Enforcer")),
				"amount": int(raw_job.get("amount", 0)),
				"cash_cost": int(raw_job.get("cash_cost", 0)),
				"seconds_remaining": float(raw_job.get("seconds_remaining", 0.0))
			})

	var remaining_offline := maxf(0.0, offline_seconds)
	if not saved_active.is_empty():
		active_job = {
			"troop_type": StringName(saved_active.get("troop_type", "Enforcer")),
			"amount": int(saved_active.get("amount", 0)),
			"cash_cost": int(saved_active.get("cash_cost", 0)),
			"seconds_remaining": float(saved_active.get("seconds_remaining", 0.0))
		}

	while remaining_offline > 0.0 and not active_job.is_empty():
		var current := float(active_job["seconds_remaining"])
		if remaining_offline >= current:
			remaining_offline -= current
			var troop_type := StringName(active_job["troop_type"])
			var amount := int(active_job["amount"])
			if roster != null and amount > 0:
				roster.add_troops(troop_type, amount)
				recruitment_completed.emit(troop_type, amount)
			active_job.clear()
			if not queued_jobs.is_empty():
				active_job = queued_jobs.pop_front()
		else:
			active_job["seconds_remaining"] = current - remaining_offline
			remaining_offline = 0.0

	queue_changed.emit()
