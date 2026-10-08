class_name BattleReportManager
extends Node

signal changed
signal report_recorded(report: Dictionary)
signal rematch_started(report: Dictionary)
signal rematch_blocked(reason: String)

const MAX_REPORTS := 20

var raid_battle: RaidBattle
var world_control: WorldControlManager
var endgame: EndgameManager
var city_map: Node
var reports: Array[Dictionary] = []


func setup(
	battle: RaidBattle,
	control: WorldControlManager,
	endgame_manager: EndgameManager,
	world: Node
) -> void:
	raid_battle = battle
	world_control = control
	endgame = endgame_manager
	city_map = world
	raid_battle.battle_resolved.connect(_on_raid_resolved)
	world_control.operation_resolved.connect(_on_operation_resolved)
	changed.emit()


func _on_raid_resolved(result: Dictionary) -> void:
	if result.is_empty():
		return
	var report := {
		"type":"raid",
		"timestamp":Time.get_unix_time_from_system(),
		"victory":bool(result.get("victory", false)),
		"grade":String(result.get("grade", "D")),
		"target_id":String(result.get("target_id", "")),
		"title":String(result.get("target_name", "Raid Target")),
		"family":world_control.get_rival_faction(String(result.get("target_id", ""))),
		"damage":float(result.get("damage", 0.0)),
		"target_hp":float(result.get("target_hp", 0.0)),
		"cash_reward":int(result.get("local_cash_reward", 0)),
		"xp_reward":int(result.get("xp_reward", 0)),
		"loot":(result.get("loot", {}) as Dictionary).duplicate(true),
		"weakness_role":String(result.get("weakness_role", "")),
		"weakness_matched":bool(result.get("weakness_matched", false)),
		"preset":String(result.get("preset", "Balanced")),
		"support_bonus":float(result.get("support_bonus", 0.0)),
		"injury_severity":String(result.get("injury_severity", "None")),
		"wounded_enforcers":int(result.get("wounded_enforcers", 0)),
		"wounded_drivers":int(result.get("wounded_drivers", 0)),
		"wounded_spies":int(result.get("wounded_spies", 0)),
		"local_drivers":int(result.get("local_drivers", 0)),
		"local_spies":int(result.get("local_spies", 0)),
		"advice":_build_raid_advice(result)
	}
	_add_report(report)


func _on_operation_resolved(result: Dictionary) -> void:
	if result.is_empty():
		return
	var report := {
		"type":"operation",
		"timestamp":Time.get_unix_time_from_system(),
		"victory":bool(result.get("victory", false)),
		"grade":_grade_operation(result),
		"target_id":String(result.get("district_id", "")),
		"title":String(result.get("district_name", "Rival Operation")),
		"family":String(result.get("family", "Rival Family")),
		"encounter_type":String(result.get("encounter_type", "roadblock")),
		"role":String(result.get("role", "Enforcer")),
		"player_power":float(result.get("player_power", 0.0)),
		"required_power":float(result.get("required_power", 0.0)),
		"cash_reward":int(result.get("cash_reward", 0)),
		"loot":(result.get("loot", {}) as Dictionary).duplicate(true),
		"dominion_boss":bool(result.get("dominion_boss", false)),
		"boss_name":String(result.get("boss_name", "")),
		"rivalry_before":int(result.get("rivalry_before", 0)),
		"rivalry_after":int(result.get("rivalry_after", 0)),
		"rivalry_label":String(result.get("rivalry_label", "COLD")),
		"season_points":int(endgame.get_status().get("season_points", 0)) if endgame != null else 0,
		"advice":_build_operation_advice(result)
	}
	_add_report(report)


func _add_report(report: Dictionary) -> void:
	reports.push_front(report.duplicate(true))
	while reports.size() > MAX_REPORTS:
		reports.pop_back()
	report_recorded.emit(reports[0].duplicate(true))
	changed.emit()


func get_report_count() -> int:
	return reports.size()


func get_report(index: int) -> Dictionary:
	if index < 0 or index >= reports.size():
		return {}
	return reports[index].duplicate(true)


func get_report_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for i in range(reports.size()):
		var report: Dictionary = reports[i]
		lines.append("#%02d • %s • %s • %s" % [
			i + 1,
			"WIN" if bool(report.get("victory", false)) else "LOSS",
			String(report.get("grade", "D")),
			String(report.get("title", "Operation"))
		])
	if lines.is_empty():
		lines.append("No operation reports yet.")
	return lines


func get_advice(report: Dictionary) -> String:
	return String(report.get("advice", "Review the report and adjust your crew before the next hit."))


