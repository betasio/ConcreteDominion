class_name UIArtStyler
extends Node

var catalog: PresentationCatalog
var root: Node
var _connected := false

const GOLD := Color(0.92, 0.72, 0.28)
const IVORY := Color(0.95, 0.91, 0.80)
const MUTED := Color(0.72, 0.73, 0.70)


func setup(root_node: Node, presentation: PresentationCatalog) -> void:
	root = root_node
	catalog = presentation
	
	await get_tree().process_frame
	_style_recursive(root)

	if not _connected:
		get_tree().node_added.connect(_on_node_added)
		_connected = true


func _on_node_added(node: Node) -> void:
	if root == null or not root.is_ancestor_of(node):
		return
	_style_node.call_deferred(node)


func _style_recursive(node: Node) -> void:
	_style_node(node)
	for child in node.get_children():
		_style_recursive(child)


func _style_node(node: Node) -> void:
	if node is PanelContainer:
		_style_panel(node as PanelContainer)
	elif node is Button:
		_style_button(node as Button)
	elif node is Label:
		_style_label(node as Label)


func _style_panel(panel: PanelContainer) -> void:
	var texture_key := "ui_panel"
	var parent_name := String(panel.get_parent().name) if panel.get_parent() != null else ""
	if parent_name.contains("Bar") or String(panel.name).contains("Bar"):
		texture_key = "ui_bar"

	var texture: Texture2D = catalog.get_decor_texture(texture_key) if catalog != null and catalog.is_decor_atlas_ready() else null
	if texture == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("#111822", 0.96)
		flat.border_color = Color("#b78c46", 0.84)
		flat.set_border_width_all(2)
		flat.set_corner_radius_all(5)
		flat.set_content_margin_all(10.0)
		panel.add_theme_stylebox_override("panel", flat)
		return

	var box := StyleBoxTexture.new()
	box.texture = texture
	box.set_texture_margin_all(12.0 if texture_key == "ui_panel" else 7.0)
	box.set_content_margin_all(8.0)
	panel.add_theme_stylebox_override("panel", box)


func _style_button(button: Button) -> void:
	var dark: Texture2D = catalog.get_decor_texture("ui_button_dark") if catalog != null and catalog.is_decor_atlas_ready() else null
	var gold: Texture2D = catalog.get_decor_texture("ui_button_gold") if catalog != null and catalog.is_decor_atlas_ready() else null
	if dark == null or gold == null:
		button.add_theme_stylebox_override("normal", _flat_button_box(Color("#192532"), Color("#a87b40")))
		button.add_theme_stylebox_override("hover", _flat_button_box(Color("#533e25"), Color("#e3b76d")))
		button.add_theme_stylebox_override("pressed", _flat_button_box(Color("#a87b40"), Color("#f5d99a")))
		button.add_theme_stylebox_override("disabled", _flat_button_box(Color("#222833"), Color("#52606c")))
		button.add_theme_color_override("font_color", IVORY)
		button.add_theme_color_override("font_hover_color", IVORY)
		button.add_theme_color_override("font_pressed_color", Color("#111822"))
		return

	button.add_theme_stylebox_override("normal", _button_box(dark, Color.WHITE))
	button.add_theme_stylebox_override("hover", _button_box(gold, Color.WHITE))
	button.add_theme_stylebox_override("pressed", _button_box(gold, Color(0.90, 0.90, 0.90)))
	button.add_theme_stylebox_override("focus", _button_box(gold, Color(1, 1, 1, 0.62)))
	button.add_theme_stylebox_override("disabled", _button_box(dark, Color(0.55, 0.55, 0.55, 0.78)))
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", Color(0.10, 0.08, 0.04))
	button.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.04))
	button.add_theme_color_override("font_focus_color", IVORY)
	button.add_theme_color_override("font_disabled_color", MUTED)


func _button_box(texture: Texture2D, modulate: Color) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.modulate_color = modulate
	box.set_texture_margin_all(7.0)
	box.set_content_margin(SIDE_LEFT, 10.0)
	box.set_content_margin(SIDE_RIGHT, 10.0)
	box.set_content_margin(SIDE_TOP, 6.0)
	box.set_content_margin(SIDE_BOTTOM, 6.0)
	return box


func _style_label(label: Label) -> void:
	if String(label.name) == "Title":
		label.add_theme_color_override("font_color", GOLD)
	elif String(label.name).contains("Status"):
		label.add_theme_color_override("font_color", IVORY)


func _flat_button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	box.set_content_margin_all(9.0)
	return box
