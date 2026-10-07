class_name RaidTarget
extends Area2D

signal selected(target: RaidTarget)
signal changed

@export var data: RaidTargetData

var cooldown_remaining := 0.0
var is_selected := false
var _last_displayed_second := -1
var progression: PlayerProgression


func setup_progression(player_progression: PlayerProgression) -> void:
	progression = player_progression
	if not progression.changed.is_connected(_on_progression_changed):
		progression.changed.connect(_on_progression_changed)
	queue_redraw()


func _on_progression_changed() -> void:
	changed.emit()
	queue_redraw()


func _ready() -> void:
	input_event.connect(_on_input_event)
	queue_redraw()


func _process(delta: float) -> void:
	if cooldown_remaining <= 0.0:
		return

	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	var shown := ceili(cooldown_remaining)

	if shown != _last_displayed_second:
		_last_displayed_second = shown
		changed.emit()
		queue_redraw()

	if cooldown_remaining <= 0.0:
		_last_displayed_second = -1
		changed.emit()
		queue_redraw()


func is_unlocked() -> bool:
	if data == null:
		return false
	if progression == null:
		return true
	return progression.account_level >= data.required_account_level


func is_available() -> bool:
	return is_unlocked() and cooldown_remaining <= 0.0


func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()


func start_cooldown(elapsed_after_start: float = 0.0) -> void:
	if data == null:
		return

	cooldown_remaining = maxf(
		0.0,
		data.cooldown_seconds - maxf(0.0, elapsed_after_start)
	)
	_last_displayed_second = -1
	changed.emit()
	queue_redraw()


func get_battle_data() -> Dictionary:
	if data == null:
		return {}

	return {
		"id": data.target_id,
		"name": data.display_name,
		"hp": data.max_hp,
		"reward_cash": data.reward_cash,
		"reward_xp": data.reward_xp,
		"required_account_level": data.required_account_level,
		"difficulty": data.difficulty,
		"loot": data.guaranteed_loot.duplicate(true)
	}


func get_target_id() -> String:
	return data.target_id if data != null else ""


func get_display_name() -> String:
	return data.display_name if data != null else "Raid Target"


func get_max_hp() -> float:
	return data.max_hp if data != null else 0.0


func get_reward_cash() -> int:
	return data.reward_cash if data != null else 0


func get_reward_xp() -> int:
	return data.reward_xp if data != null else 0


func get_required_account_level() -> int:
	return data.required_account_level if data != null else 1


func get_difficulty() -> String:
	return data.difficulty if data != null else "Unknown"


func get_loot_preview() -> Dictionary:
	return data.guaranteed_loot.duplicate(true) if data != null else {}


func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining}


func load_save_data(saved: Dictionary, offline_seconds: float = 0.0) -> void:
	cooldown_remaining = maxf(
		0.0,
		float(saved.get("cooldown_remaining", 0.0)) - maxf(0.0, offline_seconds)
	)
	_last_displayed_second = -1
	changed.emit()
	queue_redraw()


func _draw() -> void:
	var accent := data.accent_color if data != null else Color(0.72, 0.52, 0.18)
	var id := get_target_id()
	var unlocked := is_unlocked()

	var base := PackedVector2Array([
		Vector2(0, -62),
		Vector2(95, -14),
		Vector2(0, 34),
		Vector2(-95, -14)
	])

	var building := PackedVector2Array([
		Vector2(-58, -28),
		Vector2(0, -58),
		Vector2(58, -28),
		Vector2(58, -105),
		Vector2(0, -134),
		Vector2(-58, -105)
	])

	var body_color := Color(0.20, 0.21, 0.23) if is_available() else Color(0.13, 0.14, 0.15)

	draw_colored_polygon(base, Color(0.09, 0.10, 0.11))
	draw_polyline(PackedVector2Array([base[0], base[1], base[2], base[3], base[0]]), accent, 3.0)
	draw_colored_polygon(building, body_color)
	draw_polyline(PackedVector2Array([building[0], building[1], building[2], building[3], building[4], building[5], building[0]]), accent.darkened(0.2), 3.0)

	if id.contains("bank"):
		draw_rect(Rect2(-34, -92, 68, 36), accent.darkened(0.25), true)
		draw_string(ThemeDB.fallback_font, Vector2(-20, -66), "$", HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Color.WHITE)
	else:
		draw_rect(Rect2(-34, -93, 68, 38), accent.darkened(0.3), true)
		draw_string(ThemeDB.fallback_font, Vector2(-28, -66), "HQ", HORIZONTAL_ALIGNMENT_CENTER, 56, 20, Color.WHITE)

	_draw_status_bar(accent)

	if not unlocked:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-70, 12),
			"LOCKED • LV.%d" % get_required_account_level(),
			HORIZONTAL_ALIGNMENT_CENTER,
			140,
			15,
			Color(0.82, 0.58, 0.32)
		)
	elif cooldown_remaining > 0.0:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-70, 12),
			"RESPAWN %02d" % ceili(cooldown_remaining),
			HORIZONTAL_ALIGNMENT_CENTER,
			140,
			15,
			Color(0.85, 0.75, 0.55)
		)

	if is_selected:
		draw_arc(Vector2(0, -38), 114.0, 0.0, TAU, 48, Color(1.0, 0.82, 0.32), 5.0)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(-78, 65),
		get_display_name().to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		156,
		17,
		Color(0.95, 0.91, 0.78)
	)


func _draw_status_bar(accent: Color) -> void:
	var bar_rect := Rect2(-72, -164, 144, 12)
	draw_rect(bar_rect, Color(0.05, 0.05, 0.06, 0.9), true)

	if not is_unlocked():
		draw_rect(Rect2(bar_rect.position + Vector2(2, 2), Vector2(140, 8)), Color(0.28, 0.29, 0.31), true)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-68, -172),
			"LV.%d REQUIRED" % get_required_account_level(),
			HORIZONTAL_ALIGNMENT_LEFT,
			150,
			13,
			Color(0.78, 0.78, 0.78)
		)
	elif cooldown_remaining <= 0.0:
		draw_rect(Rect2(bar_rect.position + Vector2(2, 2), Vector2(140, 8)), accent, true)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-68, -172),
			"%s HP  %s" % [_format_number(roundi(get_max_hp())), get_difficulty().to_upper()],
			HORIZONTAL_ALIGNMENT_LEFT,
			150,
			13,
			Color(0.94, 0.94, 0.92)
		)
	else:
		var total := maxf(1.0, data.cooldown_seconds if data != null else 1.0)
		var ready_progress := 1.0 - clampf(cooldown_remaining / total, 0.0, 1.0)
		draw_rect(
			Rect2(bar_rect.position + Vector2(2, 2), Vector2(140.0 * ready_progress, 8)),
			Color(0.45, 0.47, 0.48),
			true
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-68, -172),
			"RECOVERING",
			HORIZONTAL_ALIGNMENT_LEFT,
			150,
			13,
			Color(0.75, 0.76, 0.76)
		)


func _format_number(value: int) -> String:
	var text := str(value)
	var output := ""
	while text.length() > 3:
		output = "," + text.right(3) + output
		text = text.left(text.length() - 3)
	return text + output


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var pressed := false

	if event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed

	if pressed:
		selected.emit(self)
		get_viewport().set_input_as_handled()
