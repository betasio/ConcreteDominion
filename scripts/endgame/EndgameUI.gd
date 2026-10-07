class_name EndgameUI
extends CanvasLayer

var endgame: EndgameManager
var faction: FactionManager

@onready var panel: PanelContainer = $Root/Panel
@onready var summary: Label = $Root/Panel/Margin/VBox/Summary
@onready var contracts: Label = $Root/Panel/Margin/VBox/Contracts
@onready var rival_button: Button = $Root/Panel/Margin/VBox/RivalOperation
@onready var boss_button: Button = $Root/Panel/Margin/VBox/BossRematch
@onready var war_button: Button = $Root/Panel/Margin/VBox/FactionWar
@onready var claim_button: Button = $Root/Panel/Margin/VBox/ClaimCache
@onready var mastery_button: Button = $Root/Panel/Margin/VBox/ClaimMastery


func setup(endgame_manager: EndgameManager, faction_manager: FactionManager) -> void:
	endgame = endgame_manager
	faction = faction_manager
	endgame.changed.connect(_refresh)
	faction.changed.connect(_refresh)
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle)
	rival_button.pressed.connect(_launch_rival_operation)
	boss_button.pressed.connect(_launch_boss_rematch)
	war_button.pressed.connect(_open_faction_war)
	claim_button.pressed.connect(_claim_cache)
	mastery_button.pressed.connect(_claim_mastery)
	_refresh()


func _process(_delta: float) -> void:
	if panel.visible:
		_refresh()


func _toggle() -> void:
	panel.visible = not panel.visible
	_refresh()


func _launch_rival_operation() -> void:
	endgame.launch_rival_operation()
	_refresh()


func _launch_boss_rematch() -> void:
	endgame.launch_boss_rematch()
	_refresh()


func _open_faction_war() -> void:
	if faction.active_war.is_empty():
		faction.start_prototype_war()
	_refresh()


func _claim_cache() -> void:
	endgame.claim_weekly_cache()
	_refresh()


func _claim_mastery() -> void:
	endgame.claim_mastery()
	_refresh()


func _refresh() -> void:
	if endgame == null or faction == null:
		return
	var status := endgame.get_status()
	var unlocked := bool(status["unlocked"])

	$Root/Shortcut.text = "Dominion" if unlocked else "Dominion • Locked"
	summary.text = (
		"DOMINION RANK • %s\n%d Marks • %d weekly cycle(s) completed\nMain cache requires %d of 3 tracks."
		% [
			String(status["rank"]),
			int(status["dominion_marks"]),
			int(status["cycles_completed"]),
			int(status["required_tracks"])
		]
	) if unlocked else "DOMINION LOCKED\nComplete Chapter 6 • Roads of Iron to unlock repeatable citywide operations."

	contracts.text = "WEEKLY DOMINION CONTRACTS\n" + "\n".join(endgame.get_contract_lines())
	contracts.visible = unlocked
	rival_button.visible = unlocked
	boss_button.visible = unlocked
	war_button.visible = unlocked
	claim_button.visible = unlocked
	mastery_button.visible = unlocked
	$Root/Panel/Margin/VBox/Reward.visible = unlocked

	if not unlocked:
		return

	rival_button.disabled = not endgame.world_control.active_patrol.is_empty()
	boss_button.disabled = not endgame.world_control.active_patrol.is_empty()
	war_button.text = "Open Faction War" if faction.active_war.is_empty() else "Faction War Active"
	war_button.disabled = not faction.has_faction() or not faction.can_start_war() or not faction.active_war.is_empty()
	claim_button.text = "Dominion Cache Claimed" if bool(status["claimed"]) else "Claim 2/3 Dominion Cache"
	claim_button.disabled = not bool(status["claimable"])
	mastery_button.text = "Mastery Claimed" if bool(status["mastery_claimed"]) else "Claim 3/3 Mastery Bonus"
	mastery_button.disabled = not bool(status["mastery_claimable"])
