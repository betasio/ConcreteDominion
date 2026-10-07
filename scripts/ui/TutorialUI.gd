class_name TutorialUI
extends CanvasLayer

var tutorial: TutorialManager
var text_catalog: LocalizedText

@onready var panel: PanelContainer = $Root/Panel
@onready var title: Label = $Root/Panel/Margin/VBox/Title
@onready var progress: Label = $Root/Panel/Margin/VBox/Progress
@onready var body: Label = $Root/Panel/Margin/VBox/Body
@onready var action: Button = $Root/Panel/Margin/VBox/Buttons/Action
@onready var skip: Button = $Root/Panel/Margin/VBox/Buttons/Skip


func setup(manager: TutorialManager, localized_text: LocalizedText) -> void:
	tutorial = manager
	text_catalog = localized_text
	tutorial.changed.connect(_refresh)
	tutorial.tutorial_completed.connect(_on_completed)
	action.pressed.connect(_on_action)
	skip.pressed.connect(tutorial.skip_tutorial)
	_refresh()


func _on_action() -> void:
	if tutorial.current_step == TutorialManager.STEP_WELCOME:
		tutorial.advance_welcome()


func _on_completed() -> void:
	panel.visible = false


func _refresh() -> void:
	if tutorial == null or text_catalog == null:
		return

	panel.visible = tutorial.is_active()
	if not panel.visible:
		return

	title.text = text_catalog.text(tutorial.get_title_key())
	progress.text = "%s  %s" % [text_catalog.text("TUTORIAL_PROGRESS"), tutorial.get_progress_text()]
	body.text = text_catalog.text(tutorial.get_body_key())
	skip.text = text_catalog.text("TUTORIAL_SKIP")

	if tutorial.current_step == TutorialManager.STEP_WELCOME:
		action.visible = true
		action.text = text_catalog.text("TUTORIAL_START")
	else:
		action.visible = false
