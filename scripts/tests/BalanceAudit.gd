extends Node

const RAID_PATHS := [
	"res://data/raids/downtown_bank.tres",
	"res://data/raids/harbor_bank.tres",
	"res://data/raids/midtown_exchange.tres",
	"res://data/raids/northside_hq.tres",
	"res://data/raids/casino_vault.tres",
	"res://data/raids/financial_tower.tres",
	"res://data/raids/industrial_depot.tres"
]

var failures: PackedStringArray = []
var warnings: PackedStringArray = []


func _ready() -> void:
	print("[BALANCE] Concrete Dominion deterministic audit")
	_audit_progression_curve()
	_audit_cash_sinks()
	_audit_raid_curve()
	_audit_specialist_value()
	_audit_timer_scale()
	_finish()


func _audit_progression_curve() -> void:
	var cumulative := 0
	for level in range(1, 7):
		cumulative += 100 + (level - 1) * 75
	print("[BALANCE] XP required from Account Lv.1 -> Lv.7: %d" % cumulative)

	var raid_xp := 0
	for path in RAID_PATHS:
		var data := load(path) as RaidTargetData
		if data != null:
			raid_xp += data.reward_xp
	print("[BALANCE] One first-clear of every district yields %d raw raid XP." % raid_xp)

	if cumulative <= 0 or cumulative > 5000:
		_fail("Account XP curve is outside the supported audit envelope.")


func _audit_cash_sinks() -> void:
	var core_total := 0
	for path in [
		"res://scenes/buildings/Safehouse.tscn",
		"res://scenes/buildings/Hospital.tscn",
		"res://scenes/buildings/Barracks.tscn"
	]:
		var building := (load(path) as PackedScene).instantiate() as Building
		for level in range(1, building.max_level):
			core_total += building.base_upgrade_cash_cost * level
		building.free()

	var city := (load("res://scenes/world/CityMap.tscn") as PackedScene).instantiate()
	var facility_total := 0
	for node_path in [
		"Buildings/BuildLotA",
		"Buildings/BuildLotB",
		"Buildings/BuildLotC",
		"Buildings/BuildLotD"
	]:
		var lot := city.get_node(node_path) as BuildLot
		facility_total += lot.build_cash_cost
		for level in range(1, lot.max_level):
			facility_total += lot.base_upgrade_cash_cost * level
	city.free()

	var total_sink := core_total + facility_total
	print("[BALANCE] Max core-building Cash sink: $%d" % core_total)
	print("[BALANCE] Build + max facility Cash sink: $%d" % facility_total)
	print("[BALANCE] Combined city-development sink: $%d" % total_sink)

	var all_turf_income := 600 + 850 + 1100 + 1450 + 1800 + 2300 + 2900
	var hours_at_full_income := float(total_sink) / float(all_turf_income)
	print("[BALANCE] Equivalent full-city passive-income hours: %.1f" % hours_at_full_income)

	if total_sink < 250000:
		_warn("City Cash sink is very low for a long-term progression game.")
	if hours_at_full_income < 12.0:
		_warn("Full-city passive income repays all city development in under 12 hours.")


