class_name FactionUI
extends CanvasLayer

var faction: FactionManager
var economy: PlayerEconomy
var missions: MissionTracker

@onready var panel: PanelContainer = $Root/Panel
@onready var summary_label: Label = $Root/Panel/Margin/Scroll/VBox/Summary
@onready var name_edit: LineEdit = $Root/Panel/Margin/Scroll/VBox/CreateBox/Name
@onready var tag_edit: LineEdit = $Root/Panel/Margin/Scroll/VBox/CreateBox/Tag
@onready var create_button: Button = $Root/Panel/Margin/Scroll/VBox/CreateBox/Create
@onready var join_button: Button = $Root/Panel/Margin/Scroll/VBox/JoinPrototype
@onready var permissions_label: Label = $Root/Panel/Margin/Scroll/VBox/Permissions
@onready var daily_label: Label = $Root/Panel/Margin/Scroll/VBox/Daily
@onready var claim_daily_button: Button = $Root/Panel/Margin/Scroll/VBox/DailyButtons/ClaimDaily
@onready var claim_mastery_button: Button = $Root/Panel/Margin/Scroll/VBox/DailyButtons/ClaimMastery
@onready var members_label: Label = $Root/Panel/Margin/Scroll/VBox/Members
@onready var invite_status_label: Label = $Root/Panel/Margin/Scroll/VBox/InviteStatus
@onready var invite_button: Button = $Root/Panel/Margin/Scroll/VBox/MemberAdmin/Invite
@onready var accept_invite_button: Button = $Root/Panel/Margin/Scroll/VBox/MemberAdmin/AcceptInvite
@onready var promote_button: Button = $Root/Panel/Margin/Scroll/VBox/MemberAdmin/Promote
@onready var remove_button: Button = $Root/Panel/Margin/Scroll/VBox/MemberAdmin/Remove
@onready var research_label: Label = $Root/Panel/Margin/Scroll/VBox/Research
@onready var donate_button: Button = $Root/Panel/Margin/Scroll/VBox/Donate
@onready var research_button: Button = $Root/Panel/Margin/Scroll/VBox/UpgradeResearch
@onready var gift_button: Button = $Root/Panel/Margin/Scroll/VBox/Gift
@onready var rally_label: Label = $Root/Panel/Margin/Scroll/VBox/Rally
@onready var start_rally_button: Button = $Root/Panel/Margin/Scroll/VBox/RallyButtons/StartRally
@onready var clear_rally_button: Button = $Root/Panel/Margin/Scroll/VBox/RallyButtons/ClearRally
@onready var territory_label: Label = $Root/Panel/Margin/Scroll/VBox/Territory
@onready var capture_territory_button: Button = $Root/Panel/Margin/Scroll/VBox/CaptureTerritory
@onready var season_label: Label = $Root/Panel/Margin/Scroll/VBox/Season
@onready var rankings_label: Label = $Root/Panel/Margin/Scroll/VBox/Rankings
@onready var matchmaking_label: Label = $Root/Panel/Margin/Scroll/VBox/Matchmaking
@onready var war_label: Label = $Root/Panel/Margin/Scroll/VBox/War
@onready var war_rules_label: Label = $Root/Panel/Margin/Scroll/VBox/WarRules
@onready var war_preparation_label: Label = $Root/Panel/Margin/Scroll/VBox/WarPreparation
@onready var captain_button: Button = $Root/Panel/Margin/Scroll/VBox/WarPrepButtons/Captain
@onready var doctrine_button: Button = $Root/Panel/Margin/Scroll/VBox/WarPrepButtons/Doctrine
@onready var defense_button: Button = $Root/Panel/Margin/Scroll/VBox/WarPrepButtons/Defense
@onready var war_strategy_label: Label = $Root/Panel/Margin/Scroll/VBox/WarStrategy
@onready var muscle_button: Button = $Root/Panel/Margin/Scroll/VBox/WarPlanButtons/Muscle
@onready var convoy_button: Button = $Root/Panel/Margin/Scroll/VBox/WarPlanButtons/Convoy
@onready var intel_button: Button = $Root/Panel/Margin/Scroll/VBox/WarPlanButtons/Intel
@onready var war_attack_report_label: Label = $Root/Panel/Margin/Scroll/VBox/WarAttackReport
@onready var war_objectives_label: Label = $Root/Panel/Margin/Scroll/VBox/WarObjectives
@onready var war_participation_label: Label = $Root/Panel/Margin/Scroll/VBox/WarParticipation
@onready var war_reward_split_label: Label = $Root/Panel/Margin/Scroll/VBox/WarRewardSplit
@onready var war_debrief_label: Label = $Root/Panel/Margin/Scroll/VBox/WarDebrief
@onready var start_war_button: Button = $Root/Panel/Margin/Scroll/VBox/WarButtons/StartWar
@onready var claim_war_reward_button: Button = $Root/Panel/Margin/Scroll/VBox/WarRewardButtons/ClaimWarReward
@onready var clear_war_button: Button = $Root/Panel/Margin/Scroll/VBox/WarRewardButtons/ClearWar
@onready var leave_button: Button = $Root/Panel/Margin/Scroll/VBox/Leave


