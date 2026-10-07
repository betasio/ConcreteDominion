class_name SettingsDiagnosticsUI
extends CanvasLayer

var settings: SettingsManager
var save_manager: SaveManager
var balance: GameBalance
var ui_roots: Array[Control] = []

@onready var panel: PanelContainer = $Root/Panel
@onready var volume: HSlider = $Root/Panel/Margin/VBox/Volume
@onready var haptics: CheckButton = $Root/Panel/Margin/VBox/Haptics
@onready var haptics_strength: HSlider = $Root/Panel/Margin/VBox/HapticsStrength
@onready var reduced_motion: CheckButton = $Root/Panel/Margin/VBox/ReducedMotion
@onready var large_text: CheckButton = $Root/Panel/Margin/VBox/LargeText
@onready var edge_pan: CheckButton = $Root/Panel/Margin/VBox/EdgePan
@onready var diagnostics: Label = $Root/Panel/Margin/VBox/Diagnostics


func setup(
	settings_manager: SettingsManager,
	game_save: SaveManager,
	game_balance: GameBalance,
	roots: Array[Control]
) -> void:
	settings = settings_manager
	save_manager = game_save
	balance = game_balance
	ui_roots = roots

	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle)
	volume.value_changed.connect(settings.set_master_volume)
	haptics.toggled.connect(settings.set_haptics_enabled)
	haptics_strength.value_changed.connect(settings.set_haptics_strength)
	reduced_motion.toggled.connect(settings.set_reduced_motion)
	large_text.toggled.connect(_set_large_text)
	edge_pan.toggled.connect(settings.set_edge_pan_enabled)
	settings.changed.connect(_refresh)

	_refresh()


func _process(_delta: float) -> void:
	if panel.visible:
		_refresh_diagnostics()


func _toggle() -> void:
	panel.visible = not panel.visible
	_refresh()


func _set_large_text(value: bool) -> void:
	settings.set_large_text(value)
	_apply_large_text()


func _apply_large_text() -> void:
	for root in ui_roots:
		if root != null and is_instance_valid(root):
			root.add_theme_font_size_override("font_size", 20 if settings.large_text else 16)


func _refresh() -> void:
	if settings == null:
		return

	volume.set_value_no_signal(settings.master_volume)
	haptics.set_pressed_no_signal(settings.haptics_enabled)
	haptics_strength.set_value_no_signal(settings.haptics_strength)
	reduced_motion.set_pressed_no_signal(settings.reduced_motion)
	large_text.set_pressed_no_signal(settings.large_text)
	edge_pan.set_pressed_no_signal(settings.edge_pan_enabled)
	haptics_strength.editable = settings.haptics_enabled
	_apply_large_text()
	_refresh_diagnostics()


func _refresh_diagnostics() -> void:
	if save_manager == null or balance == null:
		return

	var renderer := RenderingServer.get_current_rendering_method()
	var lines := PackedStringArray([
		"DIAGNOSTICS",
		"FPS: %d" % Engine.get_frames_per_second(),
		"Platform: %s" % OS.get_name(),
		"Renderer: %s" % renderer,
		"Viewport: %s" % str(get_viewport().get_visible_rect().size),
		"Touchscreen: %s" % str(DisplayServer.is_touchscreen_available()),
		"Save schema: v%d" % SaveManager.SAVE_VERSION
	])
	lines.append_array(balance.get_debug_summary())
	diagnostics.text = "\n".join(lines)
