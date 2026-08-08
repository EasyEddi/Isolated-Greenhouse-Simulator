class_name GreenhouseGameState
extends Node

signal state_changed
signal message_requested(text: String, tone: String)
signal delivery_requested(order: Dictionary)
signal objective_changed(text: String)

const SAVE_PATH := "user://isolated_greenhouse_save.json"
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
	if amount <= 0:
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
	if data.is_empty() or int(data.get("price", 0)) <= 0:
		return false
	cart[item_id] = int(cart.get(item_id, 0)) + maxi(amount, 1)
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


func collect_delivery(order_id: String, items: Dictionary) -> void:
	for item_id in items:
		add_item(item_id, int(items[item_id]))
	for index in range(pending_orders.size() - 1, -1, -1):
		if str(pending_orders[index].get("id", "")) == order_id:
			pending_orders.remove_at(index)
	advance_objective("delivery")
	message_requested.emit("Delivery stored in your inventory", "good")
	state_changed.emit()


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


func save_game(snapshot: Array = plants_snapshot) -> bool:
	set_plants_snapshot(snapshot)
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
		"total_sales": total_sales,
		"total_harvests": total_harvests,
		"session_seconds": session_seconds,
		"next_order_sequence": next_order_sequence,
		"tutorial_care_actions": tutorial_care_actions,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		message_requested.emit("Could not save the greenhouse", "warning")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	message_requested.emit("Greenhouse saved", "neutral")
	return true


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var payload = JSON.parse_string(file.get_as_text())
	if not payload is Dictionary or int(payload.get("version", 0)) != SAVE_VERSION:
		return {}
	currency = int(payload.get("currency", 85))
	inventory = Dictionary(payload.get("inventory", {})).duplicate(true)
	pending_orders.clear()
	for pending_order in Array(payload.get("pending_orders", [])):
		if pending_order is Dictionary:
			pending_orders.append(Dictionary(pending_order).duplicate(true))
	hotbar = _normalized_hotbar(Array(payload.get("hotbar", hotbar)))
	selected_hotbar_index = clampi(int(payload.get("selected_hotbar_index", 0)), 0, hotbar.size() - 1)
	watering_can_liters = float(payload.get("watering_can_liters", watering_can_capacity))
	watering_can_empty_notified = watering_can_liters <= 0.001
	objective_index = int(payload.get("objective_index", 0))
	plants_snapshot = Array(payload.get("plants", [])).duplicate(true)
	total_sales = int(payload.get("total_sales", 0))
	total_harvests = int(payload.get("total_harvests", 0))
	session_seconds = float(payload.get("session_seconds", 0.0))
	next_order_sequence = maxi(1, int(payload.get("next_order_sequence", 1)))
	tutorial_care_actions = Dictionary(payload.get("tutorial_care_actions", {})).duplicate(true)
	state_changed.emit()
	objective_changed.emit(current_objective())
	return payload


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
