class_name TurfEntranceArt
extends TurfEnvironmentArt
## Draw above roads, beneath selectable buildings, to keep the gate readable.

func _draw() -> void:
	if city_map == null or city_map.get_view_mode() != &"base":
		return
	var lower: Vector2 = city_map.lot_a.position
	_stamp("wall_corner", lower + Vector2(0, 168), 162.0)
	_stamp("security_post", lower + Vector2(-125, 140), 87.0)
