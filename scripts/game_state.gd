class_name GreenhouseGameState
extends Node

signal state_changed
signal message_requested(text: String, tone: String)
signal delivery_requested(order: Dictionary)
signal objective_changed(text: String)

const SAVE_PATH := "user://isolated_greenhouse_save.json"
const SAVE_BACKUP_PATH := "user://isolated_greenhouse_save.json.bak"
const SAVE_TEMP_PATH := "user://isolated_greenhouse_save.json.tmp"
const SAVE_VERSION := 1

const OBJECTIVES := [
	"Use the office terminal and order a plant starter.",
	"Collect the package from the drone delivery pad.",
	"Prepare an empty pot with the correct soil.",
	"Plant the delivered starter.",
	"Water and feed the plant until it is healthy.",
	"Grow a plant to maturity and harvest an offshoot.",
	"Sell an offshoot through the office terminal.",
	"Build a thriving collection at your own pace.",
]

var currency: int = 85
var inventory: Dictionary = {}
var cart: Dictionary = {}
var pending_orders: Array[Dictionary] = []
var hotbar: Array[String] = ["watering_can", "trowel", "secateurs", "soil:aroid", "feed:foliage"]
var selected_hotbar_index: int = 0
var watering_can_liters: float = 4.0
var watering_can_capacity: float = 4.0
var watering_can_empty_notified := false
var objective_index: int = 0
var plants_snapshot: Array = []
var storage_snapshot: Array = []
var total_sales: int = 0
var total_harvests: int = 0
var session_seconds: float = 0.0
var next_order_sequence: int = 1
var tutorial_care_actions: Dictionary = {}


func _ready() -> void:
	if inventory.is_empty():
		new_game()


func _process(delta: float) -> void:
	session_seconds += delta


func new_game() -> void:
	currency = 85
	inventory = {
		"watering_can": 1,
		"trowel": 1,
		"secateurs": 1,
		"soil:aroid": 1,
		"feed:foliage": 1,
	}
	cart.clear()
	pending_orders.clear()
	hotbar = ["watering_can", "trowel", "secateurs", "soil:aroid", "feed:foliage"]
	selected_hotbar_index = 0
	watering_can_liters = watering_can_capacity
	watering_can_empty_notified = false
	objective_index = 0
	plants_snapshot.clear()
	storage_snapshot.clear()
	total_sales = 0
	total_harvests = 0
	session_seconds = 0.0
	next_order_sequence = 1
	tutorial_care_actions.clear()
	state_changed.emit()
	objective_changed.emit(current_objective())


func current_objective() -> String:
	return OBJECTIVES[clampi(objective_index, 0, OBJECTIVES.size() - 1)]


func advance_objective(event: String) -> void:
	var expected := ["order", "delivery", "soil", "plant", "care", "harvest", "sale"]
	if objective_index < expected.size() and event == expected[objective_index]:
		objective_index += 1
		objective_changed.emit(current_objective())
		state_changed.emit()


func register_care_action(action: String) -> void:
	if objective_index != 4 or action not in ["water", "feed"]:
		return
	tutorial_care_actions[action] = true
	if tutorial_care_actions.has("water") and tutorial_care_actions.has("feed"):
		advance_objective("care")
	else:
		state_changed.emit()


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0 or PlantCatalog.item(item_id).is_empty():
		return
	inventory[item_id] = item_count(item_id) + amount
	_refresh_dynamic_hotbar(item_id)
	state_changed.emit()


func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or item_count(item_id) < amount:
		return false
	var remaining := item_count(item_id) - amount
	if remaining <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = remaining
	state_changed.emit()
	return true


func selected_item() -> String:
	if selected_hotbar_index < 0 or selected_hotbar_index >= hotbar.size():
		return ""
	var item_id := hotbar[selected_hotbar_index]
	return item_id if item_count(item_id) > 0 else ""


func select_hotbar(index: int) -> void:
	if hotbar.is_empty():
		hotbar = _normalized_hotbar([])
	selected_hotbar_index = posmod(index, hotbar.size())
	state_changed.emit()


