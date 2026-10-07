class_name RetentionUI
extends CanvasLayer

var retention: RetentionManager
var text_catalog: LocalizedText

@onready var shortcut: Button = $Root/Shortcut
@onready var panel: PanelContainer = $Root/Panel
@onready var login_label: Label = $Root/Panel/Margin/VBox/Login
@onready var login_button: Button = $Root/Panel/Margin/VBox/ClaimLogin
@onready var comeback_button: Button = $Root/Panel/Margin/VBox/ClaimComeback
@onready var daily_label: Label = $Root/Panel/Margin/VBox/Daily
@onready var daily_button: Button = $Root/Panel/Margin/VBox/ClaimDaily
@onready var weekly_label: Label = $Root/Panel/Margin/VBox/Weekly
@onready var weekly_button: Button = $Root/Panel/Margin/VBox/ClaimWeekly
@onready var street_cache_button: Button = $Root/Panel/Margin/VBox/StreetCache
@onready var syndicate_crate_button: Button = $Root/Panel/Margin/VBox/SyndicateCrate
@onready var achievements_label: Label = $Root/Panel/Margin/VBox/Achievements
@onready var tutorial_label: Label = $Root/TutorialBanner/Label


func setup(retention_manager: RetentionManager, localized_text: LocalizedText) -> void:
	retention = retention_manager
	text_catalog = localized_text
	$Root/Panel/Margin/VBox/Close.text = text_catalog.text("UI_CLOSE")
	retention.changed.connect(_refresh)

	shortcut.pressed.connect(_toggle_panel)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle_panel)
	login_button.pressed.connect(_claim_login)
	comeback_button.pressed.connect(_claim_comeback)
	daily_button.pressed.connect(_claim_daily)
	weekly_button.pressed.connect(_claim_weekly)
	street_cache_button.pressed.connect(_craft_street_cache)
	syndicate_crate_button.pressed.connect(_craft_syndicate_crate)

	_refresh()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	_refresh()


func _claim_login() -> void:
	retention.claim_login_reward()
	_refresh()


func _claim_comeback() -> void:
	retention.claim_comeback_reward()
	_refresh()


func _claim_daily() -> void:
	var daily := retention.get_daily_status()
	if not bool(daily["claimed"]):
		retention.claim_daily_objective_reward()
	elif not bool(daily["mastery_claimed"]):
		retention.claim_daily_mastery_reward()
	_refresh()


func _claim_weekly() -> void:
	var weekly := retention.get_weekly_status()
	if not bool(weekly["claimed"]):
		retention.claim_weekly_objective_reward()
	elif not bool(weekly["mastery_claimed"]):
		retention.claim_weekly_mastery_reward()
	_refresh()


func _craft_street_cache() -> void:
	retention.craft_street_cache()
	_refresh()


func _craft_syndicate_crate() -> void:
	retention.craft_syndicate_crate()
	_refresh()


func _refresh() -> void:
	if retention == null:
		return

	var daily := retention.get_daily_status()
	var weekly := retention.get_weekly_status()
	var comeback := retention.get_comeback_status()

	shortcut.text = "%s • Day %d" % [text_catalog.text("UI_REWARDS"), maxi(1, retention.login_streak)]

	login_label.text = "LOGIN STREAK: %d day(s)\nOne missed day will not break an established streak." % retention.login_streak
	login_button.text = "Claim Today's Login Reward" if retention.can_claim_login_reward() else "Login Reward Claimed"
	login_button.disabled = not retention.can_claim_login_reward()

	comeback_button.visible = bool(comeback["available"])
	if bool(comeback["available"]):
		var reward: Dictionary = comeback["reward"]
		comeback_button.text = "Welcome Back • %d days away — Claim $%s + %d Gold + %d XP" % [
			int(comeback["gap_days"]),
			_format_number(int(reward.get("cash", 0))),
			int(reward.get("gold", 0)),
			int(reward.get("xp", 0))
		]

	daily_label.text = "DAILY CONTRACTS • complete any %d of 3\nRecruit: %d/%d   Raid win: %d/%d   Build/Upgrade: %d/%d\nContracts complete: %d/3" % [
		int(daily["required_contracts"]),
		int(daily["recruit"]),
		int(daily["recruit_goal"]),
		int(daily["raid_win"]),
		int(daily["raid_goal"]),
		int(daily["construction"]),
		int(daily["construction_goal"]),
		int(daily["completed_contracts"])
	]
	if not bool(daily["claimed"]):
		daily_button.text = "Claim Daily Contract Reward"
		daily_button.disabled = not bool(daily["complete"])
	elif not bool(daily["mastery_claimed"]):
		daily_button.text = "Claim 3/3 Mastery Bonus"
		daily_button.disabled = not bool(daily["mastery_complete"])
	else:
		daily_button.text = "Daily Rewards Claimed"
		daily_button.disabled = true

	weekly_label.text = "WEEKLY CONTRACTS • complete any %d of 3\nRecruit: %d/%d   Raid wins: %d/%d   Build/Upgrade: %d/%d\nContracts complete: %d/3" % [
		int(weekly["required_contracts"]),
		int(weekly["recruit"]),
		int(weekly["recruit_goal"]),
		int(weekly["raid_win"]),
		int(weekly["raid_goal"]),
		int(weekly["construction"]),
		int(weekly["construction_goal"]),
		int(weekly["completed_contracts"])
	]
	if not bool(weekly["claimed"]):
		weekly_button.text = "Claim Weekly Contract Reward"
		weekly_button.disabled = not bool(weekly["complete"])
	elif not bool(weekly["mastery_claimed"]):
		weekly_button.text = "Claim Weekly 3/3 Mastery Bonus"
		weekly_button.disabled = not bool(weekly["mastery_complete"])
	else:
		weekly_button.text = "Weekly Rewards Claimed"
		weekly_button.disabled = true

	street_cache_button.text = "Craft Street Cache — Parts x3, Intel x1\nReward: $3,500 + 4 Gold + 60 XP"
	street_cache_button.disabled = not retention.can_craft_street_cache()

	syndicate_crate_button.text = "Craft Syndicate Crate — Parts x5, Intel x3, Contraband x1\nReward: $9,000 + 12 Gold + 150 XP"
	syndicate_crate_button.disabled = not retention.can_craft_syndicate_crate()

	achievements_label.text = "ACHIEVEMENTS\n" + "\n".join(retention.get_achievement_lines())
	tutorial_label.text = retention.get_tutorial_hint()


func _format_number(value: int) -> String:
	var raw := str(value)
	var output := ""
	while raw.length() > 3:
		output = "," + raw.right(3) + output
		raw = raw.left(raw.length() - 3)
	return raw + output
