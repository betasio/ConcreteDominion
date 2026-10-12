extends RefCounted
## Save and network keys remain stable; display names are independent of storage.
static func display_name(key: String) -> String:
	match key:
		"gold", "Gold": return "Diamonds"
		"Parts": return "Supplies"
		_: return key
