class_name StoreManager
extends Node

signal changed

var catalog: Array[Dictionary] = [
	{
		"id": "gold_starter",
		"title": "Diamond Starter",
		"price_label": "$0.99 example",
		"description": "80 Diamonds. Designed for small timer skips.",
		"contents": {"Gold": 80}
	},
	{
		"id": "builder_pack",
		"title": "Builder Pack",
		"price_label": "$4.99 example",
		"description": "Diamonds plus Cash for construction progression.",
		"contents": {"Gold": 160, "Cash": 15000}
	},
	{
		"id": "crew_support",
		"title": "Crew Support Pack",
		"price_label": "$4.99 example",
		"description": "Progress resources without exclusive combat power.",
		"contents": {"Gold": 100, "Parts": 5, "Intel": 3}
	},
	{
		"id": "recovery_pack",
		"title": "Recovery Pack",
		"price_label": "$2.99 example",
		"description": "Diamonds focused on Clinic and queue speed-ups.",
		"contents": {"Gold": 60}
	}
]


func get_catalog() -> Array[Dictionary]:
	return catalog.duplicate(true)


func purchases_enabled() -> bool:
	return false


func request_purchase(_offer_id: String) -> bool:
	push_warning("Store purchase requested, but billing is intentionally disabled in the prototype.")
	return false

# Bonuses are exclusive: owning multiple skins never stacks their power.
# Premium ownership comes only from the authenticated city response, never saves.
const SKINS := [
	{"id":"default","title":"Heritage Estate","level":1,"art":-1,"bonus":"none","description":"Villa at HQ 1 • Mansion at HQ 3 • Palace at HQ 5."},
	{"id":"vanguard","title":"Vanguard Estate","level":3,"art":1,"bonus":"attack","description":"Earn at HQ 3 • +10% NPC raid attack."},
	{"id":"founder","title":"Founder's Estate","level":5,"art":2,"bonus":"production","description":"Earn at HQ 5 • +10% facility Cash, Supplies and Intel production."},
	{"id":"crimson","title":"Crimson Citadel","level":0,"art":3,"bonus":"attack","description":"Premium skin • +10% NPC raid attack. Same strength as Vanguard."},
	{"id":"emerald","title":"Emerald Exchange","level":0,"art":4,"bonus":"production","description":"Premium skin • +10% facility production. Same strength as Founder."}]
var game: Node
var selected_skin := "default"
var _verified_skins: Array = []

func setup(owner_game: Node) -> void:
	game = owner_game
	game.city_map.safehouse.changed.connect(_appearance_changed)
	game.online_faction_ui.client.session_changed.connect(func():
		_verified_skins.clear()
		_appearance_changed()
	)
	game.online_faction_ui.client.request_completed.connect(func(action: String, status: int, data: Dictionary):
		if status == 401:
			_verified_skins.clear()
			_appearance_changed()
		elif action == "world" and status == 200:
			_verified_skins = data.get("skin_entitlements",[]).duplicate()
			_appearance_changed()
	)

func skin_info(id: String) -> Dictionary:
	for skin in SKINS:
		if skin.id == id: return skin
	return SKINS[0]

func owns_skin(id: String) -> bool:
	var skin := skin_info(id)
	if skin.id != id: return false
	if int(skin.level) == 0: return _verified_skins.has(id)
	return id == "default" or (game != null and game.city_map.safehouse.level >= int(skin.level))

func equip_skin(id: String) -> bool:
	if not owns_skin(id): return false
	selected_skin = id
	_appearance_changed()
	return true

func active_skin() -> String:
	return selected_skin if owns_skin(selected_skin) else "default"

func appearance() -> int:
	var skin := skin_info(active_skin())
	return int(skin.art) if int(skin.art) >= 0 else preload("res://scripts/world/CityArt.gd").tier(int(game.city_map.safehouse.level) if game != null else 1)

func attack_multiplier() -> float:
	return 1.1 if skin_info(active_skin()).bonus == "attack" else 1.0

func production_multiplier() -> float:
	return 1.1 if skin_info(active_skin()).bonus == "production" else 1.0

func get_save_data() -> Dictionary:
	return {"selected_skin":selected_skin}

func load_save_data(data: Dictionary) -> void:
	selected_skin = String(skin_info(String(data.get("selected_skin","default"))).id)
	# HQ is restored before offline facility settlement. Ownership remains server-only.
	_appearance_changed()

func _appearance_changed() -> void:
	if game != null: game.city_map.territory.queue_redraw()
	changed.emit()
