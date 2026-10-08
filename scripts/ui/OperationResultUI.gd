class_name OperationResultUI
extends CanvasLayer

var raid_battle: RaidBattle
var world_control: WorldControlManager
var endgame: EndgameManager
var presentation: PresentationCatalog
var reports: BattleReportManager
var history_index := 0

@onready var reports_button: Button = $Root/Reports
@onready var panel: PanelContainer = $Root/Panel
@onready var title: Label = $Root/Panel/Margin/VBox/Title
@onready var art: TextureRect = $Root/Panel/Margin/VBox/Art
@onready var identity: Label = $Root/Panel/Margin/VBox/Identity
@onready var grade: Label = $Root/Panel/Margin/VBox/Grade
@onready var combat: Label = $Root/Panel/Margin/VBox/Combat
@onready var rewards: Label = $Root/Panel/Margin/VBox/Rewards
@onready var advice: Label = $Root/Panel/Margin/VBox/Advice
@onready var progress: Label = $Root/Panel/Margin/VBox/Progress
@onready var newer_button: Button = $Root/Panel/Margin/VBox/HistoryNav/Newer
@onready var history_status: Label = $Root/Panel/Margin/VBox/HistoryNav/Status
@onready var older_button: Button = $Root/Panel/Margin/VBox/HistoryNav/Older
@onready var rematch_button: Button = $Root/Panel/Margin/VBox/Rematch
@onready var close_button: Button = $Root/Panel/Margin/VBox/Close


func setup(
	battle: RaidBattle,
	control: WorldControlManager,
	endgame_manager: EndgameManager,
	presentation_catalog: PresentationCatalog,
	report_manager: BattleReportManager
) -> void:
	raid_battle = battle
	world_control = control
	endgame = endgame_manager
	presentation = presentation_catalog
	reports = report_manager

	reports.report_recorded.connect(_on_report_recorded)
	reports.changed.connect(_refresh_history_controls)
	reports.rematch_started.connect(_on_rematch_started)
	reports.rematch_blocked.connect(_on_rematch_blocked)

	reports_button.pressed.connect(_open_history)
	newer_button.pressed.connect(_show_newer)
	older_button.pressed.connect(_show_older)
	rematch_button.pressed.connect(_rematch_current)
	close_button.pressed.connect(_close)

	panel.visible = false
	_refresh_history_controls()


func _on_report_recorded(_report: Dictionary) -> void:
	history_index = 0
	_show_history_report()


func _open_history() -> void:
	if reports == null or reports.get_report_count() <= 0:
		return
	history_index = clampi(history_index, 0, reports.get_report_count() - 1)
	_show_history_report()


func _show_newer() -> void:
	if reports == null:
		return
	history_index = maxi(0, history_index - 1)
	_show_history_report()


func _show_older() -> void:
	if reports == null or reports.get_report_count() <= 0:
		return
	history_index = mini(reports.get_report_count() - 1, history_index + 1)
	_show_history_report()


func _show_history_report() -> void:
	if reports == null:
		return
	var report := reports.get_report(history_index)
	if report.is_empty():
		return
	_show_report(report)


func _show_report(report: Dictionary) -> void:
	if String(report.get("source", "")) == "family_operation":
		_show_family_operation_report(report)
	else:
		_show_raid_report(report)

	advice.text = "TACTICAL READ\n%s" % reports.get_advice(report)
	_refresh_history_controls()


