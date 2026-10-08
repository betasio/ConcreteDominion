class_name BattleReportManager
extends Node

signal changed
signal report_recorded(report: Dictionary)
signal rematch_started(report: Dictionary)
signal rematch_blocked(reason: String)

const MAX_REPORTS := 20

var raid_battle: RaidBattle
var world_control: WorldControlManager
var city_map: Node

var reports: Array[Dictionary] = []


func setup(battle: RaidBattle, control: WorldControlManager, world: Node) -> void:
	raid_battle = battle
	world_control = control
	city_map = world
	raid_battle.battle_resolved.connect(_on_raid_resolved)
	world_control.operation_resolved.connect(_on_family_operation_resolved)
	changed.emit()


func _on_raid_resolved(result: Dictionary) -> void:
	if result.is_empty():
		return
	var report := result.duplicate(true)
	report["source"] = "raid"
	report["timestamp"] = Time.get_unix_time_from_system()
	report["advice"] = _build_raid_advice(report)
	_record(report)


func _on_family_operation_resolved(result: Dictionary) -> void:
	if result.is_empty():
		return
	var report := result.duplicate(true)
	report["source"] = "family_operation"
	report["timestamp"] = Time.get_unix_time_from_system()
	report["advice"] = _build_family_advice(report)
	_record(report)


func _record(report: Dictionary) -> void:
	reports.push_front(report)
	while reports.size() > MAX_REPORTS:
		reports.pop_back()
	report_recorded.emit(report.duplicate(true))
	changed.emit()


func get_report(index: int) -> Dictionary:
	if index < 0 or index >= reports.size():
		return {}
	return reports[index].duplicate(true)


func get_report_count() -> int:
	return reports.size()


func get_recent_lines(limit: int = 5) -> PackedStringArray:
	var lines := PackedStringArray()
	var count := mini(maxi(0, limit), reports.size())
	for i in range(count):
		var report: Dictionary = reports[i]
		lines.append("#%d %s" % [i + 1, get_report_summary(report)])
	if lines.is_empty():
		lines.append("No battle reports yet.")
	return lines


func get_report_summary(report: Dictionary) -> String:
	var victory := bool(report.get("victory", false))
	var outcome := "WIN" if victory else "LOSS"
	if String(report.get("source", "")) == "raid":
		return "%s • %s • Grade %s" % [
			outcome,
			String(report.get("target_name", "Raid Target")),
			String(report.get("grade", "D"))
		]

	var ratio := float(report.get("player_power", 0.0)) / maxf(1.0, float(report.get("required_power", 1.0)))
	return "%s • %s • %s • Grade %s" % [
		outcome,
		String(report.get("district_name", "District")),
		String(report.get("encounter_type", "operation")).replace("_", " ").capitalize(),
		_grade_from_ratio(ratio, victory)
	]


func get_advice(report: Dictionary) -> String:
	return String(report.get("advice", "Review the report and adjust your crew before the next hit."))


func _build_raid_advice(report: Dictionary) -> String:
	var victory := bool(report.get("victory", false))
	var ratio := float(report.get("damage", 0.0)) / maxf(1.0, float(report.get("target_hp", 1.0)))
	var missed_counter := not bool(report.get("weakness_matched", false))
	var wounded := (
		int(report.get("wounded_enforcers", 0))
		+ int(report.get("wounded_drivers", 0))
		+ int(report.get("wounded_spies", 0))
	)

	if not victory and ratio >= 0.85:
		if missed_counter:
			return "Close loss. Match the target counter-role first; your damage was within 15%% of the clear."
		return "Close loss. Keep the plan, recover wounded crew, and add a small power increase before the rematch."
	if not victory and missed_counter:
		return "The counter-role was missed. Rebuild the raid around %s support before spending more resources." % String(report.get("weakness_role", "the recommended"))
	if not victory:
		return "Power gap is significant. Improve frontline power or equipment before rematching."
	if wounded >= 3:
		return "Victory was costly. Let the Clinic recover the crew before repeating this target."
	if ratio >= 1.35:
		return "Dominant clear. You can keep this setup or shift resources to a harder target."
	if missed_counter:
		return "You won without the counter-role, but matching it should reduce risk on stronger targets."
	return "Clean execution. Counter-role, support, and damage were aligned."