func equip_item(item_id: String) -> void:
	if item_count(item_id) <= 0:
		return
	var existing_slot := hotbar.find(item_id)
	if existing_slot >= 0:
		select_hotbar(existing_slot)
		return
	var item_data := PlantCatalog.item(item_id)
	var preferred_slot := 3
	if item_data.get("kind") in ["starter", "offshoot"]:
		preferred_slot = 4
	hotbar[preferred_slot] = item_id
	selected_hotbar_index = preferred_slot
	state_changed.emit()


func refill_watering_can() -> void:
	watering_can_liters = watering_can_capacity
	watering_can_empty_notified = false
	message_requested.emit("Watering can refilled", "good")
	state_changed.emit()


func consume_water(liters: float) -> float:
	var used := minf(maxf(liters, 0.0), watering_can_liters)
	watering_can_liters -= used
	if watering_can_liters <= 0.001 and not watering_can_empty_notified:
		watering_can_empty_notified = true
		message_requested.emit("The watering can is empty", "warning")
	elif watering_can_liters > 0.001:
		watering_can_empty_notified = false
	state_changed.emit()
	return used


func add_to_cart(item_id: String, amount: int = 1) -> bool:
	var data := PlantCatalog.item(item_id)
	if item_id not in PlantCatalog.shop_item_ids() or data.is_empty() or int(data.get("price", 0)) <= 0:
		return false
	cart[item_id] = mini(int(cart.get(item_id, 0)) + maxi(amount, 1), 99)
	state_changed.emit()
	return true


func remove_from_cart(item_id: String) -> void:
	if not cart.has(item_id):
		return
	var amount := int(cart[item_id]) - 1
	if amount <= 0:
		cart.erase(item_id)
	else:
		cart[item_id] = amount
	state_changed.emit()


func cart_total() -> int:
	var total := 0
	for item_id in cart:
		total += int(PlantCatalog.item(item_id).get("price", 0)) * int(cart[item_id])
	return total


func checkout_cart() -> bool:
	var total := cart_total()
	if cart.is_empty():
		message_requested.emit("The order is empty", "warning")
		return false
	if not _cart_is_valid():
		message_requested.emit("The order contains invalid stock", "warning")
		return false
	if total > currency:
		message_requested.emit("Not enough leaves for this order", "warning")
		return false
	currency -= total
	var order := {
		"id": "%d-%04d" % [Time.get_unix_time_from_system(), next_order_sequence],
		"items": cart.duplicate(true),
		"total": total,
	}
	next_order_sequence += 1
	pending_orders.append(order)
	cart.clear()
	delivery_requested.emit(order.duplicate(true))
	advance_objective("order")
	message_requested.emit("Order confirmed. Drone inbound.", "good")
	state_changed.emit()
	return true


func collect_delivery(order_id: String) -> bool:
	var order_index := -1
	for index in range(pending_orders.size()):
		if str(pending_orders[index].get("id", "")) == order_id:
			order_index = index
			break
	if order_index < 0:
		message_requested.emit("Delivery record not found", "warning")
		return false
	var order := pending_orders[order_index]
	pending_orders.remove_at(order_index)
	for item_id in Dictionary(order.get("items", {})):
		add_item(item_id, int(order.items[item_id]))
	advance_objective("delivery")
	message_requested.emit("Delivery stored in your inventory", "good")
	state_changed.emit()
	return true


func sell_offshoot(item_id: String) -> bool:
	var data := PlantCatalog.item(item_id)
	if data.get("kind") != "offshoot" or not remove_item(item_id):
		return false
	var value := int(data.get("price", 0))
	currency += value
	total_sales += value
	advance_objective("sale")
	message_requested.emit("Sold for %d leaves" % value, "good")
	state_changed.emit()
	return true


func register_harvest(species_id: String, mutation_id: String = "") -> void:
	var item_id := "offshoot:%s" % species_id
	if not mutation_id.is_empty():
		item_id += "#%s" % mutation_id
	add_item(item_id)
	total_harvests += 1
	advance_objective("harvest")


func set_plants_snapshot(snapshot: Array) -> void:
	plants_snapshot = snapshot.duplicate(true)


func set_storage_snapshot(snapshot: Array) -> void:
	storage_snapshot = snapshot.duplicate(true)


