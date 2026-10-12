extends Camera2D

@export_group("Movement")
@export var keyboard_pan_speed: float = 900.0
@export var edge_pan_enabled: bool = true
@export var edge_pan_margin: float = 24.0
@export var edge_pan_speed: float = 700.0

@export_group("Zoom")
@export var min_zoom: float = 0.45
@export var max_zoom: float = 2.0
@export var mouse_zoom_step: float = 0.12
@export var pinch_zoom_sensitivity: float = 1.0

@export_group("World Limits")
@export var use_camera_limits: bool = false
@export var camera_bounds := Rect2(Vector2(-3500, -2500), Vector2(7000, 5000))

var estate_bottom := INF
var estate_content_rect := Rect2()
var controls_blocked := false
var _mouse_dragging := false
var _active_touches: Dictionary = {}
var _previous_pinch_distance := 0.0


func _ready() -> void:
	_ensure_input_actions()


func _process(delta: float) -> void:
	if controls_blocked:
		return
	var ui_has_focus := get_viewport().gui_get_focus_owner() != null
	if not ui_has_focus:
		_handle_keyboard_movement(delta)
	if edge_pan_enabled and not ui_has_focus and not DisplayServer.is_touchscreen_available() and get_viewport().gui_get_hovered_control() == null:
		_handle_edge_pan(delta)
	_clamp_camera_to_world()


func set_controls_blocked(blocked: bool) -> void:
	controls_blocked = blocked
	if blocked:
		_mouse_dragging = false
		_active_touches.clear()
		_previous_pinch_distance = 0.0


func _input(event: InputEvent) -> void:
	# A drag can end over a GUI control, which consumes _unhandled_input.
	if event is InputEventScreenTouch and not event.pressed:
		_active_touches.erase(event.index)
		_previous_pinch_distance = 0.0
	elif event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:
		_mouse_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if controls_blocked:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_change_zoom(mouse_zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_change_zoom(-mouse_zoom_step)

	elif event is InputEventMouseMotion and _mouse_dragging:
		position -= event.relative / zoom.x

	elif event is InputEventScreenTouch:
		if event.pressed:
			_active_touches[event.index] = event.position
		else:
			_active_touches.erase(event.index)
			_previous_pinch_distance = 0.0

		if _active_touches.size() == 2:
			_previous_pinch_distance = _get_current_pinch_distance()

	elif event is InputEventScreenDrag:
		if not _active_touches.has(event.index):
			return
		var old_position: Vector2 = _active_touches[event.index]
		_active_touches[event.index] = event.position

		if _active_touches.size() == 1:
			position -= (event.position - old_position) / zoom.x
		elif _active_touches.size() >= 2:
			var new_distance := _get_current_pinch_distance()
			if _previous_pinch_distance > 0.0 and new_distance > 0.0:
				var pinch_ratio := new_distance / _previous_pinch_distance
				var points := _active_touches.values()
				_zoom_at_screen_point(zoom.x * pow(pinch_ratio, pinch_zoom_sensitivity), (points[0]+points[1])*0.5)
			_previous_pinch_distance = new_distance


func _handle_keyboard_movement(delta: float) -> void:
	var direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if direction != Vector2.ZERO:
		position += direction * keyboard_pan_speed * delta / zoom.x


func _handle_edge_pan(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var mouse_position := get_viewport().get_mouse_position()
	var direction := Vector2.ZERO

	if mouse_position.x <= edge_pan_margin:
		direction.x -= 1.0
	elif mouse_position.x >= viewport_size.x - edge_pan_margin:
		direction.x += 1.0

	if mouse_position.y <= edge_pan_margin:
		direction.y -= 1.0
	elif mouse_position.y >= viewport_size.y - edge_pan_margin:
		direction.y += 1.0

	if direction != Vector2.ZERO:
		position += direction.normalized() * edge_pan_speed * delta / zoom.x


func _change_zoom(amount: float) -> void:
	_zoom_at_screen_point(zoom.x + amount,get_viewport().get_mouse_position())


func _zoom_at_screen_point(value: float, screen_point: Vector2) -> void:
	var offset := screen_point-get_viewport_rect().size*0.5
	var anchor := position+offset/zoom.x
	_set_camera_zoom(value)
	position = anchor-offset/zoom.x
	_clamp_camera_to_world()


func _set_camera_zoom(value: float) -> void:
	var z := clampf(value, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	_clamp_camera_to_world()


func _get_current_pinch_distance() -> float:
	if _active_touches.size() < 2:
		return 0.0
	var positions := _active_touches.values()
	return (positions[0] as Vector2).distance_to(positions[1] as Vector2)


func _clamp_camera_to_world() -> void:
	if not use_camera_limits:
		return
	position.x = clampf(position.x, camera_bounds.position.x, camera_bounds.end.x)
	position.y = clampf(position.y, camera_bounds.position.y, camera_bounds.end.y)
	if is_finite(estate_bottom):
		var content := estate_content_rect if estate_content_rect.has_area() else get_viewport_rect()
		var below_center := (content.end.y-get_viewport_rect().get_center().y)/zoom.y
		var maximum_y := estate_bottom-below_center
		position.y = minf(position.y,maximum_y)
		# Smoothing must not expose water below the southern road after zoom/resize.
		if get_screen_center_position().y > maximum_y:
			reset_smoothing()


func _ensure_input_actions() -> void:
	_add_key_action("camera_up", KEY_W)
	_add_key_action("camera_up", KEY_UP)
	_add_key_action("camera_down", KEY_S)
	_add_key_action("camera_down", KEY_DOWN)
	_add_key_action("camera_left", KEY_A)
	_add_key_action("camera_left", KEY_LEFT)
	_add_key_action("camera_right", KEY_D)
	_add_key_action("camera_right", KEY_RIGHT)


func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return

	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)
