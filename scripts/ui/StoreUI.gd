class_name StoreUI
extends CanvasLayer

var store: StoreManager
var text_catalog: LocalizedText

@onready var panel: PanelContainer = $Root/Panel
@onready var offers: VBoxContainer = $Root/Panel/Margin/VBox/Offers


func setup(store_manager: StoreManager, localized_text: LocalizedText) -> void:
	store = store_manager
	text_catalog = localized_text
	$Root/Shortcut.text = text_catalog.text("UI_STORE")
	$Root/Panel/Margin/VBox/Title.text = text_catalog.text("UI_STORE_TITLE")
	$Root/Panel/Margin/VBox/Notice.text = text_catalog.text("UI_STORE_NOTICE")
	$Root/Panel/Margin/VBox/Close.text = text_catalog.text("UI_CLOSE")
	$Root/Shortcut.pressed.connect(_toggle)
	$Root/Panel/Margin/VBox/Close.pressed.connect(_toggle)
	_build_offers()


func _toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		$Root/Panel/Margin/VBox/Close.grab_focus.call_deferred()


func _build_offers() -> void:
	for child in offers.get_children():
		child.queue_free()

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
		parts.append("%s x%s" % [String(key), str(contents[key])])
	return text_catalog.text("UI_INCLUDES") + " " + ", ".join(parts)
