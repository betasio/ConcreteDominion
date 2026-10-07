class_name HospitalQueue
extends Node

signal queue_changed
signal treatment_completed(entry: Dictionary)

@export var seconds_per_troop: float = 3.0
@export var gold_per_minute: int = 2

var wounded_queue: Array[Dictionary] = []
var economy: PlayerEconomy
var _last_displayed_second := -1


func setup(player_economy: PlayerEconomy) -> void:
	economy = player_economy


func _process(delta: float) -> void:
	if wounded_queue.is_empty():
		return

	wounded_queue[0]["seconds_remaining"] = maxf(0.0, float(wounded_queue[0]["seconds_remaining"]) - delta)

	var displayed_second := ceili(float(wounded_queue[0]["seconds_remaining"]))
	if displayed_second != _last_displayed_second:
		_last_displayed_second = displayed_second
		queue_changed.emit()

	if float(wounded_queue[0]["seconds_remaining"]) <= 0.0:
		var completed := wounded_queue.pop_front()
		_last_displayed_second = -1
		treatment_completed.emit(completed)
		queue_changed.emit()


func add_wounded(troop_type: StringName, amount: int) -> void:
	if amount <= 0:
		return
	wounded_queue.append({
		"troop_type": troop_type,
		"amount": amount,
		"seconds_remaining": maxf(1.0, amount * seconds_per_troop)
	})
	queue_changed.emit()


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
		var completed := wounded_queue.pop_front()
		completed["seconds_remaining"] = 0.0
		treatment_completed.emit(completed)

	_last_displayed_second = -1
	queue_changed.emit()
	return true