func save_game(snapshot: Array = plants_snapshot, stored_items: Array = storage_snapshot) -> bool:
	set_plants_snapshot(snapshot)
	set_storage_snapshot(stored_items)
	var payload := {
		"version": SAVE_VERSION,
		"currency": currency,
		"inventory": inventory,
		"pending_orders": pending_orders,
		"hotbar": hotbar,
		"selected_hotbar_index": selected_hotbar_index,
		"watering_can_liters": watering_can_liters,
		"objective_index": objective_index,
		"plants": plants_snapshot,
		"storage": storage_snapshot,
		"total_sales": total_sales,
		"total_harvests": total_harvests,
		"session_seconds": session_seconds,
		"next_order_sequence": next_order_sequence,
		"tutorial_care_actions": tutorial_care_actions,
	}
	var file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		message_requested.emit("Could not save the greenhouse", "warning")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	var save_path := ProjectSettings.globalize_path(SAVE_PATH)
	var backup_path := ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
	var temp_path := ProjectSettings.globalize_path(SAVE_TEMP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_BACKUP_PATH):
			DirAccess.remove_absolute(backup_path)
		if DirAccess.rename_absolute(save_path, backup_path) != OK:
			DirAccess.remove_absolute(temp_path)
			message_requested.emit("Could not protect the previous save", "warning")
			return false
	if DirAccess.rename_absolute(temp_path, save_path) != OK:
		if FileAccess.file_exists(SAVE_BACKUP_PATH) and not FileAccess.file_exists(SAVE_PATH):
			DirAccess.rename_absolute(backup_path, save_path)
		DirAccess.remove_absolute(temp_path)
		message_requested.emit("Could not finish saving the greenhouse", "warning")
		return false
	message_requested.emit("Greenhouse saved", "neutral")
	return true


func load_game() -> Dictionary:
	var payload := _read_save_payload(SAVE_PATH)
	var recovered := false
	if payload.is_empty():
		payload = _read_save_payload(SAVE_BACKUP_PATH)
		recovered = not payload.is_empty()
	if payload.is_empty():
		return {}
	currency = clampi(_safe_int(payload.get("currency", 85), 85), 0, 999999999)
	inventory = _sanitized_inventory(payload.get("inventory", {}))
	pending_orders = _sanitized_pending_orders(payload.get("pending_orders", []))
	var saved_hotbar: Array = payload.get("hotbar", []) if payload.get("hotbar", []) is Array else []
	hotbar = _normalized_hotbar(saved_hotbar)
	selected_hotbar_index = clampi(_safe_int(payload.get("selected_hotbar_index", 0)), 0, hotbar.size() - 1)
	watering_can_liters = clampf(_safe_float(payload.get("watering_can_liters", watering_can_capacity), watering_can_capacity), 0.0, watering_can_capacity)
	watering_can_empty_notified = watering_can_liters <= 0.001
	objective_index = clampi(_safe_int(payload.get("objective_index", 0)), 0, OBJECTIVES.size() - 1)
	plants_snapshot = _sanitized_snapshot_array(payload.get("plants", []), 64)
	storage_snapshot = _sanitized_storage(payload.get("storage", []))
	total_sales = maxi(0, _safe_int(payload.get("total_sales", 0)))
	total_harvests = maxi(0, _safe_int(payload.get("total_harvests", 0)))
	session_seconds = maxf(0.0, _safe_float(payload.get("session_seconds", 0.0)))
	next_order_sequence = maxi(1, _safe_int(payload.get("next_order_sequence", 1), 1))
	tutorial_care_actions = _sanitized_tutorial_actions(payload.get("tutorial_care_actions", {}))
	_recover_essential_tools()
	state_changed.emit()
	objective_changed.emit(current_objective())
	if recovered:
		message_requested.emit("Recovered the previous greenhouse save", "warning")
	var sanitized_payload := payload.duplicate(true)
	sanitized_payload["plants"] = plants_snapshot
	sanitized_payload["storage"] = storage_snapshot
	return sanitized_payload


static func has_save_file() -> bool:
	return not _read_save_payload(SAVE_PATH).is_empty() or not _read_save_payload(SAVE_BACKUP_PATH).is_empty()


static func _read_save_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
		return {}
	return Dictionary(parsed)


