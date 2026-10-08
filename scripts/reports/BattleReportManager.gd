class_name BattleReportManager
extends Node

signal changed
signal report_added(report: Dictionary)

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
		"rivalry_after":int(result.get("rivalry_after", 0)),
		"season_points":int(endgame.get_status().get("season_points", 0)) if endgame != null else 0,
		"advice":_build_operation_advice(result)
	}
	_add_report(report)


func _add_report(report: Dictionary) -> void:
	reports.push_front(report.duplicate(true))
	while reports.size() > MAX_REPORTS:
		reports.pop_back()
	report_added.emit(reports[0].duplicate(true))
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
		var report := reports[i]
		lines.append("#%02d • %s • %s • %s" % [
			i + 1,
			"WIN" if bool(report.get("victory", false)) else "LOSS",
			String(report.get("grade", "D")),
			String(report.get("title", "Operation"))
		])
	if lines.is_empty():
		lines.append("No operation reports yet.")
	return lines


func can_rematch(index: int) -> bool:
	var report := get_report(index)
	if report.is_empty():
		return false
	var target_id := String(report.get("target_id", ""))
	if String(report.get("type", "")) == "raid":
		if raid_battle == null or raid_battle.is_active() or city_map == null:
			return false
		var target: RaidTarget = city_map.get_raid_target_by_id(target_id)
		return target != null and target.is_available() and target.is_unlocked()

	if world_control == null or not world_control.active_patrol.is_empty():
		return false
	if not world_control.is_discovered(target_id):
		return false
	if bool(report.get("dominion_boss", false)):
		return world_control.family_rules != null
	return world_control.can_launch_family_operation(target_id, String(report.get("encounter_type", "roadblock")))


func rematch(index: int) -> bool:
	if not can_rematch(index):
		return false
	var report := get_report(index)
	var target_id := String(report.get("target_id", ""))
	if String(report.get("type", "")) == "raid":
		var target: RaidTarget = city_map.get_raid_target_by_id(target_id)
		return raid_battle.start_battle(
			target,
			int(report.get("local_drivers", 0)),
			int(report.get("local_spies", 0))
		)

	if bool(report.get("dominion_boss", false)):
		return world_control.launch_boss_rematch(target_id)
	return world_control.launch_family_operation(target_id, String(report.get("encounter_type", "roadblock")))


func focus_target(index: int) -> bool:
	var report := get_report(index)
	if report.is_empty() or city_map == null:
		return false
	var target_id := String(report.get("target_id", ""))
	var target: RaidTarget = city_map.get_raid_target_by_id(target_id)
	if target == null:
		return false
	city_map.focus_raid_target(target)
	return true


func _build_raid_advice(result: Dictionary) -> String:
	var damage := float(result.get("damage", 0.0))
	var hp := maxf(1.0, float(result.get("target_hp", 1.0)))
	var ratio := damage / hp
	if bool(result.get("victory", false)):
		if ratio >= 1.35:
			return "Dominant clear. This setup is safe to repeat unless the target scales up."
		return "Clean win. Keep the plan; stronger counter-role support can improve the grade."
	if not bool(result.get("weakness_matched", false)):
		return "Counter missed. Bring %s support before retrying." % String(result.get("weakness_role", "the recommended role"))
	if ratio >= 0.85:
		return "Close loss. Keep the counter and improve equipment, troop power, or support before revenge."
	return "Power gap is too large. Upgrade the squad before spending another attempt."


func _build_operation_advice(result: Dictionary) -> String:
	var player := float(result.get("player_power", 0.0))
	var required := maxf(1.0, float(result.get("required_power", 1.0)))
	var ratio := player / required
	var role := String(result.get("role", "Enforcer"))
	if bool(result.get("victory", false)):
		if bool(result.get("dominion_boss", false)):
			return "Boss pattern broken. Repeat while this Family remains strategically valuable."
		return "Operation secured. %s strength is sufficient for this threat level." % role
	if ratio >= 0.85:
		return "Near miss. Add roughly %d%% more %s power and strike again." % [ceili((1.0 - ratio) * 100.0), role]
	return "This route is overmatched. Build %s strength or choose another operation first." % role


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
			if not raw_report is Dictionary:
				continue
			var report: Dictionary = raw_report.duplicate(true)
			var report_type := String(report.get("type", ""))
			if report_type != "raid" and report_type != "operation":
				continue
			report["title"] = String(report.get("title", "Operation")).left(80)
			report["advice"] = String(report.get("advice", "")).left(240)
			reports.append(report)
			if reports.size() >= MAX_REPORTS:
				break
	changed.emit()
