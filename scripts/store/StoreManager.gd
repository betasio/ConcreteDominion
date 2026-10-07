class_name StoreManager
extends Node

signal changed

var catalog: Array[Dictionary] = [
	{
		"id": "gold_starter",
		"title": "Gold Starter",
		"price_label": "$0.99 example",
		"description": "80 Gold. Designed for small timer skips.",
		"contents": {"Gold": 80}
	},
	{
		"id": "builder_pack",
		"title": "Builder Pack",
		"price_label": "$4.99 example",
		"description": "Gold plus Cash for construction progression.",
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
		"description": "Gold focused on Clinic and queue speed-ups.",
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
