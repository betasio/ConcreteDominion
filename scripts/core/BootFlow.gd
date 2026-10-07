class_name BootFlow
extends Node

const GAME_SCENE_PATH := "res://scenes/core/Main.tscn"
const SAVE_PATH := "user://concrete_dominion_save.json"
const BACKUP_PATH := "user://concrete_dominion_save.backup.json"

@onready var title_root: Control = $TitleUI
@onready var loading_root: Control = $LoadingUI
@onready var continue_button: Button = $TitleUI/Center/VBox/Continue
@onready var new_game_button: Button = $TitleUI/Center/VBox/NewGame
@onready var quit_button: Button = $TitleUI/Center/VBox/Quit
@onready var status_label: Label = $LoadingUI/Center/VBox/Status
@onready var progress_bar: ProgressBar = $LoadingUI/Center/VBox/Progress

var _loading := false


func _ready() -> void:
	continue_button.pressed.connect(_continue_game)
	new_game_button.pressed.connect(_new_game)
	quit_button.pressed.connect(func(): get_tree().quit())

	continue_button.disabled = not (
		FileAccess.file_exists(SAVE_PATH)
		or FileAccess.file_exists(BACKUP_PATH)
	)

	if OS.has_feature("web"):
		quit_button.visible = false

	continue_button.grab_focus.call_deferred()


func _process(_delta: float) -> void:
	if not _loading:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH, progress)

	if not progress.is_empty():
		progress_bar.value = float(progress[0]) * 100.0

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			status_label.text = "Loading city systems..."
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
			if packed == null:
				_show_load_error("Could not load the game scene.")
				return
			_loading = false
			get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED:
			_show_load_error("Loading failed. Check the project diagnostics.")
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_show_load_error("The main game scene is invalid.")


func _continue_game() -> void:
	_begin_load()


func _new_game() -> void:
	_remove_if_exists(SAVE_PATH)
	_remove_if_exists(BACKUP_PATH)
	_begin_load()


func _begin_load() -> void:
	if _loading:
		return

	var error := ResourceLoader.load_threaded_request(GAME_SCENE_PATH)
	if error != OK:
		_show_load_error("Could not start loading (%s)." % error_string(error))
		return

	_loading = true
	title_root.visible = false
	loading_root.visible = true
	progress_bar.value = 0.0
	status_label.text = "Preparing Concrete Dominion..."


func _show_load_error(message: String) -> void:
	_loading = false
	title_root.visible = true
	loading_root.visible = false
	continue_button.disabled = false
	continue_button.grab_focus.call_deferred()
	push_error(message)


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
