class_name RecruitmentQueue
extends Node

signal queue_changed
signal recruitment_completed(troop_type: StringName, amount: int)

@export var gold_per_minute: int = 2

var economy: PlayerEconomy
var roster: TroopRoster
var balance: GameBalance
var active_job: Dictionary = {}
var _last_displayed_second := -1

var definitions := {
	&"Enforcer": {"cash_each": 250, "seconds_each": 1.4},
	&"Driver": {"cash_each": 400, "seconds_each": 2.0},
	&"Spy": {"cash_each": 500, "seconds_each": 2.4}
}


func setup(player_economy: PlayerEconomy, troop_roster: TroopRoster, game_balance: GameBalance = null) -> void:
	economy = player_economy
	roster = troop_roster
	balance = game_balance
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
	return float(definitions[troop_type]["seconds_each"]) * float(maxi(0, amount))


func recruit(troop_type: StringName, amount: int) -> bool:
	if is_busy() or amount <= 0 or not definitions.has(troop_type):
		return false
	var cash_cost := get_cash_cost(troop_type, amount)
	if economy == null or not economy.spend_cash(cash_cost):
		return false
	active_job = {
		"troop_type": troop_type,
		"amount": amount,
		"cash_cost": cash_cost,
		"seconds_remaining": maxf(1.0, get_duration(troop_type, amount))
	}
	_last_displayed_second = -1
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
	_last_displayed_second = -1
	recruitment_completed.emit(troop_type, amount)
	queue_changed.emit()


func get_save_data() -> Dictionary:
	if active_job.is_empty():
		return {}

	return {
		"troop_type": String(active_job["troop_type"]),
		"amount": int(active_job["amount"]),
		"cash_cost": int(active_job.get("cash_cost", 0)),
		"seconds_remaining": float(active_job["seconds_remaining"])
	}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	active_job.clear()
	_last_displayed_second = -1

	if data.is_empty():
		queue_changed.emit()
		return

	var troop_type := StringName(data.get("troop_type", "Enforcer"))
	var amount := int(data.get("amount", 0))
	var remaining := maxf(0.0, float(data.get("seconds_remaining", 0.0)) - maxf(0.0, offline_seconds))

	if remaining <= 0.0:
		if roster != null and amount > 0:
			roster.add_troops(troop_type, amount)
			recruitment_completed.emit(troop_type, amount)
	else:
		active_job = {
			"troop_type": troop_type,
			"amount": amount,
			"cash_cost": int(data.get("cash_cost", 0)),
			"seconds_remaining": remaining
		}

	queue_changed.emit()
