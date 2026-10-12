extends Node2D
## World-anchored open water and small ambient boats beyond the estate cliffs.
const SHADER_PATH := "res://shaders/backgrounds/golden_bay_distance.gdshader"
@onready var city_map: Node2D = get_parent()
var ocean: Polygon2D
var motion_enabled := true
var animation_time := 0.0
var redraw_time := 0.0
# Every route stays outside the artwork, including its widest southern pads.
const ROUTES := [
	[Vector2(-610,60),Vector2(-740,860)],
	[Vector2(830,120),Vector2(970,980)],
	[Vector2(-1000,650),Vector2(-1140,-140)]
]

func _ready() -> void:
	z_index = -90
	ocean = Polygon2D.new()
	ocean.name = "OpenWater"
	ocean.polygon = PackedVector2Array([Vector2(-6000,-4000),Vector2(6000,-4000),Vector2(6000,5000),Vector2(-6000,5000)])
	var water := ShaderMaterial.new()
	water.shader = load(SHADER_PATH)
	water.set_shader_parameter("backplate",false)
	water.set_shader_parameter("use_estate_water",true)
	water.set_shader_parameter("estate_water_detail",load("res://assets/environment/expanded_estate.png"))
	ocean.material = water
	ocean.show_behind_parent = true
	add_child(ocean)
	city_map.view_mode_changed.connect(_on_view_mode_changed)
	_on_view_mode_changed(city_map.get_view_mode())

func _process(delta: float) -> void:
	if not visible or not motion_enabled:
		return
	animation_time += delta
	ocean.material.set_shader_parameter("animation_time",animation_time)
	redraw_time += delta
	if redraw_time >= 0.05:
		redraw_time = 0.0
		queue_redraw()

func boat_position(index: int) -> Vector2:
	var phase := (sin(animation_time*0.012+float(index)*2.0)+1.0)*0.5
	return ROUTES[index][0].lerp(ROUTES[index][1],phase)

func _draw() -> void:
	for index in range(ROUTES.size()):
		var heading: float = (ROUTES[index][1]-ROUTES[index][0]).angle()
		if cos(animation_time*0.012+float(index)*2.0) < 0:
			heading += PI
		draw_set_transform(boat_position(index),heading,Vector2(1.0,0.72))
		# Translucent curved wakes, tapered hull, ivory cabin and dark glazing.
		for side in [-1.0,1.0]:
			var wake := PackedVector2Array()
			for step in range(13):
				var distance := float(step)
				wake.append(Vector2(-18-distance*5.0,side*(7+distance*1.7)+sin(distance*0.7-animation_time)*0.7))
			draw_polyline(wake,Color(0.55,0.79,0.82,0.20),2.0,true)
			draw_line(Vector2(-22,side*4),Vector2(-45,side*7),Color(0.73,0.87,0.84,0.2),3.0,true)
		draw_ellipse_shadow()
		draw_colored_polygon(PackedVector2Array([Vector2(29,0),Vector2(13,-8),Vector2(-22,-8),Vector2(-25,0),Vector2(-22,8),Vector2(13,8)]),Color("#c6c5b9"))
		draw_colored_polygon(PackedVector2Array([Vector2(22,0),Vector2(10,-5),Vector2(-20,-5),Vector2(-20,5),Vector2(10,5)]),Color("#ece3cb"))
		draw_rect(Rect2(-11,-5,20,10),Color("#354c56"))
		draw_rect(Rect2(-9,-4,13,8),Color("#e0d9c4"))
		draw_line(Vector2(-18,-6),Vector2(-18,6),Color("#8e7149"),2,true)
		draw_line(Vector2(1,0),Vector2(-2,-8),Color("#eee7d8"),1,true)
		draw_circle(Vector2(11,-7),1.1,Color("#b96854"))
		draw_circle(Vector2(11,7),1.1,Color("#6cba9e"))
	draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow() -> void:
	var points := PackedVector2Array()
	for step in range(24):
		var angle := TAU*float(step)/24.0
		points.append(Vector2(cos(angle)*28,sin(angle)*11+4))
	draw_colored_polygon(points,Color(0.01,0.04,0.05,0.3))

func _on_view_mode_changed(mode: StringName) -> void:
	visible = mode == &"base"

func set_reduced_motion(enabled: bool) -> void:
	motion_enabled = not enabled
