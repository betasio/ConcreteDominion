class_name TurfDetailArt
extends TurfEnvironmentArt
## Foreground decoration using the project's cleaned premium PNG assets.
## Separate from retaining cliffs so planters draw over paving, not under it.

func _draw() -> void:
	if city_map == null or city_map.get_view_mode() != &"base":
		return
	var hq: Vector2 = city_map.safehouse.position
	var clinic: Vector2 = city_map.hospital.position
	var barracks: Vector2 = city_map.barracks.position
	var garage: Vector2 = city_map.lot_a.position
	var scrap: Vector2 = city_map.lot_c.position
	var data: Vector2 = city_map.lot_d.position
	# The shipped filenames are verified visually: luxury_fence contains
	# the rocky planted embankment, rock_embankment the long garden median.
	_stamp("luxury_fence", hq + Vector2(-205, 85), 140.0)
	_stamp("luxury_fence", hq + Vector2(200, 81), 131.0)
	_stamp("cypress_planter", hq + Vector2(-157, -26), 80.0)
	_stamp("ornamental_tree", hq + Vector2(164, -18), 57.0)
	# Mid-level planted edges stay away from the clinic/barracks labels.
	_stamp("flower_planter", clinic + Vector2(-111, 80), 83.0)
	_stamp("hedge_barrier", barracks + Vector2(123, 79), 93.0)
	# Lower service-zone landscaping; keep the central entrance accessible.
	_stamp("rock_embankment", scrap + Vector2(-101, 104), 146.0)
	_stamp("flower_planter", garage + Vector2(-132, 89), 72.0)
	_stamp("rock_embankment", data + Vector2(122, 102), 140.0)