func _build_family_advice(report: Dictionary) -> String:
	var victory := bool(report.get("victory", false))
	var ratio := float(report.get("player_power", 0.0)) / maxf(1.0, float(report.get("required_power", 1.0)))
	var role := String(report.get("role", "Enforcer"))
	var encounter := String(report.get("encounter_type", "roadblock")).replace("_", " ").capitalize()

	if not victory and ratio >= 0.85:
		return "Close loss on %s. Recover the %s specialist and add a small power increase before retrying." % [encounter, role]
	if not victory:
		return "%s needs more %s power. Improve that specialist instead of brute-forcing repeated attempts." % [encounter, role]
	if bool(report.get("dominion_boss", false)) and ratio < 1.15:
		return "Boss win was narrow. Build a safer margin before the next featured rematch."
	if ratio >= 1.35:
		return "Overwhelming operation. Consider rotating to the featured Dominion target for better seasonal value."
	return "Successful operation. Rivalry increased, so future feud rewards also improved."


func can_rematch(report: Dictionary) -> Dictionary:
	if report.is_empty():
		return {"ok":false,"reason":"No report selected."}
	if raid_battle == null or world_control == null:
		return {"ok":false,"reason":"Combat systems are not ready."}
	if raid_battle.is_active() or not world_control.active_patrol.is_empty():
		return {"ok":false,"reason":"Another operation is already active."}

	var source := String(report.get("source", ""))
	if source == "raid":
		if city_map == null:
			return {"ok":false,"reason":"City targets are unavailable."}
		var target_id := String(report.get("target_id", ""))
		var target: RaidTarget = city_map.get_raid_target_by_id(target_id)
		if target == null:
			return {"ok":false,"reason":"That raid target no longer exists."}
		if not target.is_unlocked():
			return {"ok":false,"reason":"That target is currently locked."}
		if not target.is_available():
			return {"ok":false,"reason":"Target is still on cooldown."}
		return {"ok":true,"reason":""}

	if source == "family_operation":
		var district_id := String(report.get("district_id", ""))
		if not world_control.is_discovered(district_id):
			return {"ok":false,"reason":"District is not currently available."}
		var encounter_type := String(report.get("encounter_type", ""))
		if bool(report.get("dominion_boss", false)):
			var boss_type := world_control.family_rules.get_preferred_encounter(district_id)
			if not world_control.can_launch_family_operation(district_id, boss_type):
				return {"ok":false,"reason":"Boss rematch is not currently available."}
		elif not world_control.can_launch_family_operation(district_id, encounter_type):
			return {"ok":false,"reason":"That Rival Family operation is not currently available."}
		return {"ok":true,"reason":""}

	return {"ok":false,"reason":"This report cannot be rematched."}


func rematch(report: Dictionary) -> bool:
	var check := can_rematch(report)
	if not bool(check.get("ok", false)):
		rematch_blocked.emit(String(check.get("reason", "Rematch unavailable.")))
		return false

	var source := String(report.get("source", ""))
	if source == "raid":
		var target: RaidTarget = city_map.get_raid_target_by_id(String(report.get("target_id", "")))
		var drivers := maxi(0, int(report.get("local_drivers", 0)))
		var spies := maxi(0, int(report.get("local_spies", 0)))
		if raid_battle.start_battle(target, drivers, spies):
			rematch_started.emit(report.duplicate(true))
			return true
	elif source == "family_operation":
		var district_id := String(report.get("district_id", ""))
		var started := false
		if bool(report.get("dominion_boss", false)):
			started = world_control.launch_boss_rematch(district_id)
		else:
			started = world_control.launch_family_operation(
				district_id,
				String(report.get("encounter_type", "roadblock"))
			)
		if started:
			rematch_started.emit(report.duplicate(true))
			return true

	rematch_blocked.emit("Rematch could not be started.")
	return false


func get_save_data() -> Dictionary:
	return {"reports": reports.duplicate(true)}


func load_save_data(data: Dictionary) -> void:
	reports.clear()
	var saved = data.get("reports", [])
	if saved is Array:
		for raw_report in saved:
			if not (raw_report is Dictionary):
				continue
			var report: Dictionary = raw_report.duplicate(true)
			var source := String(report.get("source", ""))
			if source not in ["raid", "family_operation"]:
				continue
			report["timestamp"] = maxf(0.0, float(report.get("timestamp", 0.0)))
			report["advice"] = String(report.get("advice", "")).left(300)
			reports.append(report)
			if reports.size() >= MAX_REPORTS:
				break
	changed.emit()


func _grade_from_ratio(ratio: float, victory: bool) -> String:
	if not victory:
		return "C" if ratio >= 0.85 else "D"
	if ratio >= 1.35:
		return "S"
	if ratio >= 1.15:
		return "A"
	return "B"
