class_name GameBalance
extends Node

signal changed

var recruitment: Dictionary = {
	&"Enforcer": {"cash_each": 250, "seconds_each": 1.4},
	&"Driver": {"cash_each": 400, "seconds_each": 2.0},
	&"Spy": {"cash_each": 500, "seconds_each": 2.4}
}

var speedups: Dictionary = {
	"recruitment_gold_per_minute": 2,
	"construction_gold_per_minute": 3,
	"hospital_gold_per_minute": 2
}

var facilities: Dictionary = {
	"garage_driver_support_per_level": 0.02,
	"garage_driver_training_reduction_per_level": 0.05,
	"intel_spy_support_per_level": 0.025,
	"intel_spy_training_reduction_per_level": 0.05,
	"minimum_training_multiplier": 0.70
}

var progression: Dictionary = {
	"base_xp_to_level": 100,
	"xp_step_per_level": 75,
	"driver_base_bonus": 0.15,
	"driver_bonus_per_level": 0.03,
	"spy_base_bonus": 0.18,
	"spy_bonus_per_level": 0.04,
	"enforcer_base_power": 100.0,
	"enforcer_power_per_level": 15.0
}


func get_recruitment_definition(troop_type: StringName) -> Dictionary:
	return recruitment.get(troop_type, {}).duplicate(true)


func get_speedup_rate(key: String, fallback: int) -> int:
	return int(speedups.get(key, fallback))


func get_progression_value(key: String, fallback: float) -> float:
	return float(progression.get(key, fallback))


func get_facility_value(key: String, fallback: float) -> float:
	return float(facilities.get(key, fallback))


func get_debug_summary() -> PackedStringArray:
	return PackedStringArray([
		"Recruit: Enforcer $%d / %.1fs" % [
			int(recruitment[&"Enforcer"]["cash_each"]),
			float(recruitment[&"Enforcer"]["seconds_each"])
		],
		"Recruit: Driver $%d / %.1fs" % [
			int(recruitment[&"Driver"]["cash_each"]),
			float(recruitment[&"Driver"]["seconds_each"])
		],
		"Recruit: Spy $%d / %.1fs" % [
			int(recruitment[&"Spy"]["cash_each"]),
			float(recruitment[&"Spy"]["seconds_each"])
		],
		"Facilities: Garage +%.1f%% Driver/Lv • Intel +%.1f%% Spy/Lv" % [
			get_facility_value("garage_driver_support_per_level", 0.02) * 100.0,
			get_facility_value("intel_spy_support_per_level", 0.025) * 100.0
		],
		"Gold/min: Recruit %d • Build %d • Clinic %d" % [
			int(speedups["recruitment_gold_per_minute"]),
			int(speedups["construction_gold_per_minute"]),
			int(speedups["hospital_gold_per_minute"])
		]
	])
