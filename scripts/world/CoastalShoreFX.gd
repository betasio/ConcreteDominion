extends Node2D
## Restrained animated shoreline accents beneath the estate's lowest cliffs.
## Decorative only: no collision, selection, or changes to game state.
@onready var city_map: Node2D = get_parent()
var phase := 0.0
var refresh := 0.0

func _ready() -> void:
    z_index = -1
    city_map.view_mode_changed.connect(_on_view_mode_changed)
    _on_view_mode_changed(city_map.get_view_mode())
    set_process(true)

func _on_view_mode_changed(mode: StringName) -> void:
    visible = mode == &"base"
    queue_redraw()

func _process(delta: float) -> void:
    if not visible:
        return
    phase = fmod(phase + delta, TAU * 16.0)
    refresh += delta
    if refresh > 0.12:
        refresh = 0.0
        queue_redraw()

func _draw() -> void:
    if not visible or city_map.get_view_mode() != &"base":
        return
    # These sites follow the actual interactive lot positions when re-laid out.
    var left: Vector2 = city_map.lot_c.position
    var middle: Vector2 = city_map.lot_a.position
    var right: Vector2 = city_map.lot_d.position
    _shore_section(left + Vector2(-160, 97), left + Vector2(70, 145), 0.0)
    _shore_section(left + Vector2(65, 146), middle + Vector2(86, 190), 1.8)
    _shore_section(middle + Vector2(80, 192), right + Vector2(142, 152), 3.5)
    # Faint deeper-water ripples below the cliff, not a full-screen overlay.
    for i in range(14):
        var seed := float(i)
        var x := -840.0 + seed * 132.0
        var y := 750.0 + 24.0 * sin(seed * 1.37)
        var motion := 8.0 * sin(phase * 0.27 + seed)
        draw_arc(Vector2(x + motion, y), 31.0 + 10.0 * sin(seed), PI * 0.98, PI * 1.85, 20, Color(0.33, 0.58, 0.67, 0.075), 1.4, true)

func _shore_section(start: Vector2, finish: Vector2, offset: float) -> void:
    var length := start.distance_to(finish)
    var steps := maxi(16, int(length / 7.0))
    var forward := (finish - start).normalized()
    var normal := Vector2(-forward.y, forward.x)
    var crest := PackedVector2Array()
    var backwash := PackedVector2Array()
    for i in range(steps + 1):
        var t := float(i) / float(steps)
        var endpoint_fade := sin(PI * t)
        var wave := sin(t * 22.0 + phase * 0.65 + offset) * 3.5 * endpoint_fade
        var p := start.lerp(finish, t) + normal * wave
        crest.append(p)
        backwash.append(p + normal * (12.0 + 4.0 * sin(phase * 0.48 + t * 10.0 + offset)))
    draw_polyline(backwash, Color(0.17, 0.45, 0.54, 0.12), 7.0, true)
    draw_polyline(crest, Color(0.69, 0.87, 0.88, 0.27), 2.2, true)
