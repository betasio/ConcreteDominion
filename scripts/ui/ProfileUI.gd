class_name ProfileUI
extends CanvasLayer

var profile: PlayerProfile
var mailbox: MailboxManager
var progression: PlayerProgression

@onready var shortcut: Button = $Root/Shortcut
@onready var panel: PanelContainer = $Root/Panel
@onready var name_edit: LineEdit = $Root/Panel/Margin/VBox/NameEdit
@onready var avatar_button: Button = $Root/Panel/Margin/VBox/Avatar
@onready var power_label: Label = $Root/Panel/Margin/VBox/Power
@onready var badges_label: Label = $Root/Panel/Margin/VBox/Badges
@onready var inbox_label: Label = $Root/Panel/Margin/VBox/Inbox
@onready var claim_all_button: Button = $Root/Panel/Margin/VBox/ClaimAll


func setup(
	player_profile: PlayerProfile,
	mailbox_manager: MailboxManager,
	player_progression: PlayerProgression
) -> void:
	profile = player_profile
	mailbox = mailbox_manager
	progression = player_progression

	profile.changed.connect(_refresh)
	mailbox.changed.connect(_refresh)
	progression.changed.connect(_refresh)

	shortcut.pressed.connect(_toggle_panel)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle_panel)
	$Root/Panel/Margin/VBox/SaveName.pressed.connect(_save_name)
	avatar_button.pressed.connect(_cycle_avatar)
	claim_all_button.pressed.connect(_claim_all)

	_refresh()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	_refresh()


func _save_name() -> void:
	profile.set_display_name(name_edit.text)
	_refresh()


func _cycle_avatar() -> void:
	profile.cycle_avatar()
	_refresh()


func _claim_all() -> void:
	mailbox.claim_all()
	_refresh()


func _refresh() -> void:
	if profile == null:
		return

	shortcut.text = "%s • Profile" % profile.display_name
	name_edit.text = profile.display_name
	avatar_button.text = "Avatar: %s  (Change)" % profile.get_avatar_name()

	power_label.text = "Account Lv.%d\nPower Rating: %s" % [
		progression.account_level,
		_format_number(profile.get_power_rating())
	]

	badges_label.text = "BADGES\n" + " • ".join(profile.get_badges())

	var lines := PackedStringArray()
	for message in mailbox.messages:
		var state := "CLAIMED" if bool(message["claimed"]) else "REWARD READY"
		lines.append("%s — %s\n%s" % [
			String(message["subject"]),
			state,
			String(message["body"])
		])

	if lines.is_empty():
		inbox_label.text = "INBOX\nNo messages."
	else:
		inbox_label.text = "INBOX\n" + "\n\n".join(lines)

	var count := mailbox.get_unclaimed_count()
	claim_all_button.text = "Claim All Mail Rewards (%d)" % count
	claim_all_button.disabled = count <= 0


func _format_number(value: int) -> String:
	var text := str(value)
	var output := ""
	while text.length() > 3:
		output = "," + text.right(3) + output
		text = text.left(text.length() - 3)
	return text + output