func _show_raid_report(result: Dictionary) -> void:
	if result.is_empty():
		return

	var victory := bool(result.get("victory", false))
	var target_id := String(result.get("target_id", ""))
	title.text = "OPERATION WON" if victory else "OPERATION FAILED"
	identity.text = "%s%s" % [
		String(result.get("title", result.get("target_name", "Raid Target"))).to_upper(),
		" • %s" % String(result.get("family", "")).to_upper() if not String(result.get("family", "")).is_empty() else ""
	]
	grade.text = "COMBAT GRADE • %s" % String(result.get("grade", "D"))
	combat.text = "Damage %.0f / %.0f HP\nPlan: %s • Counter %s • Support +%d%%\nInjuries: %s" % [
		float(result.get("damage", 0.0)),
		float(result.get("target_hp", 0.0)),
		String(result.get("preset", "Balanced")),
		"MATCHED" if bool(result.get("weakness_matched", false)) else "MISSED",
		roundi(float(result.get("support_bonus", 0.0)) * 100.0),
		_get_raid_injury_line(result)
	]
	rewards.text = "REWARDS\n%s" % _get_raid_reward_line(result)
	progress.text = _get_rival_progress_line(target_id)
	_apply_art(target_id, true)
	_present()


func _show_family_operation_report(result: Dictionary) -> void:
	if result.is_empty():
		return

	var victory := bool(result.get("victory", false))
	var target_id := String(result.get("target_id", result.get("district_id", "")))
	var boss := bool(result.get("dominion_boss", false))
	title.text = ("BOSS REMATCH WON" if victory else "BOSS REMATCH LOST") if boss else ("RIVAL OPERATION WON" if victory else "RIVAL OPERATION HELD")
	identity.text = "%s\n%s%s" % [
		String(result.get("title", result.get("district_name", target_id))).to_upper(),
		String(result.get("family", "Rival Family")).to_upper(),
		" • %s" % String(result.get("boss_name", "")).to_upper() if boss and not String(result.get("boss_name", "")).is_empty() else ""
	]

	var player_power := float(result.get("player_power", 0.0))
	var required_power := float(result.get("required_power", 1.0))
	grade.text = "OPERATION GRADE • %s" % String(result.get("grade", _grade_from_ratio(player_power / maxf(1.0, required_power), victory)))
	combat.text = "%s power %.0f / %.0f required\nEncounter: %s\nRivalry: %d → %d • %s" % [
		String(result.get("role", "Enforcer")),
		player_power,
		required_power,
		String(result.get("encounter_type", "roadblock")).replace("_", " ").capitalize(),
		int(result.get("rivalry_before", 0)),
		int(result.get("rivalry_after", 0)),
		String(result.get("rivalry_label", world_control.get_rivalry_label(target_id)))
	]
	rewards.text = "REWARDS\n%s" % _get_operation_reward_line(result)
	progress.text = _get_dominion_progress_line(target_id, victory)
	_apply_art(target_id, boss)
	_present()


func _rematch_current() -> void:
	if reports == null:
		return
	if reports.rematch(history_index):
		panel.visible = false
	else:
		_refresh_history_controls()


func _on_rematch_started(_report: Dictionary) -> void:
	panel.visible = false


func _on_rematch_blocked(reason: String) -> void:
	rematch_button.text = reason
	rematch_button.disabled = true


func _refresh_history_controls() -> void:
	if reports == null:
		reports_button.text = "Battle Reports"
		reports_button.disabled = true
		return

	var count := reports.get_report_count()
	reports_button.text = "Battle Reports (%d)" % count
	reports_button.disabled = count <= 0

	if count <= 0:
		history_status.text = "No Reports"
		newer_button.disabled = true
		older_button.disabled = true
		rematch_button.disabled = true
		rematch_button.text = "Rematch"
		return

	history_index = clampi(history_index, 0, count - 1)
	history_status.text = "Report %d/%d" % [history_index + 1, count]
	newer_button.disabled = history_index <= 0
	older_button.disabled = history_index >= count - 1

	var report := reports.get_report(history_index)
	var status: Dictionary = reports.get_rematch_status(history_index)
	rematch_button.disabled = not bool(status.get("ok", false))
	if rematch_button.disabled:
		rematch_button.text = String(status.get("reason", "Rematch unavailable"))
	else:
		rematch_button.text = "Revenge" if not bool(report.get("victory", false)) else "Rematch"


