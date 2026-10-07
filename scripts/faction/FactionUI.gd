class_name FactionUI
extends CanvasLayer

var faction: FactionManager
var economy: PlayerEconomy

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
@onready var research_label: Label = $Root/Panel/Margin/Scroll/VBox/Research
@onready var donate_button: Button = $Root/Panel/Margin/Scroll/VBox/Donate
@onready var research_button: Button = $Root/Panel/Margin/Scroll/VBox/UpgradeResearch
@onready var gift_button: Button = $Root/Panel/Margin/Scroll/VBox/Gift
@onready var rally_label: Label = $Root/Panel/Margin/Scroll/VBox/Rally
@onready var start_rally_button: Button = $Root/Panel/Margin/Scroll/VBox/RallyButtons/StartRally
@onready var clear_rally_button: Button = $Root/Panel/Margin/Scroll/VBox/RallyButtons/ClearRally
@onready var war_label: Label = $Root/Panel/Margin/Scroll/VBox/War
@onready var war_rules_label: Label = $Root/Panel/Margin/Scroll/VBox/WarRules
@onready var start_war_button: Button = $Root/Panel/Margin/Scroll/VBox/WarButtons/StartWar
@onready var war_attack_button: Button = $Root/Panel/Margin/Scroll/VBox/WarButtons/WarAttack
@onready var leave_button: Button = $Root/Panel/Margin/Scroll/VBox/Leave


func setup(faction_manager: FactionManager, player_economy: PlayerEconomy) -> void:
	faction = faction_manager
	economy = player_economy

	faction.changed.connect(_refresh)
	economy.changed.connect(_refresh)
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/Scroll/VBox/Close.pressed.connect(_toggle)
	create_button.pressed.connect(_create)
	join_button.pressed.connect(_join)
	donate_button.pressed.connect(_donate)
	research_button.pressed.connect(_upgrade_research)
	claim_daily_button.pressed.connect(_claim_daily)
	claim_mastery_button.pressed.connect(_claim_mastery)
	gift_button.pressed.connect(_claim_gift)
	start_rally_button.pressed.connect(_start_rally)
	clear_rally_button.pressed.connect(_clear_rally)
	start_war_button.pressed.connect(_start_war)
	war_attack_button.pressed.connect(_war_attack)
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


func _start_rally() -> void:
	faction.start_rally("faction_war_front", "Faction War Front")
	_refresh()


func _clear_rally() -> void:
	faction.clear_rally()
	_refresh()


func _start_war() -> void:
	faction.start_prototype_war()
	_refresh()


func _war_attack() -> void:
	faction.perform_prototype_war_attack()
	_refresh()


func _leave() -> void:
	faction.leave_faction()
	_refresh()


func _refresh() -> void:
	if faction == null or economy == null:
		return

	$Root/Shortcut.text = "Faction" if not faction.has_faction() else "[%s] %s" % [faction.faction_tag, faction.faction_name]
	summary_label.text = faction.get_summary()

	var has := faction.has_faction()
	$Root/Panel/Margin/Scroll/VBox/CreateBox.visible = not has
	join_button.visible = not has
	permissions_label.visible = has
	daily_label.visible = has
	$Root/Panel/Margin/Scroll/VBox/DailyButtons.visible = has
	members_label.visible = has
	research_label.visible = has
	donate_button.visible = has
	research_button.visible = has
	gift_button.visible = has
	rally_label.visible = has
	$Root/Panel/Margin/Scroll/VBox/RallyButtons.visible = has
	war_label.visible = has
	war_rules_label.visible = has
	$Root/Panel/Margin/Scroll/VBox/WarButtons.visible = has
	leave_button.visible = has

	if not has:
		permissions_label.text = ""
		daily_label.text = ""
		members_label.text = ""
		research_label.text = ""
		rally_label.text = ""
		war_label.text = ""
		war_rules_label.text = ""
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

	war_label.text = "FACTION WAR\n%s" % faction.get_war_summary()
	war_rules_label.text = "WAR RULES\n" + "\n".join(faction.get_war_rules_lines())
	start_war_button.disabled = not faction.can_start_war() or not faction.active_war.is_empty()
	war_attack_button.disabled = (
		faction.active_war.is_empty()
		or String(faction.active_war.get("status", "")) != "active"
		or int(faction.active_war.get("attacks_remaining", 0)) <= 0
	)

	leave_button.disabled = faction.get_local_role() == FactionManager.ROLE_LEADER and faction.members.size() > 1


func _format_number(value: int) -> String:
	var raw := str(value)
	var output := ""
	while raw.length() > 3:
		output = "," + raw.right(3) + output
		raw = raw.left(raw.length() - 3)
	return raw + output
