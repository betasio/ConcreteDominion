extends Node2D
signal site_selected(id: String)
signal estate_selected(estate: Dictionary)
const ART := preload("res://scripts/world/CityArt.gd")
const SITES := [
	{"id":"exchange", "name":"Underground Exchange", "day":30, "cell":Vector2i(9,21), "art":3},
	{"id":"port", "name":"Port Authority", "day":45, "cell":Vector2i(29,21), "art":4},
	{"id":"city_hall", "name":"City Hall", "day":60, "cell":Vector2i(19,9), "art":2}]
const COLORS := {"self":Color("#78d96c"), "ally":Color("#64c5ff"), "other":Color("#eda65b")}
var city_map: Node2D
var world_state: Dictionary = {}
var cells: Array[Vector2i] = []
var font: FontFile
var tap := Vector2.INF
var active := false

func _ready() -> void:
	city_map = get_parent()
	font = ThemeDB.fallback_font.duplicate() as FontFile
	font.multichannel_signed_distance_field = true
	for y in [4,9,14,19,24,29]:
		for x in [4,9,14,19,24,29,34]:
			var cell := Vector2i(x,y)
			var reserved := false
			for site in SITES:
				var footprint := Rect2(city_map.iso_to_screen(cell)+Vector2(-145,-220),Vector2(290,285))
				reserved = reserved or footprint.intersects(site_rect(site))
			if not reserved and cells.size() < 24:
				cells.append(cell)
	cells.sort_custom(func(a,b): return Vector2(a).distance_squared_to(Vector2(18,16)) < Vector2(b).distance_squared_to(Vector2(18,16)))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	city_map.view_mode_changed.connect(func(_mode): queue_redraw())

func set_snapshot(data: Dictionary) -> void:
	world_state = data.duplicate(true)
	queue_redraw()

func get_estates() -> Array:
	return world_state.get("players", [{"slot":1,"id":"local", "display_name":"My Turf", "tag":"", "relation":"self"}])

func estate_position(estate: Dictionary) -> Vector2:
	return city_map.iso_to_screen(cells[(int(estate.slot)-1)%24])

func focus_home() -> void:
	for estate in get_estates():
		if estate.relation == "self":
			city_map._focus_camera(estate_position(estate))
			return

func _draw() -> void:
	if not active or city_map.get_view_mode() != &"world":
		return
	var entries: Array = []
	var occupied := {}
	for estate in get_estates():
		var pos := estate_position(estate)
		occupied[(int(estate.slot)-1)%24] = true
		entries.append({"pos":pos,"art":estate_art(estate),"estate":estate})
	for i in range(cells.size()):
		if not occupied.has(i):
			entries.append({"pos":city_map.iso_to_screen(cells[i]),"art":5 if i % 3 == 0 else -1})
	for site in SITES:
		entries.append({"pos":city_map.iso_to_screen(site.cell),"art":site.art,"site":site})
	entries.sort_custom(func(a,b): return a.pos.y < b.pos.y)
	for entry in entries:
		var p: Vector2 = entry.pos
		var width := 570.0 if entry.has("site") else (260.0 if entry.has("estate") else 245.0)
		var texture: Texture2D = ART.landmark(entry.site.id) if entry.has("site") else (ART.texture(5) if entry.art == -1 else ART.turf(entry.art))
		var size := Vector2(width, width * texture.get_height()/texture.get_width())
		draw_texture_rect(texture, Rect2(p+Vector2(-width/2,50-size.y),size),false)
		if entry.has("estate"):
			var estate: Dictionary = entry.estate
			var relation := String(estate.relation)
			var label := ("[%s] " % estate.tag if not String(estate.tag).is_empty() else "") + String(estate.display_name)
			if estate.has("hq_level"): label += " · HQ %d" % estate_level(estate)
			if relation == "self": label = "MY TURF · HQ %d" % estate_level(estate)
			_plate(p+Vector2(0,55), label, COLORS.get(relation,COLORS.other))
		elif entry.has("site"):
			var site: Dictionary = entry.site
			var label: String = site.name
			var color := Color("#e6c477")
			var state := _site_state(site.id)
			if state.is_empty(): label += " · DAY %d" % site.day
			elif state.phase == "contested": label += " · CONTEST"
			elif not String(state.owner_id).is_empty(): label += " · " + String(state.owner_name)
			else: label += " · PROTECTED"
			_plate(p+Vector2(0,66),label,color)

func _site_state(id: String) -> Dictionary:
	for site in world_state.get("landmarks",[]):
		if site.id == id: return site
	return {}

func _plate(pos: Vector2, label: String, color: Color) -> void:
	draw_style_box(_plate_style(color),Rect2(pos+Vector2(-145,-18),Vector2(290,30)))
	draw_string(font,pos+Vector2(-138,4),label.left(32),HORIZONTAL_ALIGNMENT_CENTER,276,20,color)

func _plate_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#101913",0.94)
	box.border_color = color.darkened(0.4)
	box.border_width_bottom = 2
	box.set_corner_radius_all(4)
	return box

func _unhandled_input(event: InputEvent) -> void:
	if not active or city_map.get_view_mode()!=&"world" or city_map.camera.controls_blocked:
		tap = Vector2.INF
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if tap.is_finite() and event.position.distance_to(tap)>10*get_viewport_rect().size.x/float(get_window().size.x): tap=Vector2.INF
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		tap=Vector2.INF
		return
	if event is InputEventScreenTouch and event.index!=0:
		tap=Vector2.INF
		return
	if not (event is InputEventMouseButton or event is InputEventScreenTouch): return
	if event.pressed:
		tap=event.position
	elif tap.is_finite():
		tap=Vector2.INF
		var p: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		for site in SITES:
			if site_rect(site).has_point(p):
				site_selected.emit(site.id)
				get_viewport().set_input_as_handled()
				return
		for estate in get_estates():
			if p.distance_to(estate_position(estate)+Vector2(0,-25))<85:
				estate_selected.emit(estate)
				get_viewport().set_input_as_handled()
				return

func estate_level(estate: Dictionary) -> int:
	if estate.relation == "self": return int(city_map.safehouse.level)
	return maxi(1,int(estate.get("hq_level",1)))

func estate_art(estate: Dictionary) -> int:
	if estate.relation == "self": return city_map.get_parent().store_manager.appearance()
	return ART.tier(estate_level(estate))

func site_rect(site: Dictionary) -> Rect2:
	var pos: Vector2 = city_map.iso_to_screen(site.cell)
	return Rect2(pos+Vector2(-285,-677),Vector2(570,752))
