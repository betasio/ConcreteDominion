class_name FactionUI
extends CanvasLayer

var faction: FactionManager
var economy: PlayerEconomy

@onready var panel: PanelContainer = $Root/Panel
@onready var summary_label: Label = $Root/Panel/Margin/VBox/Summary
@onready var name_edit: LineEdit = $Root/Panel/Margin/VBox/CreateBox/Name
@onready var tag_edit: LineEdit = $Root/Panel/Margin/VBox/CreateBox/Tag
@onready var create_button: Button = $Root/Panel/Margin/VBox/CreateBox/Create
@onready var join_button: Button = $Root/Panel/Margin/VBox/JoinPrototype
@onready var members_label: Label = $Root/Panel/Margin/VBox/Members
@onready var research_label: Label = $Root/Panel/Margin/VBox/Research
@onready var donate_button: Button = $Root/Panel/Margin/VBox/Donate
@onready var research_button: Button = $Root/Panel/Margin/VBox/UpgradeResearch
@onready var leave_button: Button = $Root/Panel/Margin/VBox/Leave


func setup(faction_manager: FactionManager, player_economy: PlayerEconomy) -> void:
	faction = faction_manager
	economy = player_economy

	faction.changed.connect(_refresh)
	economy.changed.connect(_refresh)
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle)
	create_button.pressed.connect(_create)
	join_button.pressed.connect(_join)
	donate_button.pressed.connect(_donate)
	research_button.pressed.connect(_upgrade_research)
	leave_button.pressed.connect(_leave)
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


func _leave() -> void:
	faction.leave_faction()
	_refresh()


func _refresh() -> void:
	if faction == null or economy == null:
		return

	$Root/Shortcut.text = "Faction" if not faction.has_faction() else "[%s] %s" % [faction.faction_tag, faction.faction_name]
	summary_label.text = faction.get_summary()

	var has := faction.has_faction()
	$Root/Panel/Margin/VBox/CreateBox.visible = not has
	join_button.visible = not has
	members_label.visible = has
	research_label.visible = has
	donate_button.visible = has
	research_button.visible = has
	leave_button.visible = has

	if not has:
		members_label.text = ""
		research_label.text = ""
		return

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

	leave_button.disabled = faction.get_local_role() == FactionManager.ROLE_LEADER and faction.members.size() > 1


func _format_number(value: int) -> String:
	var raw := str(value)
	var output := ""
	while raw.length() > 3:
		output = "," + raw.right(3) + output
		raw = raw.left(raw.length() - 3)
	return raw + output
