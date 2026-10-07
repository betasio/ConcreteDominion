class_name FacilityEffects
extends Node

signal changed

var garage: BuildLot
var intel_office: BuildLot
var balance: GameBalance


func setup(garage_lot: BuildLot, intel_lot: BuildLot, game_balance: GameBalance = null) -> void:
	garage = garage_lot
	intel_office = intel_lot
	balance = game_balance

	if garage != null:
		garage.changed.connect(_emit_changed)
	if intel_office != null:
		intel_office.changed.connect(_emit_changed)

	changed.emit()


func get_garage_level() -> int:
	return garage.level if garage != null and garage.is_built else 0


func get_intel_level() -> int:
	return intel_office.level if intel_office != null and intel_office.is_built else 0


func get_driver_support_bonus() -> float:
	var per_level := 0.02 if balance == null else balance.get_facility_value("garage_driver_support_per_level", 0.02)
	return float(get_garage_level()) * per_level


func get_spy_support_bonus() -> float:
	var per_level := 0.025 if balance == null else balance.get_facility_value("intel_spy_support_per_level", 0.025)
	return float(get_intel_level()) * per_level


func get_training_time_multiplier(troop_type: StringName) -> float:
	var minimum := 0.70 if balance == null else balance.get_facility_value("minimum_training_multiplier", 0.70)
	match troop_type:
		&"Driver":
			var step := 0.05 if balance == null else balance.get_facility_value("garage_driver_training_reduction_per_level", 0.05)
			return maxf(minimum, 1.0 - float(get_garage_level()) * step)
		&"Spy":
			var step := 0.05 if balance == null else balance.get_facility_value("intel_spy_training_reduction_per_level", 0.05)
			return maxf(minimum, 1.0 - float(get_intel_level()) * step)
		_:
			return 1.0


func get_summary() -> PackedStringArray:
	return PackedStringArray([
		"Garage Lv.%d — Driver support +%d%%, training -%d%%" % [
			get_garage_level(),
			roundi(get_driver_support_bonus() * 100.0),
			roundi((1.0 - get_training_time_multiplier(&"Driver")) * 100.0)
		],
		"Intel Office Lv.%d — Spy support +%.1f%%, training -%d%%" % [
			get_intel_level(),
			get_spy_support_bonus() * 100.0,
			roundi((1.0 - get_training_time_multiplier(&"Spy")) * 100.0)
		]
	])


func _emit_changed() -> void:
	changed.emit()
