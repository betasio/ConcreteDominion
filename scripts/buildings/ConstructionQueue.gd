class_name ConstructionQueue
extends Node

signal queue_changed
signal construction_completed(target: Node)

@export var gold_per_minute: int = 3

var active_job: Dictionary = {}
var economy: PlayerEconomy
var balance: GameBalance
var core_effects: CoreBuildingEffects
var _last_displayed_second := -1

func setup(player_economy: PlayerEconomy, game_balance: GameBalance = null, building_effects: CoreBuildingEffects = null) -> void:
	economy = player_economy
	balance = game_balance
	core_effects = building_effects
	if balance != null:
		gold_per_minute = balance.get_speedup_rate("construction_gold_per_minute", gold_per_minute)

func _process(delta: float) -> void:
	if active_job.is_empty():
		return
	active_job["seconds_remaining"] = maxf(0.0, float(active_job["seconds_remaining"]) - delta)
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
	if is_busy() or not building.can_upgrade():
		return false
	var next_level := building.level + 1
	var cash_cost := building.get_upgrade_cash_cost()
	var duration := building.get_upgrade_duration() * (core_effects.get_construction_time_multiplier() if core_effects != null else 1.0)
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

func start_facility_upgrade(lot: BuildLot) -> bool:
	if is_busy() or not lot.can_upgrade():
		return false
	var next_level := lot.level + 1
	var cash_cost := lot.get_upgrade_cash_cost()
	var duration := lot.get_upgrade_duration() * (core_effects.get_construction_time_multiplier() if core_effects != null else 1.0)
	if economy == null or not economy.spend_cash(cash_cost):
		return false
	lot.begin_construction(next_level)
	active_job = {
		"target": lot,
		"label": "%s Lv.%d" % [lot.building_name, next_level],
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
	lot.begin_construction(1)
	active_job = {
		"target": lot,
		"label": lot.building_name,
		"target_level": 1,
		"seconds_remaining": lot.build_duration * (core_effects.get_construction_time_multiplier() if core_effects != null else 1.0),
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

func get_save_data() -> Dictionary:
	if active_job.is_empty():
		return {}
	var world := get_parent().get_node_or_null("CityMap")
	if world == null or not world.has_method("get_target_id"):
		return {}
	return {
		"target_id": world.get_target_id(active_job["target"]),
		"label": String(active_job.get("label", "")),
		"target_level": int(active_job.get("target_level", 1)),
		"seconds_remaining": float(active_job.get("seconds_remaining", 0.0)),
		"cash_cost": int(active_job.get("cash_cost", 0))
	}

func load_save_data(data: Dictionary, offline_seconds: float, world: Node) -> void:
	active_job.clear()
	_last_displayed_second = -1
	if data.is_empty():
		queue_changed.emit()
		return

	var target := world.get_persistent_target(String(data.get("target_id", "")))
	if target == null:
		queue_changed.emit()
		return

	var remaining := maxf(0.0, float(data.get("seconds_remaining", 0.0)) - maxf(0.0, offline_seconds))
	var target_level := int(data.get("target_level", 1))

	if remaining <= 0.0:
		if target.has_method("complete_construction"):
			target.call("complete_construction", target_level)
		construction_completed.emit(target)
	else:
		if target is Building:
			target.begin_construction(target_level)
		elif target is BuildLot:
			target.begin_construction(target_level)
		active_job = {
			"target": target,
			"label": String(data.get("label", "")),
			"target_level": target_level,
			"seconds_remaining": remaining,
			"cash_cost": int(data.get("cash_cost", 0))
		}

	queue_changed.emit()
