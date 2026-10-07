class_name CoreBuildingEffects
extends Node

signal changed

var safehouse: Building
var clinic: Building
var barracks: Building
var balance: GameBalance


func setup(
	safehouse_building: Building,
	clinic_building: Building,
	barracks_building: Building,
	game_balance: GameBalance = null
) -> void:
	safehouse = safehouse_building
	clinic = clinic_building
	barracks = barracks_building
	balance = game_balance

	for building in [safehouse, clinic, barracks]:
		if building != null:
			building.changed.connect(_emit_changed)

	changed.emit()


func get_construction_time_multiplier() -> float:
	var level := safehouse.level if safehouse != null else 1
	var step := _value("safehouse_construction_reduction_per_level", 0.04)
	return maxf(_value("safehouse_min_construction_multiplier", 0.75), 1.0 - float(level - 1) * step)


func get_raid_cash_multiplier() -> float:
	var level := safehouse.level if safehouse != null else 1
	return 1.0 + float(level - 1) * _value("safehouse_raid_cash_bonus_per_level", 0.02)


func get_clinic_time_multiplier() -> float:
	var level := clinic.level if clinic != null else 1
	var step := _value("clinic_healing_reduction_per_level", 0.08)
	return maxf(_value("clinic_min_healing_multiplier", 0.60), 1.0 - float(level - 1) * step)


func get_clinic_slots() -> int:
	var level := clinic.level if clinic != null else 1
	return clampi(1 + int(floor(float(level - 1) / 2.0)), 1, 3)


func get_enforcer_training_multiplier() -> float:
	var level := barracks.level if barracks != null else 1
	var step := _value("barracks_enforcer_training_reduction_per_level", 0.05)
	return maxf(_value("barracks_min_training_multiplier", 0.70), 1.0 - float(level - 1) * step)


func get_recruitment_queue_capacity() -> int:
	var level := barracks.level if barracks != null else 1
	if level >= 5:
		return 3
	if level >= 3:
		return 2
	return 1


func get_building_effect_summary(building: Building) -> String:
	if building == null:
		return ""

	match building.building_type:
		&"safehouse":
			return "Construction time -%d%% • Raid Cash +%d%%" % [
				roundi((1.0 - get_construction_time_multiplier()) * 100.0),
				roundi((get_raid_cash_multiplier() - 1.0) * 100.0)
			]
		&"hospital":
			return "Healing time -%d%% • Treatment slots %d" % [
				roundi((1.0 - get_clinic_time_multiplier()) * 100.0),
				get_clinic_slots()
			]
		&"barracks":
			return "Enforcer training -%d%% • Recruitment queue %d" % [
				roundi((1.0 - get_enforcer_training_multiplier()) * 100.0),
				get_recruitment_queue_capacity()
			]
		_:
			return ""


func _value(key: String, fallback: float) -> float:
	return fallback if balance == null else balance.get_core_building_value(key, fallback)


func _emit_changed() -> void:
	changed.emit()