func _get_raid_reward_line(result: Dictionary) -> String:
	if not bool(result.get("victory", false)):
		return "No cash payout • regroup and adjust the counter-role."
	var pieces := PackedStringArray([
		"$%s Cash" % _format_number(int(result.get("cash_reward", result.get("local_cash_reward", 0)))),
		"%d XP" % int(result.get("xp_reward", 0))
	])
	var awarded_loot = result.get("loot", {})
	if awarded_loot is Dictionary:
		for item_name in awarded_loot.keys():
			pieces.append("%s x%d" % [String(item_name), int(awarded_loot[item_name])])
	return " • ".join(pieces)


func _get_operation_reward_line(result: Dictionary) -> String:
	if not bool(result.get("victory", false)):
		return "No payout • recover the specialist before another attempt."
	var pieces := PackedStringArray(["$%s Cash" % _format_number(int(result.get("cash_reward", 0)))])
	var awarded_loot = result.get("loot", {})
	if awarded_loot is Dictionary:
		for item_name in awarded_loot.keys():
			pieces.append("%s x%d" % [String(item_name), int(awarded_loot[item_name])])
	return " • ".join(pieces)


func _get_raid_injury_line(result: Dictionary) -> String:
	var total := int(result.get("wounded_enforcers", 0)) + int(result.get("wounded_drivers", 0)) + int(result.get("wounded_spies", 0))
	if total <= 0:
		return "None"
	return "%d wounded • %s" % [total, String(result.get("injury_severity", "Standard"))]


func _get_rival_progress_line(target_id: String) -> String:
	if target_id.is_empty() or not world_control.districts.has(target_id):
		return "BATTLE REPORT • contribution and reward split finalized."
	return "CITY CONTROL\n%s • Rivalry %s %d/10 • Future feud reward +%d%%" % [
		world_control.get_rival_faction(target_id),
		world_control.get_rivalry_label(target_id),
		world_control.get_rivalry_score(target_id),
		roundi((world_control.get_rivalry_reward_multiplier(target_id) - 1.0) * 100.0)
	]


func _get_dominion_progress_line(target_id: String, victory: bool) -> String:
	if endgame == null or not endgame.is_unlocked():
		return _get_rival_progress_line(target_id)
	var status := endgame.get_status()
	var modifier := endgame.get_current_modifier()
	var featured := target_id == String(modifier.get("district_id", ""))
	var featured_note := " • FEATURED CITY BONUS" if victory and featured else ""
	return "DOMINION\n%s • %d seasonal influence • %d/%d weekly tracks%s" % [
		String(status.get("season_tier", "BRONZE")),
		int(status.get("season_points", 0)),
		int(status.get("completed_tracks", 0)),
		3,
		featured_note
	]


func _apply_art(target_id: String, boss_focus: bool) -> void:
	art.texture = null
	if presentation == null:
		return
	match target_id:
		"northside_hq":
			art.texture = presentation.get_campaign_art("darius" if boss_focus else "northside")
		"casino_vault", "financial_tower":
			art.texture = presentation.get_campaign_art("celeste" if boss_focus else "casino")
		"industrial_depot":
			art.texture = presentation.get_character_portrait("driver")
		"midtown_exchange":
			art.texture = presentation.get_character_portrait("spy")
		_:
			art.texture = presentation.get_texture("raid_target")


func _grade_from_ratio(ratio: float, victory: bool) -> String:
	if not victory:
		return "C" if ratio >= 0.85 else "D"
	if ratio >= 1.35:
		return "S"
	if ratio >= 1.15:
		return "A"
	return "B"


func _present() -> void:
	panel.visible = true
	close_button.grab_focus.call_deferred()


func _close() -> void:
	panel.visible = false


func _format_number(value: int) -> String:
	var raw := str(value)
	var output := ""
	while raw.length() > 3:
		output = "," + raw.right(3) + output
		raw = raw.left(raw.length() - 3)
	return raw + output