func _cart_is_valid() -> bool:
	var shop_items := PlantCatalog.shop_item_ids()
	for raw_item_id in cart:
		var item_id := str(raw_item_id)
		if item_id not in shop_items or _safe_int(cart[raw_item_id]) <= 0:
			return false
	return true


static func _safe_int(value: Variant, fallback: int = 0) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and String(value).is_valid_int():
		return int(value)
	return fallback


static func _safe_float(value: Variant, fallback: float = 0.0) -> float:
	if value is int or value is float:
		return float(value)
	if value is String and String(value).is_valid_float():
		return float(value)
	return fallback


static func _sanitized_inventory(source: Variant) -> Dictionary:
	var result := {}
	if not source is Dictionary:
		return result
	for raw_item_id in source:
		var item_id := str(raw_item_id)
		var amount := clampi(_safe_int(source[raw_item_id]), 0, 999)
		if amount > 0 and not PlantCatalog.item(item_id).is_empty():
			result[item_id] = amount
	return result


static func _sanitized_pending_orders(source: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not source is Array:
		return result
	var shop_items := PlantCatalog.shop_item_ids()
	var seen_ids := {}
	for raw_order in source:
		if result.size() >= 32 or not raw_order is Dictionary:
			continue
		var order := Dictionary(raw_order)
		var order_id := str(order.get("id", "")).strip_edges()
		if order_id.is_empty() or seen_ids.has(order_id):
			continue
		var raw_items = order.get("items", {})
		if not raw_items is Dictionary:
			continue
		var items := {}
		var total := 0
		for raw_item_id in raw_items:
			var item_id := str(raw_item_id)
			var amount := clampi(_safe_int(raw_items[raw_item_id]), 0, 99)
			if amount <= 0 or item_id not in shop_items:
				continue
			items[item_id] = amount
			total += int(PlantCatalog.item(item_id).get("price", 0)) * amount
		if items.is_empty():
			continue
		seen_ids[order_id] = true
		result.append({"id": order_id, "items": items, "total": total})
	return result


static func _sanitized_snapshot_array(source: Variant, limit: int) -> Array:
	var result: Array = []
	if not source is Array:
		return result
	for raw_snapshot in source:
		if result.size() >= limit:
			break
		if raw_snapshot is Dictionary and not str(raw_snapshot.get("slot_id", "")).is_empty():
			result.append(Dictionary(raw_snapshot).duplicate(true))
	return result


static func _sanitized_storage(source: Variant) -> Array:
	var result: Array = []
	for snapshot in _sanitized_snapshot_array(source, 12):
		var item_id := str(snapshot.get("item_id", ""))
		if item_id.is_empty() or not PlantCatalog.item(item_id).is_empty():
			result.append({"slot_id": str(snapshot.slot_id), "item_id": item_id})
	return result


static func _sanitized_tutorial_actions(source: Variant) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for action in ["water", "feed"]:
			if source.get(action, false) is bool and bool(source.get(action, false)):
				result[action] = true
	return result


func _recover_essential_tools() -> void:
	var stored_items := {}
	for snapshot in storage_snapshot:
		stored_items[str(snapshot.get("item_id", ""))] = true
	for tool_id in ["watering_can", "trowel", "secateurs"]:
		if item_count(tool_id) <= 0 and not stored_items.has(tool_id):
			inventory[tool_id] = 1


func _refresh_dynamic_hotbar(item_id: String) -> void:
	var data := PlantCatalog.item(item_id)
	if data.get("kind") in ["soil", "feed"] and (hotbar[3].is_empty() or item_count(hotbar[3]) <= 0):
		hotbar[3] = item_id
	if data.get("kind") in ["starter", "offshoot"] and (hotbar[4].is_empty() or item_count(hotbar[4]) <= 0):
		hotbar[4] = item_id


func _normalized_hotbar(source: Array) -> Array[String]:
	var defaults: Array[String] = ["watering_can", "trowel", "secateurs", "soil:aroid", "feed:foliage"]
	var result: Array[String] = []
	for index in range(defaults.size()):
		var item_id := str(source[index]) if index < source.size() else defaults[index]
		if item_id.is_empty() or PlantCatalog.item(item_id).is_empty():
			item_id = defaults[index]
		result.append(item_id)
	return result
