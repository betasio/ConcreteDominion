class_name RetentionUI
extends CanvasLayer

var retention: RetentionManager

@onready var shortcut: Button = $Root/Shortcut
@onready var panel: PanelContainer = $Root/Panel
@onready var login_label: Label = $Root/Panel/Margin/VBox/Login
@onready var login_button: Button = $Root/Panel/Margin/VBox/ClaimLogin
@onready var daily_label: Label = $Root/Panel/Margin/VBox/Daily
@onready var daily_button: Button = $Root/Panel/Margin/VBox/ClaimDaily
@onready var weekly_label: Label = $Root/Panel/Margin/VBox/Weekly
@onready var weekly_button: Button = $Root/Panel/Margin/VBox/ClaimWeekly
@onready var street_cache_button: Button = $Root/Panel/Margin/VBox/StreetCache
@onready var syndicate_crate_button: Button = $Root/Panel/Margin/VBox/SyndicateCrate
@onready var achievements_label: Label = $Root/Panel/Margin/VBox/Achievements
@onready var tutorial_label: Label = $Root/TutorialBanner/Label


func setup(retention_manager: RetentionManager) -> void:
	retention = retention_manager
	retention.changed.connect(_refresh)

	shortcut.pressed.connect(_toggle_panel)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle_panel)
	login_button.pressed.connect(_claim_login)
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


func _claim_daily() -> void:
	retention.claim_daily_objective_reward()
	_refresh()


func _claim_weekly() -> void:
	retention.claim_weekly_objective_reward()
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

	shortcut.text = "Rewards • Day %d" % maxi(1, retention.login_streak)

	login_label.text = "LOGIN STREAK: %d day(s)\n7-day cycle rewards include Cash, Gold, loot, and XP." % retention.login_streak
	login_button.text = "Claim Today's Login Reward" if retention.can_claim_login_reward() else "Login Reward Claimed"
	login_button.disabled = not retention.can_claim_login_reward()

	daily_label.text = "DAILY OBJECTIVES\nRecruit: %d/%d   Raid wins: %d/%d" % [
		int(daily["recruit"]),
		int(daily["recruit_goal"]),
		int(daily["raid_win"]),
		int(daily["raid_goal"])
	]
	daily_button.text = "Claim Daily Reward" if not bool(daily["claimed"]) else "Daily Reward Claimed"
	daily_button.disabled = not bool(daily["complete"]) or bool(daily["claimed"])

	weekly_label.text = "WEEKLY OBJECTIVES\nRecruit: %d/%d   Raid wins: %d/%d" % [
		int(weekly["recruit"]),
		int(weekly["recruit_goal"]),
		int(weekly["raid_win"]),
		int(weekly["raid_goal"])
	]
	weekly_button.text = "Claim Weekly Reward" if not bool(weekly["claimed"]) else "Weekly Reward Claimed"
	weekly_button.disabled = not bool(weekly["complete"]) or bool(weekly["claimed"])

	street_cache_button.text = "Craft Street Cache — Parts x3, Intel x1\nReward: $3,500 + 4 Gold + 60 XP"
	street_cache_button.disabled = not retention.can_craft_street_cache()

	syndicate_crate_button.text = "Craft Syndicate Crate — Parts x5, Intel x3, Contraband x1\nReward: $9,000 + 12 Gold + 150 XP"
	syndicate_crate_button.disabled = not retention.can_craft_syndicate_crate()

	achievements_label.text = "ACHIEVEMENTS\n" + "\n".join(retention.get_achievement_lines())
	tutorial_label.text = retention.get_tutorial_hint()
