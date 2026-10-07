class_name PauseMenu
extends CanvasLayer

var save_manager: SaveManager

@onready var panel: PanelContainer = $Root/Panel
@onready var status: Label = $Root/Panel/Margin/VBox/Status
@onready var resume_button: Button = $Root/Panel/Margin/VBox/Resume


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Root/Panel/Margin/VBox/Resume.pressed.connect(_resume)
	$Root/Panel/Margin/VBox/Save.pressed.connect(_save_now)
	$Root/Panel/Margin/VBox/Title.pressed.connect(_return_to_title)
	$Root/Panel/Margin/VBox/Quit.pressed.connect(_quit_game)


func setup(game_save: SaveManager) -> void:
	save_manager = game_save


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if panel.visible:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	get_tree().paused = true
	panel.visible = true
	status.text = "Game paused."
	resume_button.grab_focus.call_deferred()


func _resume() -> void:
	panel.visible = false
	get_tree().paused = false


func _save_now() -> void:
	if save_manager != null and save_manager.save_game():
		status.text = "Game saved."
	else:
		status.text = "Save failed."


func _return_to_title() -> void:
	if save_manager != null:
		save_manager.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/core/Boot.tscn")


func _quit_game() -> void:
	if save_manager != null:
		save_manager.save_game()
	get_tree().paused = false
	get_tree().quit()
