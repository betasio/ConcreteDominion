class_name ConstructionQueue
extends Node

signal queue_changed
signal construction_completed(target: Node)

@export var gold_per_minute: int = 3

var active_job: Dictionary = {}
var economy: PlayerEconomy
var _last_displayed_second := -1


func setup(player_economy: PlayerEconomy) -> void:
	economy = player_economy


func _process(delta: float) -> void:
	if active_job.is_empty():
		return

	active_job["seconds_remaining"] = maxf(
		0.0,
		float(active_job["seconds_remaining"]) - delta
	)

	var displayed_second := ceili(float(active_job["seconds_remaining"]))
	if displayed_second != _last_displayed_second:
		_last_displayed_second = displayed_second
		queue_changed.emit()

	if float(active_job["seconds_remaining"]) <= 0.0:
		_complete_active_job()


func is_busy() -> bool:
	return not active_job.is_empty()


func is_target_active(target: Node) -> bool:
	return not active_job.is_empty() and active_job.get("target") == target


func start_upgrade(building: Building) -> bool:
	if is_busy() or building.is_constructing:
		return false

	var next_level := building.level + 1
	var cash_cost := building.get_upgrade_cash_cost()
	var duration := building.get_upgrade_duration()

	if economy == null or not economy.spend_cash(cash_cost):
		return false

	building.begin_construction(next_level)
	active_job = {
		"target": building,
		"label": "%s Lv.%d" % [building.display_name, next_level],
		"target_level": next_level,
		"seconds_remaining": duration,
		"cash_cost": cash_cost
	}
	_last_displayed_second = -1
	queue_changed.emit()
	return true


func start_lot_build(lot: BuildLot) -> bool:
	if is_busy() or lot.is_built:
		return false

	if economy == null or not economy.spend_cash(lot.build_cash_cost):
		return false

	lot.begin_construction()
	active_job = {
		"target": lot,
		"label": lot.building_name,
		"target_level": 1,
		"seconds_remaining": lot.build_duration,
		"cash_cost": lot.build_cash_cost
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

	var cost := get_finish_now_cost()
	if not economy.spend_gold(cost):
		return false

	_complete_active_job()
	return true


func _complete_active_job() -> void:
	if active_job.is_empty():
		return

	var target: Node = active_job["target"]
	var target_level := int(active_job["target_level"])

	if target.has_method("complete_construction"):
		target.call("complete_construction", target_level)

	active_job.clear()
	_last_displayed_second = -1
	construction_completed.emit(target)
	queue_changed.emit()