func setup(
	faction_manager: FactionManager,
	player_economy: PlayerEconomy,
	mission_tracker: MissionTracker
) -> void:
	faction = faction_manager
	economy = player_economy
	missions = mission_tracker

	faction.changed.connect(_refresh)
	economy.changed.connect(_refresh)
	missions.changed.connect(_refresh)
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/Scroll/VBox/Close.pressed.connect(_toggle)
	create_button.pressed.connect(_create)
	join_button.pressed.connect(_join)
	donate_button.pressed.connect(_donate)
	research_button.pressed.connect(_upgrade_research)
	claim_daily_button.pressed.connect(_claim_daily)
	claim_mastery_button.pressed.connect(_claim_mastery)
	gift_button.pressed.connect(_claim_gift)
	invite_button.pressed.connect(_invite)
	accept_invite_button.pressed.connect(_accept_invite)
	promote_button.pressed.connect(_promote)
	remove_button.pressed.connect(_remove)
	start_rally_button.pressed.connect(_start_rally)
	clear_rally_button.pressed.connect(_clear_rally)
	capture_territory_button.pressed.connect(_capture_territory)
	start_war_button.pressed.connect(_start_war)
	captain_button.pressed.connect(_cycle_war_captain)
	doctrine_button.pressed.connect(_cycle_war_doctrine)
	defense_button.pressed.connect(_cycle_war_defense)
	muscle_button.pressed.connect(func(): _war_attack("muscle"))
	convoy_button.pressed.connect(func(): _war_attack("convoy"))
	intel_button.pressed.connect(func(): _war_attack("intel"))
	claim_war_reward_button.pressed.connect(_claim_war_reward)
	clear_war_button.pressed.connect(_clear_war)
	leave_button.pressed.connect(_leave)
	_refresh()


func _process(_delta: float) -> void:
	if panel.visible:
		_refresh()


func _toggle() -> void:
	panel.visible = not panel.visible
	_refresh()


func _create() -> void:
	faction.create_faction(name_edit.text, tag_edit.text)
	_refresh()


func _join() -> void:
	faction.join_prototype_faction()
	_refresh()


func _donate() -> void:
	faction.donate_cash(5000, economy)
	_refresh()


func _upgrade_research() -> void:
	for research_id in ["construction_help", "raid_coordination", "territory_income"]:
		if faction.can_upgrade_research(research_id):
			faction.upgrade_research(research_id)
			break
	_refresh()


func _claim_daily() -> void:
	faction.claim_daily_reward()
	_refresh()


func _claim_mastery() -> void:
	faction.claim_daily_mastery()
	_refresh()


func _claim_gift() -> void:
	faction.claim_gift_chest()
	_refresh()


func _invite() -> void:
	faction.invite_prototype_member()
	_refresh()


func _accept_invite() -> void:
	faction.accept_next_prototype_invite()
	_refresh()


func _promote() -> void:
	faction.promote_prototype_member()
	_refresh()


func _remove() -> void:
	faction.remove_prototype_member()
	_refresh()


func _start_rally() -> void:
	var target_id := faction.get_next_territory_id()
	if target_id.is_empty():
		target_id = "faction_war_front"
	faction.start_rally(target_id, "Faction Territory Push")
	_refresh()


func _clear_rally() -> void:
	faction.clear_rally()
	_refresh()


func _capture_territory() -> void:
	faction.capture_next_territory()
	_refresh()


func _cycle_war_captain() -> void:
	faction.cycle_war_captain()
	_refresh()


func _cycle_war_doctrine() -> void:
	faction.cycle_war_doctrine()
	_refresh()


