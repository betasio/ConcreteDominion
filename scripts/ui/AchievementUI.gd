class_name AchievementUI
extends CanvasLayer

var achievements: AchievementManager
var text_catalog: LocalizedText

@onready var panel: PanelContainer = $Root/Panel
@onready var summary: Label = $Root/Panel/Margin/VBox/Summary
@onready var list_label: Label = $Root/Panel/Margin/VBox/List


func setup(manager: AchievementManager, localized_text: LocalizedText) -> void:
	achievements = manager
	text_catalog = localized_text
	$Root/Shortcut.text = text_catalog.text("UI_ACHIEVEMENTS")
	$Root/Panel/Margin/VBox/Title.text = text_catalog.text("UI_ACHIEVEMENTS_TITLE")
	$Root/Panel/Margin/VBox/Close.text = text_catalog.text("UI_CLOSE")
	achievements.changed.connect(_refresh)
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle)
	_refresh()


func _toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		$Root/Panel/Margin/VBox/Close.grab_focus.call_deferred()
	_refresh()


func _refresh() -> void:
	if achievements == null:
		return
	summary.text = achievements.get_dominion_summary()
	list_label.text = "\n\n".join(achievements.get_progress_lines(text_catalog))
