class_name UIFocusManager
extends Node

var root: Node


func setup(game_root: Node) -> void:
	root = game_root


func _unhandled_input(event: InputEvent) -> void:
	if root == null:
		return

	var wants_focus := (
		event.is_action_pressed("ui_focus_next")
		or event.is_action_pressed("ui_focus_prev")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_right")
		or event.is_action_pressed("ui_accept")
	)

	if not wants_focus:
		return

	if get_viewport().gui_get_focus_owner() == null:
		var first := _find_first_focusable(root)
		if first != null:
			first.grab_focus()
			get_viewport().set_input_as_handled()


func _find_first_focusable(node: Node) -> Control:
	if node is Control:
		var control := node as Control
		if (
			control.is_visible_in_tree()
			and control.focus_mode == Control.FOCUS_ALL
			and not (control is BaseButton and (control as BaseButton).disabled)
		):
			return control

	for child in node.get_children():
		var found := _find_first_focusable(child)
		if found != null:
			return found

	return null