func _cycle_war_defense() -> void:
	faction.cycle_war_defense()
	_refresh()


func _start_war() -> void:
	faction.start_prototype_war()
	_refresh()


func _war_attack(strategy_id: String) -> void:
	faction.perform_war_attack(strategy_id)
	_refresh()


func _claim_war_reward() -> void:
	faction.claim_war_reward()
	_refresh()


func _clear_war() -> void:
	faction.clear_completed_war()
	_refresh()


func _leave() -> void:
	faction.leave_faction()
	_refresh()


func _refresh() -> void:
	if faction == null or economy == null:
		return

	$Root/Shortcut.text = "Faction" if not faction.has_faction() else "[%s] %s" % [faction.faction_tag, faction.faction_name]
	if not panel.visible:
		return

	var faction_unlocked := bool(missions.missions["chapter_2_complete"]["completed"])
	summary_label.text = faction.get_summary() if faction_unlocked else "Faction unlocks after Chapter 2. Build your Family and defeat Harbor + Midtown first."

	var has := faction.has_faction()
	for node in [
		permissions_label,
		daily_label,
		$Root/Panel/Margin/Scroll/VBox/DailyButtons,
		members_label,
		$Root/Panel/Margin/Scroll/VBox/MemberAdmin,
		invite_status_label,
		research_label,
		donate_button,
		research_button,
		gift_button,
		rally_label,
		$Root/Panel/Margin/Scroll/VBox/RallyButtons,
		territory_label,
		capture_territory_button,
		season_label,
		rankings_label,
		matchmaking_label,
		war_label,
		war_rules_label,
		war_preparation_label,
		$Root/Panel/Margin/Scroll/VBox/WarPrepButtons,
		war_strategy_label,
		$Root/Panel/Margin/Scroll/VBox/WarPlanButtons,
		war_attack_report_label,
		war_objectives_label,
		war_participation_label,
		war_reward_split_label,
		war_debrief_label,
		$Root/Panel/Margin/Scroll/VBox/WarButtons,
		$Root/Panel/Margin/Scroll/VBox/WarRewardButtons,
		leave_button
	]:
		node.visible = has

	$Root/Panel/Margin/Scroll/VBox/CreateBox.visible = not has and faction_unlocked
	join_button.visible = not has and faction_unlocked

	if not has:
		return

	permissions_label.text = "ROLE PERMISSIONS\n%s" % faction.get_permissions_summary()

	var daily := faction.get_daily_status()
	daily_label.text = "DAILY FACTION OPERATIONS • complete %d of %d\n%s" % [
		int(daily["required"]),
		int(daily["total"]),
		"\n".join(faction.get_daily_lines())
	]
	claim_daily_button.text = "Daily Reward Claimed" if bool(daily["claimed"]) else "Claim %d/%d Reward" % [int(daily["required"]), int(daily["total"])]
	claim_daily_button.disabled = not bool(daily["claimable"])
	claim_mastery_button.text = "Mastery Claimed" if bool(daily["mastery_claimed"]) else "Claim 4/4 Mastery"
	claim_mastery_button.disabled = not bool(daily["mastery_claimable"])

	members_label.text = "MEMBERS & RANKS\n" + "\n".join(faction.get_member_lines())
	invite_status_label.text = faction.get_invite_summary()
	var can_manage := faction.can_manage_members()
	invite_button.disabled = not can_manage or faction.members.size() + faction.pending_invites.size() >= faction.get_member_limit()
	accept_invite_button.disabled = not can_manage or faction.pending_invites.is_empty()
	promote_button.disabled = not can_manage
	remove_button.disabled = not can_manage

	research_label.text = "FACTION RESEARCH\n" + "\n".join(faction.get_research_summary())
	donate_button.text = "Donate $5,000 to Faction"
	donate_button.disabled = economy.cash < 5000

	var next_research := ""
	for research_id in ["construction_help", "raid_coordination", "territory_income"]:
		if faction.can_upgrade_research(research_id):
			next_research = research_id
			break

	if next_research.is_empty():
		research_button.text = "Research Upgrade Unavailable"
		research_button.disabled = true
	else:
		research_button.text = "Upgrade %s — $%s Treasury" % [
			next_research.replace("_", " ").capitalize(),
			_format_number(faction.get_research_cost(next_research))
		]
		research_button.disabled = false

	gift_button.text = "Claim Faction Gift (%d)" % faction.gift_charges
	gift_button.disabled = faction.gift_charges <= 0

	rally_label.text = "FACTION RALLY\n%s" % faction.get_rally_summary()
	start_rally_button.disabled = not faction.can_start_rally() or not faction.active_rally.is_empty()
	clear_rally_button.disabled = faction.active_rally.is_empty()

	territory_label.text = "FACTION TERRITORY OBJECTIVES\n" + "\n".join(faction.get_territory_lines())
	var next_territory := faction.get_next_territory_id()
	capture_territory_button.text = "All Territory Objectives Held" if next_territory.is_empty() else "Capture Next Objective"
	capture_territory_button.disabled = not faction.can_capture_next_territory()

	season_label.text = "SEASON\n%s" % faction.get_season_summary()
	rankings_label.text = "FACTION RANKINGS\n" + "\n".join(faction.get_ranking_lines())

	var candidates := faction.get_matchmaking_candidates()
	var matchmaking_lines := PackedStringArray()
	for candidate in candidates:
		matchmaking_lines.append("%s • Rating %d • %d members" % [
			String(candidate["name"]),
			int(candidate["rating"]),
			int(candidate["members"])
		])
	matchmaking_label.text = "WAR MATCHMAKING PREVIEW • your rating %d\n%s" % [
		faction.get_matchmaking_rating(),
		"\n".join(matchmaking_lines)
	]

	war_label.text = "FACTION WAR\n%s" % faction.get_war_summary()
	war_rules_label.text = "WAR RULES\n" + "\n".join(faction.get_war_rules_lines())
	war_preparation_label.text = "WAR PREPARATION\n%s\n%s" % [
		faction.get_war_preparation_summary(),
		faction.get_war_doctrine_summary()
	]
	var prep_locked := not faction.active_war.is_empty()
	captain_button.text = "Captain"
	doctrine_button.text = "Doctrine"
	defense_button.text = "Defense"
	captain_button.disabled = prep_locked or not faction.can_start_war()
	doctrine_button.disabled = prep_locked or not faction.can_start_war()
	defense_button.disabled = prep_locked or not faction.can_start_war()

	war_strategy_label.text = "WAR STRATEGY\nEnemy stance: %s\n%s" % [
		faction.get_current_war_defense().to_upper() if not faction.active_war.is_empty() else "—",
		"\n".join(faction.get_war_strategy_lines())
	]
	var attack_history := faction.get_war_attack_history_lines()
	war_attack_report_label.text = "WAR ATTACK REPORT\n%s%s" % [
		faction.get_last_war_attack_summary(),
		"\n" + "\n".join(attack_history) if not attack_history.is_empty() else ""
	]
	var objective_lines := faction.get_war_objective_lines()
	war_objectives_label.text = "SHARED WAR OBJECTIVES\n%s" % ("\n".join(objective_lines) if not objective_lines.is_empty() else "Start a Faction War to reveal shared objectives.")
	var participation_lines := faction.get_war_participation_lines()
	war_participation_label.text = "WAR PARTICIPATION\n%s" % ("\n".join(participation_lines) if not participation_lines.is_empty() else "Participation begins when the war starts.")
	war_reward_split_label.text = "PARTICIPATION REWARD\n%s" % "\n".join(faction.get_war_reward_split_lines())
	war_debrief_label.text = "WAR ROOM • LAST 10 COMPLETED WARS\n%s" % "\n\n".join(faction.get_war_debrief_lines())
	start_war_button.disabled = not faction.can_start_war() or not faction.active_war.is_empty()
	var can_attack := (
		not faction.active_war.is_empty()
		and String(faction.active_war.get("status", "")) == "active"
		and int(faction.active_war.get("attacks_remaining", 0)) > 0
	)
	muscle_button.disabled = not can_attack
	convoy_button.disabled = not can_attack
	intel_button.disabled = not can_attack
	claim_war_reward_button.disabled = not faction.can_claim_war_reward()
	clear_war_button.disabled = (
		faction.active_war.is_empty()
		or String(faction.active_war.get("status", "")) != "complete"
		or not faction.war_reward_claimed
	)

	leave_button.disabled = faction.get_local_role() == FactionManager.ROLE_LEADER and faction.members.size() > 1


func _format_number(value: int) -> String:
	var raw := str(value)
	var output := ""
	while raw.length() > 3:
		output = "," + raw.right(3) + output
		raw = raw.left(raw.length() - 3)
	return raw + output
