extends Node2D
## Two small ambient vehicles on measured road lanes, never on building pads.
const LAYOUT := preload("res://scripts/world/IllustratedEstateLayout.gd")
const LANES := [
	[Vector2(530,300),Vector2(530,400),Vector2(530,510),Vector2(530,580)],
	[Vector2(390,790),Vector2(390,910),Vector2(390,1070),Vector2(390,1250)]
]
var clock := 0.0
var refresh := 0.0
@onready var backdrop = get_parent().get_node("GoldenBayBackdrop")

func _ready() -> void:
	get_parent().view_mode_changed.connect(func(mode): visible = mode == &"base")
	visible = get_parent().get_view_mode() == &"base"

func _process(delta: float) -> void:
	if not visible or not backdrop.motion_enabled:
		return
	clock += delta
	refresh += delta
	if refresh >= 0.05:
		refresh = 0.0
		queue_redraw()

func _draw() -> void:
	for index in range(LANES.size()):
		var lane: Array = LANES[index]
		var phase := fmod(clock*0.025+float(index)*0.43,2.0)
		var fraction := phase if phase <= 1.0 else 2.0-phase
		var segment := minf(fraction*float(lane.size()-1),float(lane.size()-1)-0.001)
		var start: Vector2 = lane[int(segment)]
		var end: Vector2 = lane[int(segment)+1]
		var point := LAYOUT.artwork_to_world(start.lerp(end,fmod(segment,1.0)))
		var heading := (end-start).angle() + (PI if phase > 1.0 else 0.0)
		draw_set_transform(point,heading,Vector2.ONE)
		draw_circle(Vector2(0,2),7,Color(0,0,0,0.28))
		draw_style_box(_body(),Rect2(-8,-4,16,8))
		draw_rect(Rect2(-3,-3,7,6),Color("#526572"))
		for side in [-2.5,2.5]:
			draw_line(Vector2(6,side),Vector2(8,side),Color("#f4d89a"),1.5,true)
			draw_line(Vector2(-8,side),Vector2(-7,side),Color("#a94639"),1.0,true)
	draw_set_transform(Vector2.ZERO)

var body: StyleBoxFlat
func _body() -> StyleBoxFlat:
	if body == null:
		body = StyleBoxFlat.new()
		body.bg_color = Color("#18252c")
		body.border_color = Color("#788082")
		body.set_border_width_all(1)
		body.set_corner_radius_all(3)
	return body
