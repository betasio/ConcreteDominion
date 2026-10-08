class_name SecondaryMenu
extends CanvasLayer
## One touch-friendly launcher for secondary panels on the right.
## Delegates to original shortcut signals, preserving existing panel logic.

const ITEMS := [
	["Boss Profile", "ProfileUI"],
	["Faction Hub", "OnlineFactionUI"],
	["Store", "StoreUI"],
	["Territory", "WorldControlUI"],
	["Achievements", "AchievementUI"]
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
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_button.position = Vector2(-144, 250)
	root.add_child(menu_button)

	list_panel = PanelContainer.new()
	list_panel.visible = false
	list_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	list_panel.position = Vector2(-238, 300)
	root.add_child(list_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	list_panel.add_child(column)
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
