class_name ProfileUI
extends CanvasLayer

var profile: PlayerProfile
var mailbox: MailboxManager
var progression: PlayerProgression
var text_catalog: LocalizedText

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
	player_progression: PlayerProgression,
	localized_text: LocalizedText
) -> void:
	profile = player_profile
	mailbox = mailbox_manager
	progression = player_progression
	text_catalog = localized_text
	$Root/Panel/Margin/VBox/Close.text = text_catalog.text("UI_CLOSE")

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

	shortcut.text = "%s • %s" % [profile.display_name, text_catalog.text("UI_PROFILE")]
	name_edit.text = profile.display_name
	avatar_button.text = "%s: %s  (%s)" % [text_catalog.text("UI_AVATAR"), profile.get_avatar_name(), text_catalog.text("UI_CHANGE")]

	power_label.text = "Account Lv.%d\n%s: %s" % [
		progression.account_level,
		text_catalog.text("UI_POWER_RATING"),
		_format_number(profile.get_power_rating())
	]

	badges_label.text = text_catalog.text("UI_BADGES") + "\n" + " • ".join(profile.get_badges())

	var lines := PackedStringArray()
	for message in mailbox.messages:
		var state := text_catalog.text("UI_CLAIMED") if bool(message["claimed"]) else text_catalog.text("UI_REWARD_READY")
		lines.append("%s — %s\n%s" % [
			String(message["subject"]),
			state,
			String(message["body"])
		])

	if lines.is_empty():
		inbox_label.text = text_catalog.text("UI_INBOX") + "\n" + text_catalog.text("UI_NO_MESSAGES")
	else:
		inbox_label.text = text_catalog.text("UI_INBOX") + "\n" + "\n\n".join(lines)

	var count := mailbox.get_unclaimed_count()
	claim_all_button.text = "%s (%d)" % [text_catalog.text("UI_CLAIM_ALL"), count]
	claim_all_button.disabled = count <= 0


func _format_number(value: int) -> String:
	var text := str(value)
	var output := ""
	while text.length() > 3:
		output = "," + text.right(3) + output
		text = text.left(text.length() - 3)
	return text + output
