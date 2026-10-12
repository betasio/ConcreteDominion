extends BuildLot
const SKIN := preload("res://scripts/ui/EstateSkin.gd")
var facility_kind := "empty"
var required_chapter := 0
var districts: Node
var fog: Sprite2D

func _ready() -> void:
	super._ready()
	fog = Sprite2D.new()
	var fill := GradientTexture2D.new()
	fill.gradient = Gradient.new()
	fill.width = 280
	fill.height = 175
	fog.texture = fill
	fog.position.y = -15
	var mist := ShaderMaterial.new()
	mist.shader = preload("res://shaders/backgrounds/district_fog.gdshader")
	fog.material = mist
	fog.show_behind_parent = true
	add_child(fog)

func _process(_delta: float) -> void:
	fog.visible = not can_develop()
	if fog.visible:
		fog.material.set_shader_parameter("animation_time",districts.get_parent().get_node("GoldenBayBackdrop").animation_time)

func can_develop() -> bool:
	return required_chapter == 0 or districts.chapter_completed(required_chapter)

func can_upgrade() -> bool:
	return can_develop() and super.can_upgrade()

func get_effect_summary() -> String:
	return districts.effect_summary(facility_kind,level)

func _draw() -> void:
	if not can_develop():
		MAP_LABEL.draw_badge(self,"LOCKED · Complete Chapter %d" % required_chapter,5,15)
		return
	super._draw()
