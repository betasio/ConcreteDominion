class_name HospitalQueue
extends Node

signal queue_changed
signal treatment_completed(entry: Dictionary)

@export var seconds_per_troop: float = 3.0
@export var gold_per_minute: int = 2

var wounded_queue: Array[Dictionary] = []
var economy: PlayerEconomy
var roster: TroopRoster
var _last_displayed_second := -1


func setup(player_economy: PlayerEconomy, troop_roster: TroopRoster = null) -> void:
	economy = player_economy
	roster = troop_roster


func _process(delta: float) -> void:
	if wounded_queue.is_empty():
		return

	wounded_queue[0]["seconds_remaining"] = maxf(0.0, float(wounded_queue[0]["seconds_remaining"]) - delta)

	var displayed_second := ceili(float(wounded_queue[0]["seconds_remaining"]))
	if displayed_second != _last_displayed_second:
		_last_displayed_second = displayed_second
		queue_changed.emit()

	if float(wounded_queue[0]["seconds_remaining"]) <= 0.0:
		_finish_front_entry()


func add_wounded(troop_type: StringName, amount: int) -> void:
	send_to_hospital(troop_type, amount)


func send_to_hospital(troop_type: StringName, amount: int) -> bool:
	if amount <= 0:
		return false

	if roster != null and not roster.remove_troops(troop_type, amount):
		return false

	wounded_queue.append({
		"troop_type": troop_type,
		"amount": amount,
		"seconds_remaining": maxf(1.0, amount * seconds_per_troop)
	})
	queue_changed.emit()
	return true


func get_instant_heal_cost() -> int:
	var total_seconds := 0.0
	for entry in wounded_queue:
		total_seconds += float(entry["seconds_remaining"])
	return ceili(total_seconds / 60.0) * gold_per_minute


func instant_heal() -> bool:
	if wounded_queue.is_empty():
		return true

	var cost := get_instant_heal_cost()
	if economy == null or not economy.spend_gold(cost):
		return false

	while not wounded_queue.is_empty():
		_finish_front_entry()

	_last_displayed_second = -1
	queue_changed.emit()
	return true


func _finish_front_entry() -> void:
	if wounded_queue.is_empty():
		return

	var completed := wounded_queue.pop_front()
	completed["seconds_remaining"] = 0.0

	if roster != null:
		roster.add_troops(
			StringName(completed["troop_type"]),
			int(completed["amount"])
		)

	_last_displayed_second = -1
	treatment_completed.emit(completed)
	queue_changed.emit()


func get_save_data() -> Dictionary:
	var saved_queue: Array = []
	for entry in wounded_queue:
		saved_queue.append({
			"troop_type": String(entry["troop_type"]),
			"amount": int(entry["amount"]),
			"seconds_remaining": float(entry["seconds_remaining"])
		})
	return {"queue": saved_queue}


func load_save_data(data: Dictionary, offline_seconds: float = 0.0) -> void:
	wounded_queue.clear()

	for raw_entry in data.get("queue", []):
		if raw_entry is Dictionary:
			wounded_queue.append({
				"troop_type": StringName(raw_entry.get("troop_type", "Enforcer")),
				"amount": int(raw_entry.get("amount", 0)),
				"seconds_remaining": float(raw_entry.get("seconds_remaining", 0.0))
			})

	var remaining_offline := maxf(0.0, offline_seconds)

	while remaining_offline > 0.0 and not wounded_queue.is_empty():
		var current_time := float(wounded_queue[0]["seconds_remaining"])
		if remaining_offline >= current_time:
			remaining_offline -= current_time
			_finish_front_entry()
		else:
			wounded_queue[0]["seconds_remaining"] = current_time - remaining_offline
			remaining_offline = 0.0

	_last_displayed_second = -1
	queue_changed.emit()
