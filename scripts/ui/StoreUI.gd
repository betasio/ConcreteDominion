class_name StoreUI
extends CanvasLayer

var store: StoreManager
@onready var heading: Label = $Root/Panel/Margin/VBox/Title
@onready var close_button: Button = $Root/Panel/Margin/VBox/Close
var skin_buttons: Dictionary = {}
var heritage_preview: TextureRect
var text_catalog: LocalizedText

@onready var panel: PanelContainer = $Root/Panel
@onready var offers: VBoxContainer = $Root/Panel/Margin/VBox/Offers


func setup(store_manager: StoreManager, localized_text: LocalizedText) -> void:
	store = store_manager
	text_catalog = localized_text
	$Root/Shortcut.text = text_catalog.text("UI_STORE")
	heading.text = "TURF COLLECTION"
	heading.focus_mode = Control.FOCUS_ALL
	$Root/Panel/Margin/VBox/Notice.text = "One active bonus. Earn equal strength through HQ upgrades. Premium checkout coming later."
	$Root/Panel/Margin/VBox/Close.text = text_catalog.text("UI_CLOSE")
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle)
	_build_offers()
	store.changed.connect(_refresh_skins)
	_refresh_skins()


func _toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		heading.grab_focus.call_deferred()


func _build_offers() -> void:
	for child in offers.get_children():
		child.queue_free()

	_build_skins()
	for offer in store.get_catalog():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 105)
		offers.add_child(card)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 8)
		card.add_child(margin)

		var box := VBoxContainer.new()
		margin.add_child(box)

		var title := Label.new()
		title.text = "%s — %s" % [String(offer["title"]), String(offer["price_label"])]
		title.add_theme_font_size_override("font_size", 19)
		box.add_child(title)

		var description := Label.new()
		description.text = "%s\n%s" % [
			String(offer["description"]),
			_format_contents(offer["contents"])
		]
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(description)

		var purchase := Button.new()
		purchase.text = text_catalog.text("UI_STORE_DISABLED")
		purchase.disabled = true
		purchase.tooltip_text = text_catalog.text("UI_STORE_TOOLTIP")
		box.add_child(purchase)


func _first_offer_button() -> Button:
	for card in offers.get_children():
		for child in card.get_children():
			if child is MarginContainer:
				for box in child.get_children():
					if box is VBoxContainer:
						for control in box.get_children():
							if control is Button:
								return control
	return null


func _format_contents(contents: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in contents.keys():
		parts.append("%s x%s" % [preload("res://scripts/core/ResourceIdentity.gd").display_name(String(key)), str(contents[key])])
	return text_catalog.text("UI_INCLUDES") + " " + ", ".join(parts)

func _build_skins() -> void:
	var notice := Label.new()
	notice.text = "APPEARANCES\nBonuses apply to NPC raids or facility production, not PvP or landmark scores."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	offers.add_child(notice)
	for skin in StoreManager.SKINS:
		var card := HBoxContainer.new()
		offers.add_child(card)
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(112,112)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = preload("res://scripts/world/CityArt.gd").turf(int(skin.art) if int(skin.art)>=0 else store.appearance())
		if skin.id == "default": heritage_preview = preview
		card.add_child(preview)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(box)
		var label := Label.new()
		label.text = skin.title + "\n" + skin.description
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
		var button := Button.new()
		button.custom_minimum_size.y = 44
		button.pressed.connect(func(): store.equip_skin(skin.id))
		box.add_child(button)
		skin_buttons[skin.id] = button

func _refresh_skins() -> void:
	if heritage_preview != null:
		heritage_preview.texture = preload("res://scripts/world/CityArt.gd").turf(preload("res://scripts/world/CityArt.gd").tier(int(store.game.city_map.safehouse.level)))
	for id in skin_buttons:
		var button: Button = skin_buttons[id]
		var skin := store.skin_info(id)
		button.disabled = not store.owns_skin(id) or store.active_skin() == id
		button.text = "Equipped" if store.active_skin() == id else ("Equip" if store.owns_skin(id) else ("Checkout unavailable" if int(skin.level)==0 else "Unlock at HQ %d" % skin.level))
