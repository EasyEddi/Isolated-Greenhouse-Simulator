class_name GreenhouseStorageSlot
extends GreenhouseInteractable

var game_state: GreenhouseGameState
var slot_id: String = ""
var stored_item_id: String = ""
var visual_root: Node3D


func configure_slot(id: String, state: GreenhouseGameState, initial_item: String = "", pad_color: Color = Color("#4a6258")) -> GreenhouseStorageSlot:
	slot_id = id
	game_state = state
	configure(id, "Storage slot", _on_slot_interacted, "E", _slot_prompt)
	_build_slot(pad_color)
	set_stored_item(initial_item)
	return self


func _slot_prompt(selected_item: String) -> String:
	if not stored_item_id.is_empty():
		return "E  Take %s" % PlantCatalog.display_name(stored_item_id)
	if _is_storable(selected_item) and game_state.item_count(selected_item) > 0:
		return "E  Store %s" % PlantCatalog.display_name(selected_item)
	return "Equip an item to store"


func _on_slot_interacted(_player, selected_item: String) -> bool:
	if not stored_item_id.is_empty():
		var collected_item := stored_item_id
		set_stored_item("")
		game_state.add_item(collected_item)
		game_state.message_requested.emit("%s returned to inventory" % PlantCatalog.display_name(collected_item), "good")
		return true
	if not _is_storable(selected_item) or not game_state.remove_item(selected_item):
		game_state.message_requested.emit("Equip an item before using this slot", "warning")
		return false
	set_stored_item(selected_item)
	game_state.message_requested.emit("%s stored on the shelf" % PlantCatalog.display_name(selected_item), "neutral")
	return true


func set_stored_item(item_id: String) -> void:
	stored_item_id = item_id if _is_storable(item_id) else ""
	_refresh_visual()


func snapshot() -> Dictionary:
	return {"slot_id": slot_id, "item_id": stored_item_id}


func _is_storable(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	var kind := str(PlantCatalog.item(item_id).get("kind", ""))
	return kind in ["tool", "equipment", "soil", "feed", "starter", "offshoot"]


func _build_slot(pad_color: Color) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.68, 0.30, 0.54)
	collision.shape = shape
	collision.position.y = 0.14
	add_child(collision)
	var pad := MeshInstance3D.new()
	pad.name = "ShelfPad"
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(0.62, 0.018, 0.48)
	pad.mesh = pad_mesh
	var pad_material := StandardMaterial3D.new()
	pad_material.albedo_color = pad_color
	pad_material.roughness = 0.90
	pad.material_override = pad_material
	add_child(pad)
	visual_root = Node3D.new()
	visual_root.name = "StoredItemVisual"
	add_child(visual_root)


func _refresh_visual() -> void:
	if not visual_root:
		return
	for child in visual_root.get_children():
		child.queue_free()
	if stored_item_id.is_empty():
		return
	var data := PlantCatalog.item(stored_item_id)
	var model_name := ""
	match str(data.get("kind", "")):
		"tool":
			model_name = {"watering_can": "watering_can", "trowel": "trowel", "secateurs": "secateurs"}.get(stored_item_id, "")
		"equipment":
			model_name = "empty_pot"
		"soil":
			model_name = "soil_bag"
		"feed":
			model_name = "fertilizer_bag"
		"starter", "offshoot":
			model_name = "plant_starter"
	if model_name.is_empty():
		return
	var resource = load("res://assets/models/props/%s.glb" % model_name)
	if not resource is PackedScene:
		return
	var model := resource.instantiate() as Node3D
	visual_root.add_child(model)
	var scale_factor: float = {
		"watering_can": 0.70,
		"trowel": 1.10,
		"secateurs": 1.30,
		"empty_pot": 0.88,
		"soil_bag": 0.76,
		"fertilizer_bag": 0.76,
		"plant_starter": 0.82,
	}.get(model_name, 0.80)
	model.scale = Vector3.ONE * scale_factor
	model.position.y = 0.025
	if model_name in ["soil_bag", "fertilizer_bag"]:
		model.rotation = Vector3(PI * 0.5, 0.0, PI)
		model.position.y = 0.075
	elif model_name in ["trowel", "secateurs"]:
		model.rotation.y = PI * 0.5
