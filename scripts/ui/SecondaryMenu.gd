class_name SecondaryMenu
extends CanvasLayer
## One touch-friendly launcher for secondary panels on the right.
## Delegates to original shortcut signals, preserving existing panel logic.

const ITEMS := [
	["Boss Profile", "ProfileUI"],
	["Faction Hub", "OnlineFactionUI"],
	["Faction Management", "FactionUI"],
	["Store", "StoreUI"],
	["Territory", "WorldControlUI"],
	["Achievements", "AchievementUI"],
	["Events", "EventUI"],
	["Tactics", "CombatStrategyUI"],
	["Settings", "SettingsDiagnosticsUI"]
]

var menu_button: Button
var list_panel: PanelContainer


func _ready() -> void:
	layer = 16
	var root := Control.new()
	root.name = "LauncherRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	menu_button = Button.new()
	menu_button.text = "MORE  ☰"
	menu_button.custom_minimum_size = Vector2(128, 46)
	menu_button.anchor_left = 1.0
	menu_button.anchor_right = 1.0
	menu_button.offset_left = -146.0
	menu_button.offset_right = -16.0
	menu_button.offset_top = 250.0
	menu_button.offset_bottom = 298.0
	root.add_child(menu_button)

	list_panel = PanelContainer.new()
	list_panel.visible = false
	list_panel.anchor_left = 1.0
	list_panel.anchor_right = 1.0
	list_panel.offset_left = -238.0
	list_panel.offset_right = -16.0
	list_panel.offset_top = 302.0
	list_panel.offset_bottom = 554.0
	root.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "MenuScroll"
	scroll.custom_minimum_size = Vector2(204, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.name = "MenuOptions"
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)
	for entry in ITEMS:
		var target_name: String = entry[1]
		var owner_ui := get_parent().get_node_or_null(target_name)
		if owner_ui == null:
			continue
		var shortcut := owner_ui.get_node_or_null("Root/Shortcut") as Button
		if shortcut == null:
			continue
		var option := Button.new()
		option.text = entry[0]
		option.custom_minimum_size = Vector2(188, 43)
		column.add_child(option)
		option.pressed.connect(func() -> void:
			list_panel.visible = false
			shortcut.pressed.emit()
		)
		shortcut.visible = false
	menu_button.pressed.connect(func() -> void:
		list_panel.visible = not list_panel.visible
	)
	get_viewport().size_changed.connect(_fit_launcher_to_viewport)
	_fit_launcher_to_viewport()


func _fit_launcher_to_viewport() -> void:
	# Keep the popover within shorter landscape Android viewports.
	if menu_button == null or list_panel == null:
		return
	var height := get_viewport().get_visible_rect().size.y
	var top := minf(250.0, maxf(104.0, height - 390.0))
	menu_button.offset_top = top
	menu_button.offset_bottom = top + 48.0
	list_panel.offset_top = top + 52.0
	list_panel.offset_bottom = minf(height - 16.0, top + 368.0)