func get_rematch_status(index: int) -> Dictionary:
	var report := get_report(index)
	if report.is_empty():
		return {"ok":false,"reason":"No report selected."}
	var target_id := String(report.get("target_id", ""))

	if String(report.get("type", "")) == "raid":
		if raid_battle == null or city_map == null:
			return {"ok":false,"reason":"Raid systems are not ready."}
		if raid_battle.is_active() or (world_control != null and not world_control.active_patrol.is_empty()):
			return {"ok":false,"reason":"Another operation is already active."}
		var target: RaidTarget = city_map.get_raid_target_by_id(target_id)
		if target == null:
			return {"ok":false,"reason":"Target is no longer available."}
		if not target.is_unlocked():
			return {"ok":false,"reason":"Target is currently locked."}
		if not target.is_available():
			return {"ok":false,"reason":"Target is recovering from the last hit."}
		return {"ok":true,"reason":""}

	if world_control == null:
		return {"ok":false,"reason":"Territory operations are not ready."}
	if raid_battle != null and raid_battle.is_active():
		return {"ok":false,"reason":"Another operation is already active."}
	if not world_control.active_patrol.is_empty():
		return {"ok":false,"reason":"A Rival Family operation is already active."}
	if not world_control.is_discovered(target_id):
		return {"ok":false,"reason":"District is not currently available."}
	if bool(report.get("dominion_boss", false)):
		return {"ok":world_control.family_rules != null,"reason":"" if world_control.family_rules != null else "Boss data is unavailable."}
	if not world_control.can_launch_family_operation(target_id, String(report.get("encounter_type", "roadblock"))):
		return {"ok":false,"reason":"That operation is not currently available."}
	return {"ok":true,"reason":""}


func can_rematch(index: int) -> bool:
	return bool(get_rematch_status(index).get("ok", false))


func rematch(index: int) -> bool:
	var status := get_rematch_status(index)
	if not bool(status.get("ok", false)):
		rematch_blocked.emit(String(status.get("reason", "Rematch unavailable.")))
		return false

	var report := get_report(index)
	var target_id := String(report.get("target_id", ""))
	var started := false
	if String(report.get("type", "")) == "raid":
		var target: RaidTarget = city_map.get_raid_target_by_id(target_id)
		started = raid_battle.start_battle(
			target,
			int(report.get("local_drivers", 0)),
			int(report.get("local_spies", 0))
		)
	elif bool(report.get("dominion_boss", false)):
		started = world_control.launch_boss_rematch(target_id)
	else:
		started = world_control.launch_family_operation(target_id, String(report.get("encounter_type", "roadblock")))

	if started:
		rematch_started.emit(report)
		return true
	rematch_blocked.emit("Rematch could not be started.")
	return false


func _build_raid_advice(result: Dictionary) -> String:
	var damage := float(result.get("damage", 0.0))
	var hp := maxf(1.0, float(result.get("target_hp", 1.0)))
	var ratio := damage / hp
	var missed_counter := not bool(result.get("weakness_matched", false))
	var wounds := int(result.get("wounded_enforcers", 0)) + int(result.get("wounded_drivers", 0)) + int(result.get("wounded_spies", 0))
	if not bool(result.get("victory", false)) and ratio >= 0.85:
		if missed_counter:
			return "Close loss. Match the target counter-role first; your damage was within 15%% of the clear."
		return "Close loss. Keep the plan, recover wounded crew, and add a small power increase before revenge."
	if not bool(result.get("victory", false)) and missed_counter:
		return "Counter missed. Bring %s support before retrying." % String(result.get("weakness_role", "the recommended role"))
	if not bool(result.get("victory", false)):
		return "Power gap is too large. Upgrade the squad before spending another attempt."
	if wounds >= 3:
		return "Victory was costly. Let the Clinic recover the crew before repeating this target."
	if ratio >= 1.35:
		return "Dominant clear. This setup is safe to repeat or redirect toward a harder target."
	if missed_counter:
		return "You won without the counter-role, but matching it should reduce risk against stronger targets."
	return "Clean win. Counter-role, support, and damage were aligned."


func _build_operation_advice(result: Dictionary) -> String:
	var player := float(result.get("player_power", 0.0))
	var required := maxf(1.0, float(result.get("required_power", 1.0)))
	var ratio := player / required
	var role := String(result.get("role", "Enforcer"))
	if not bool(result.get("victory", false)) and ratio >= 0.85:
		return "Near miss. Add roughly %d%% more %s power and strike again." % [ceili((1.0 - ratio) * 100.0), role]
	if not bool(result.get("victory", false)):
		return "This route is overmatched. Build %s strength or choose another operation first." % role
	if bool(result.get("dominion_boss", false)) and ratio < 1.15:
		return "Boss win was narrow. Build a safer margin before the next featured rematch."
	if ratio >= 1.35:
		return "Overwhelming operation. Rotate to the featured Dominion target for better seasonal value."
	return "Operation secured. Rivalry rose, improving future feud rewards."


func _grade_operation(result: Dictionary) -> String:
	var ratio := float(result.get("player_power", 0.0)) / maxf(1.0, float(result.get("required_power", 1.0)))
	if not bool(result.get("victory", false)):
		return "C" if ratio >= 0.85 else "D"
	if ratio >= 1.35:
		return "S"
	if ratio >= 1.15:
		return "A"
	return "B"


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
			var report_type := String(report.get("type", ""))
			if report_type != "raid" and report_type != "operation":
				continue
			report["title"] = String(report.get("title", "Operation")).left(80)
			report["timestamp"] = maxf(0.0, float(report.get("timestamp", 0.0)))
			report["advice"] = String(report.get("advice", "")).left(300)
			reports.append(report)
			if reports.size() >= MAX_REPORTS:
				break
	changed.emit()
