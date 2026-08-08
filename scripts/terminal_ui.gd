class_name GreenhouseTerminalUI
extends Control

signal close_requested

var game_state: GreenhouseGameState
var frame: PanelContainer
var shop_tab: Button
var sell_tab: Button
var category_buttons: Dictionary = {}
var category_panel: Control
var item_grid: GridContainer
var cart_panel: PanelContainer
var cart_header: Label
var cart_list: VBoxContainer
var cart_total_label: Label
var checkout_button: Button
var status_label: Label
var current_mode := "shop"
var current_category := "plants"
var rebuilding := false

var colors := {
	"ink": Color("#172524"),
	"panel": Color("#263938"),
	"panel_2": Color("#314846"),
	"line": Color("#7c9790"),
	"text": Color("#edf1df"),
	"muted": Color("#aabbb2"),
	"accent": Color("#67c587"),
	"gold": Color("#d0bd65"),
	"warning": Color("#d58b67"),
}


func configure(state: GreenhouseGameState) -> GreenhouseTerminalUI:
	game_state = state
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	game_state.state_changed.connect(_refresh_all)
	visible = false
	return self


func open() -> void:
	visible = true
	current_mode = "shop"
	current_category = "plants"
	_refresh_all()
	shop_tab.call_deferred("grab_focus")


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("terminal") or event.is_action_pressed("pause"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.024, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	frame = PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 120
	frame.offset_top = 70
	frame.offset_right = -120
	frame.offset_bottom = -70
	frame.add_theme_stylebox_override("panel", _panel_style(colors.panel, colors.line, 2, 4, 24))
	add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	frame.add_child(outer)
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size.y = 76
	top_bar.add_theme_constant_override("separation", 12)
	outer.add_child(top_bar)
	shop_tab = _icon_button("cart", "Order stock", 72)
	shop_tab.pressed.connect(_set_mode.bind("shop"))
	top_bar.add_child(shop_tab)
	sell_tab = _icon_button("leaf", "Sell offshoots", 72)
	sell_tab.pressed.connect(_set_mode.bind("sell"))
	top_bar.add_child(sell_tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	status_label = Label.new()
	status_label.text = "DRONE LINK READY"
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", colors.muted)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(status_label)
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", colors.line.darkened(0.2))
	outer.add_child(separator)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	outer.add_child(content)
	category_panel = VBoxContainer.new()
	category_panel.custom_minimum_size.x = 92
	category_panel.add_theme_constant_override("separation", 12)
	content.add_child(category_panel)
	for spec in [["plants", "starter", "Plant starters"], ["supplies", "soil", "Soil and feed"], ["equipment", "equipment", "Equipment"]]:
		var button := _icon_button(spec[1], spec[2], 76)
		button.pressed.connect(_set_category.bind(spec[0]))
		category_panel.add_child(button)
		category_buttons[spec[0]] = button
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	item_grid = GridContainer.new()
	item_grid.columns = 3
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 14)
	item_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(item_grid)
	cart_panel = PanelContainer.new()
	cart_panel.custom_minimum_size.x = 285
	cart_panel.add_theme_stylebox_override("panel", _panel_style(colors.ink, colors.line.darkened(0.28), 1, 3, 16))
	content.add_child(cart_panel)
	var cart_column := VBoxContainer.new()
	cart_column.add_theme_constant_override("separation", 12)
	cart_panel.add_child(cart_column)
	cart_header = Label.new()
	cart_header.text = "ORDER"
	cart_header.add_theme_font_size_override("font_size", 21)
	cart_header.add_theme_color_override("font_color", colors.text)
	cart_column.add_child(cart_header)
	var cart_scroll := ScrollContainer.new()
	cart_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cart_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cart_column.add_child(cart_scroll)
	cart_list = VBoxContainer.new()
	cart_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cart_list.add_theme_constant_override("separation", 8)
	cart_scroll.add_child(cart_list)
	cart_total_label = Label.new()
	cart_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cart_total_label.add_theme_font_size_override("font_size", 24)
	cart_total_label.add_theme_color_override("font_color", colors.gold)
	cart_column.add_child(cart_total_label)
	checkout_button = Button.new()
	checkout_button.text = "CONFIRM ORDER"
	checkout_button.custom_minimum_size.y = 54
	checkout_button.add_theme_font_size_override("font_size", 18)
	_apply_button_style(checkout_button, true)
	checkout_button.pressed.connect(_checkout)
	cart_column.add_child(checkout_button)


func _set_mode(mode: String) -> void:
	current_mode = mode
	_refresh_all()


func _set_category(category: String) -> void:
	current_mode = "shop"
	current_category = category
	_refresh_all()


func _refresh_all() -> void:
	if rebuilding or not item_grid:
		return
	rebuilding = true
	_refresh_tabs()
	_rebuild_items()
	_rebuild_cart()
	rebuilding = false


func _refresh_tabs() -> void:
	_set_button_active(shop_tab, current_mode == "shop")
	_set_button_active(sell_tab, current_mode == "sell")
	category_panel.visible = current_mode == "shop"
	cart_panel.visible = current_mode == "shop"
	for category in category_buttons:
		_set_button_active(category_buttons[category], current_mode == "shop" and current_category == category)
	status_label.text = "DRONE QUEUE %d" % game_state.pending_orders.size() if game_state.pending_orders.size() else "DRONE LINK READY"


func _rebuild_items() -> void:
	_free_children(item_grid)
	if current_mode == "sell":
		var found := false
		for item_id in game_state.inventory:
			if item_id.begins_with("offshoot:") and game_state.item_count(item_id) > 0:
				item_grid.add_child(_sell_card(item_id))
				found = true
		if not found:
			item_grid.add_child(_empty_state("No offshoots are ready for collection."))
		return
	match current_category:
		"plants":
			for species_id in PlantCatalog.species_ids():
				item_grid.add_child(_shop_card("starter:%s" % species_id))
		"supplies":
			for item_id in PlantCatalog.BASE_ITEMS:
				if PlantCatalog.BASE_ITEMS[item_id].kind in ["soil", "feed"]:
					item_grid.add_child(_shop_card(item_id))
		"equipment":
			for item_id in ["empty_pot", "watering_can", "trowel", "secateurs"]:
				item_grid.add_child(_equipment_card(item_id))


func _shop_card(item_id: String) -> Control:
	var data := PlantCatalog.item(item_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(205, 218)
	card.add_theme_stylebox_override("panel", _panel_style(colors.panel_2, colors.line.darkened(0.22), 1, 4, 14))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	card.add_child(column)
	var icon := GreenhouseIcon.new()
	icon.icon_kind = str(data.icon)
	if data.kind == "starter":
		var species := PlantCatalog.species(str(data.species))
		icon.icon_kind = "species:%s" % str(data.species)
		icon.icon_color = Color(species.accent)
		icon.secondary_color = Color(species.accent).darkened(0.28)
	icon.custom_minimum_size = Vector2(60, 60)
	column.add_child(icon)
	var name_label := Label.new()
	name_label.text = str(data.name)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", colors.text)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.y = 44
	column.add_child(name_label)
	var detail := Label.new()
	if data.kind == "starter":
		var plant := PlantCatalog.species(str(data.species))
		detail.text = "%s / %s\n%s water" % [PlantCatalog.SOIL_NAMES[plant.soil], PlantCatalog.FEED_NAMES[plant.feed], _water_label(float(plant.water_use))]
	else:
		detail.text = "For %s profiles" % str(data.profile).capitalize()
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", colors.muted)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(detail)
	var add_button := Button.new()
	add_button.text = "+  %d leaves" % int(data.price)
	add_button.custom_minimum_size.y = 42
	_apply_button_style(add_button, true)
	add_button.pressed.connect(_add_item.bind(item_id))
	column.add_child(add_button)
	return card


func _equipment_card(item_id: String) -> Control:
	var data := PlantCatalog.item(item_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(205, 218)
	card.add_theme_stylebox_override("panel", _panel_style(colors.panel_2, colors.line.darkened(0.22), 1, 4, 14))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var icon := GreenhouseIcon.new()
	icon.icon_kind = str(data.icon)
	icon.custom_minimum_size = Vector2(68, 68)
	column.add_child(icon)
	var name_label := Label.new()
	name_label.text = str(data.name)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	column.add_child(name_label)
	var status := Label.new()
	status.text = "ON POTTING BENCH" if item_id == "empty_pot" else "ON TOOL RACK"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", colors.accent)
	status.add_theme_font_size_override("font_size", 14)
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(status)
	return card


func _sell_card(item_id: String) -> Control:
	var data := PlantCatalog.item(item_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(205, 190)
	card.add_theme_stylebox_override("panel", _panel_style(colors.panel_2, colors.line.darkened(0.22), 1, 4, 14))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	card.add_child(column)
	var icon := GreenhouseIcon.new()
	var species_id := str(data.species)
	var species := PlantCatalog.species(species_id)
	icon.icon_kind = "species:%s" % species_id
	var mutation_id := str(data.get("mutation", ""))
	icon.icon_color = Color("#dce8ae") if mutation_id == "variegated" else Color(species.accent)
	icon.secondary_color = Color("#72a66b") if mutation_id == "variegated" else Color(species.accent).darkened(0.28)
	icon.custom_minimum_size = Vector2(62, 62)
	column.add_child(icon)
	var name_label := Label.new()
	name_label.text = str(data.name)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 17)
	column.add_child(name_label)
	var sell_button := Button.new()
	sell_button.text = "SELL  %d leaves  x%d" % [int(data.price), game_state.item_count(item_id)]
	sell_button.custom_minimum_size.y = 44
	_apply_button_style(sell_button, true)
	sell_button.pressed.connect(_sell_item.bind(item_id))
	column.add_child(sell_button)
	return card


func _empty_state(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(500, 160)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", colors.muted)
	return label


func _rebuild_cart() -> void:
	_free_children(cart_list)
	if game_state.cart.is_empty():
		var empty := Label.new()
		empty.text = "Select stock for the next drone run."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", colors.muted)
		empty.add_theme_font_size_override("font_size", 15)
		cart_list.add_child(empty)
	else:
		for item_id in game_state.cart:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var label := Label.new()
			label.text = "%dx  %s" % [int(game_state.cart[item_id]), PlantCatalog.display_name(item_id)]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_size_override("font_size", 14)
			row.add_child(label)
			var remove := Button.new()
			remove.text = "-"
			remove.custom_minimum_size = Vector2(34, 34)
			_apply_button_style(remove, false)
			remove.pressed.connect(_remove_item.bind(item_id))
			row.add_child(remove)
			cart_list.add_child(row)
	cart_total_label.text = "%d leaves" % game_state.cart_total()
	checkout_button.disabled = game_state.cart.is_empty() or game_state.cart_total() > game_state.currency
	checkout_button.visible = current_mode == "shop"
	cart_total_label.visible = current_mode == "shop"


func _add_item(item_id: String) -> void:
	game_state.add_to_cart(item_id)


func _remove_item(item_id: String) -> void:
	game_state.remove_from_cart(item_id)


func _checkout() -> void:
	game_state.checkout_cart()


func _sell_item(item_id: String) -> void:
	game_state.sell_offshoot(item_id)


func _water_label(rate: float) -> String:
	if rate >= 0.0058:
		return "High"
	if rate >= 0.0035:
		return "Medium"
	return "Low"


func _icon_button(kind: String, tooltip: String, pixels: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(pixels, pixels)
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	_apply_button_style(button, false)
	var icon := GreenhouseIcon.new()
	icon.icon_kind = kind
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 13
	icon.offset_top = 13
	icon.offset_right = -13
	icon.offset_bottom = -13
	button.add_child(icon)
	return button


func _set_button_active(button: Button, active: bool) -> void:
	if not button:
		return
	var background: Color = colors.panel_2
	button.add_theme_stylebox_override("normal", _panel_style(background, colors.accent if active else colors.line.darkened(0.2), 2 if active else 1, 4, 8))
	button.modulate = Color.WHITE if active else Color(0.78, 0.84, 0.80, 1.0)


func _apply_button_style(button: Button, accented: bool) -> void:
	var base: Color = colors.accent.darkened(0.46) if accented else colors.panel_2
	button.add_theme_stylebox_override("normal", _panel_style(base, colors.line, 1, 3, 8))
	button.add_theme_stylebox_override("hover", _panel_style(base.lightened(0.10), colors.accent, 2, 3, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(base.darkened(0.08), colors.gold, 2, 3, 8))
	button.add_theme_stylebox_override("disabled", _panel_style(colors.ink, colors.line.darkened(0.3), 1, 3, 8))
	button.add_theme_color_override("font_color", colors.text)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", colors.muted.darkened(0.2))


func _panel_style(background: Color, border: Color, border_width: int, corner_radius: int, content_margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style


func _free_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