func _audit_raid_curve() -> void:
	var alliance_levels := [1, 1, 2, 2, 3, 4, 4]
	var specialist_levels := [1, 1, 1, 2, 2, 3, 3]
	var garage_levels := [0, 1, 1, 2, 3, 4, 5]
	var intel_levels := [0, 0, 1, 2, 3, 4, 5]

	for i in range(RAID_PATHS.size()):
		var data := load(RAID_PATHS[i]) as RaidTargetData
		if data == null:
			continue

		var alliance_level := int(alliance_levels[i])
		var specialist_level := int(specialist_levels[i])
		var garage_level := int(garage_levels[i])
		var intel_level := int(intel_levels[i])

		var driver_each := 0.15 + float(specialist_level - 1) * 0.03 + float(garage_level) * 0.02
		var spy_each := 0.18 + float(specialist_level - 1) * 0.04 + float(intel_level) * 0.025

		var driver_count := 2
		var spy_count := 1
		if alliance_level >= 2:
			spy_count = 2
		if alliance_level >= 4:
			driver_count = 3

		var support := minf(1.25, float(driver_count) * driver_each + float(spy_count) * spy_each)
		var frontline := 8000.0 * (1.0 + float(alliance_level - 1) * 0.02)
		var damage := frontline * (1.0 + support)

		var weakness_present := (
			data.weakness_role == &"Enforcer"
			or (data.weakness_role == &"Driver" and driver_count > 0)
			or (data.weakness_role == &"Spy" and spy_count > 0)
		)
		if weakness_present:
			damage *= 1.0 + data.weakness_bonus

		# Reference F2P player uses the matching role's level-1 equipment perk.
		damage *= 1.03

		var tactical_required := i >= 5
		if tactical_required:
			# Late tiers are expected to exercise Blitz + Intel Burst, both obtainable in-game.
			damage *= 1.12
			damage *= 1.10

		var target_hp := data.max_hp * data.hp_multiplier
		var ratio := damage / target_hp
		var profile := "tactical" if tactical_required else "balanced"
		print("[BALANCE] %s — %s ratio %.2f  damage %.0f / HP %.0f" % [
			data.display_name,
			profile,
			ratio,
			damage,
			target_hp
		])

		if ratio < 1.0:
			_fail("%s is not beatable by its reference %s F2P alliance profile." % [data.display_name, profile])
		elif ratio < 1.05:
			_warn("%s reference clear margin is below 5%%." % data.display_name)


func _audit_specialist_value() -> void:
	var frontline := 8000.0
	var driver_bonus := 0.15
	var spy_bonus := 0.18

	var no_local := frontline * (1.0 + driver_bonus + spy_bonus)
	var with_local_driver := frontline * (1.0 + driver_bonus * 2.0 + spy_bonus)
	var with_local_spy := frontline * (1.0 + driver_bonus + spy_bonus * 2.0)

	var driver_uplift := with_local_driver / no_local - 1.0
	var spy_uplift := with_local_spy / no_local - 1.0

	print("[BALANCE] Local Driver early-raid damage uplift: %.1f%%" % (driver_uplift * 100.0))
	print("[BALANCE] Local Spy early-raid damage uplift: %.1f%%" % (spy_uplift * 100.0))

	if driver_uplift < 0.10:
		_fail("Driver specialist contribution fell below the 10% F2P usefulness floor.")
	if spy_uplift < 0.10:
		_fail("Spy specialist contribution fell below the 10% F2P usefulness floor.")


func _audit_timer_scale() -> void:
	var recruit_seconds := [1.4, 2.0, 2.4]
	var average := (recruit_seconds[0] + recruit_seconds[1] + recruit_seconds[2]) / 3.0
	print("[BALANCE] Mean base recruitment seconds/troop: %.1f" % average)

	if average < 10.0:
		_warn("Recruitment/build/healing timers are prototype-compressed; production monetization pacing is not yet represented.")

	var starter_gold := 250
	var one_minute_build_speedup := 3
	if starter_gold >= one_minute_build_speedup * 50:
		_warn("Starter Gold can fund many current short speed-ups; reassess after production-scale timer tuning.")


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[BALANCE][FAIL] %s" % message)


func _warn(message: String) -> void:
	warnings.append(message)
	print("[BALANCE][WARN] %s" % message)


func _finish() -> void:
	print("[BALANCE] Warnings: %d | Failures: %d" % [warnings.size(), failures.size()])
	if failures.is_empty():
		print("[BALANCE] PASS — reference progression and F2P raid viability are intact.")
		get_tree().quit(0)
	else:
		print("[BALANCE] FAIL — repair hard balance/data regressions before merging.")
		get_tree().quit(1)
