class_name GreenhousePlantActor
extends StaticBody3D

signal inspection_requested(plant: GreenhousePlantActor)
signal planted(plant: GreenhousePlantActor)
signal care_applied(plant: GreenhousePlantActor)
signal harvested(plant: GreenhousePlantActor)

var slot_id: String = ""
var game_state: GreenhouseGameState
var species_id: String = ""
var mutation_id: String = ""
var mutation_chance: float = 0.055
var soil_profile: String = ""
var soil_prepared: bool = false
var feed_profile: String = ""
var moisture: float = 0.0
var nutrition: float = 0.0
var health: float = 1.0
var growth: float = 0.0
var offshoot_progress: float = 0.0
var offshoot_ready: bool = false
var care_streak: float = 0.0
var simulation_multiplier: float = 1.0

var visual_root: Node3D
var empty_visual: Node3D
var plant_visual: Node3D
var offshoot_marker: MeshInstance3D
var growth_parts: Array[Dictionary] = []
var _visual_accumulator: float = 0.0
var _message_cooldown: float = 0.0


func configure(id: String, state: GreenhouseGameState, snapshot: Dictionary = {}) -> GreenhousePlantActor:
	slot_id = id
	game_state = state
	_build_base()
	if snapshot:
		apply_snapshot(snapshot)
	else:
		_update_visuals(true)
	return self


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_message_cooldown = maxf(0.0, _message_cooldown - delta)
	if species_id.is_empty():
		return
	var data := PlantCatalog.species(species_id)
	if data.is_empty():
		return
	var scaled_delta := delta * simulation_multiplier
	moisture = maxf(-0.08, moisture - float(data.water_use) * scaled_delta)
	nutrition = maxf(0.0, nutrition - float(data.nutrition_use) * scaled_delta)
	var water_quality := _range_quality(moisture, float(data.optimal_low), float(data.optimal_high))
	var feed_quality := clampf(nutrition / 0.45, 0.0, 1.0)
	var soil_quality := 1.0 if soil_profile == str(data.soil) else 0.62
	var care_quality := water_quality * 0.52 + feed_quality * 0.20 + soil_quality * 0.28
	if moisture < 0.03 or moisture > 1.04:
		health = maxf(0.08, health - 0.012 * scaled_delta)
		care_streak = 0.0
	elif care_quality < 0.48:
		health = maxf(0.08, health - 0.0032 * scaled_delta)
		care_streak = maxf(0.0, care_streak - scaled_delta)
	else:
		health = minf(1.0, health + 0.008 * scaled_delta)
		care_streak += scaled_delta
	if growth < 1.0 and health > 0.18:
		var growth_rate := (0.30 + care_quality * 0.70) * (0.45 + health * 0.55)
		growth = minf(1.0, growth + scaled_delta * growth_rate / float(data.growth_seconds))
	if growth >= 0.92 and health >= 0.68 and water_quality >= 0.48:
		offshoot_progress = minf(1.0, offshoot_progress + scaled_delta / float(data.offshoot_seconds))
		if offshoot_progress >= 1.0:
			offshoot_ready = true
	_visual_accumulator += delta
	if _visual_accumulator >= 0.08:
		_visual_accumulator = 0.0
		_update_visuals()


func get_interaction_prompt(selected_item: String = "") -> String:
	if species_id.is_empty():
		if soil_profile.is_empty():
			if selected_item.begins_with("soil:"):
				return "E  Add %s" % PlantCatalog.display_name(selected_item)
			return "Equip a soil mix"
		if not soil_prepared:
			return "E  Mix soil" if selected_item == "trowel" else "Equip the trowel"
		if selected_item.begins_with("starter:"):
			return "E  Plant %s" % PlantCatalog.display_name(selected_item).trim_suffix(" starter")
		return "Equip a plant starter"
	if selected_item == "watering_can":
		return "Hold E  Water %s" % PlantCatalog.species(species_id).name
	if selected_item.begins_with("feed:"):
		return "E  Apply %s" % PlantCatalog.display_name(selected_item)
	if selected_item == "secateurs" and offshoot_ready:
		return "E  Harvest %s offshoot" % PlantCatalog.species(species_id).name
	return "E  Inspect %s" % PlantCatalog.species(species_id).name


func uses_terminal_key() -> bool:
	return false


func interact(_player, selected_item: String = "") -> bool:
	if species_id.is_empty():
		return _interact_empty(selected_item)
	if selected_item.begins_with("feed:"):
		return _apply_feed(selected_item)
	if selected_item == "secateurs" and offshoot_ready:
		offshoot_ready = false
		offshoot_progress = 0.0
		game_state.register_harvest(species_id, mutation_id)
		game_state.message_requested.emit("Healthy offshoot harvested", "good")
		harvested.emit(self)
		_update_visuals(true)
		return true
	inspection_requested.emit(self)
	return true


func hold_interact(_player, selected_item: String, delta: float) -> bool:
	if species_id.is_empty() or selected_item != "watering_can":
		return false
	var used := game_state.consume_water(delta * 0.24)
	if used <= 0.0:
		return false
	moisture = minf(1.16, moisture + used * 0.52)
	care_applied.emit(self)
	game_state.advance_objective("care")
	_update_visuals()
	return true


func _interact_empty(selected_item: String) -> bool:
	if soil_profile.is_empty() and selected_item.begins_with("soil:"):
		if game_state.remove_item(selected_item):
			soil_profile = selected_item.trim_prefix("soil:")
			soil_prepared = false
			game_state.message_requested.emit("Soil added. Mix it with the trowel.", "neutral")
			_update_visuals(true)
			return true
		return false
	if not soil_profile.is_empty() and not soil_prepared and selected_item == "trowel":
		soil_prepared = true
		game_state.advance_objective("soil")
		game_state.message_requested.emit("Soil is loose and ready", "good")
		_update_visuals(true)
		return true
	if soil_prepared and selected_item.begins_with("starter:"):
		var new_species := selected_item.trim_prefix("starter:")
		if PlantCatalog.species(new_species).is_empty() or not game_state.remove_item(selected_item):
			return false
		species_id = new_species
		mutation_id = "variegated" if randf() < mutation_chance else ""
		moisture = 0.24
		nutrition = 0.10
		health = 0.86
		growth = 0.04
		offshoot_progress = 0.0
		offshoot_ready = false
		_load_plant_visual()
		game_state.advance_objective("plant")
		if mutation_id.is_empty():
			game_state.message_requested.emit("%s planted" % PlantCatalog.species(species_id).name, "good")
		else:
			game_state.message_requested.emit("A rare variegated shoot has emerged", "good")
		planted.emit(self)
		_update_visuals(true)
		return true
	inspection_requested.emit(self)
	return false


func _apply_feed(item_id: String) -> bool:
	if not game_state.remove_item(item_id):
		return false
	feed_profile = item_id.trim_prefix("feed:")
	var preferred := str(PlantCatalog.species(species_id).feed)
	if feed_profile == preferred:
		nutrition = minf(1.0, nutrition + 0.70)
		health = minf(1.0, health + 0.05)
		game_state.message_requested.emit("The feed suits this species", "good")
	else:
		nutrition = minf(1.0, nutrition + 0.32)
		health = maxf(0.1, health - 0.035)
		game_state.message_requested.emit("This feed is usable, but not ideal", "warning")
	game_state.advance_objective("care")
	care_applied.emit(self)
	return true


func _range_quality(value: float, low: float, high: float) -> float:
	if value >= low and value <= high:
		return 1.0
	if value < low:
		return clampf(value / maxf(low, 0.001), 0.0, 1.0)
	return clampf(1.0 - (value - high) / maxf(1.15 - high, 0.001), 0.0, 1.0)


func _build_base() -> void:
	if visual_root:
		return
	visual_root = Node3D.new()
	visual_root.name = "PlantVisual"
	add_child(visual_root)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 0.72
	shape.radius = 0.31
	collision.shape = shape
	collision.position.y = 0.36
	add_child(collision)
	_load_empty_visual()
	offshoot_marker = MeshInstance3D.new()
	offshoot_marker.name = "OffshootReadyMarker"
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.055
	marker_mesh.height = 0.11
	offshoot_marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("#c9e77e")
	marker_material.emission_enabled = true
	marker_material.emission = Color("#4d8b46")
	marker_material.emission_energy_multiplier = 0.65
	offshoot_marker.material_override = marker_material
	offshoot_marker.position = Vector3(0.22, 0.43, 0.0)
	offshoot_marker.visible = false
	visual_root.add_child(offshoot_marker)


func _load_empty_visual() -> void:
	if empty_visual:
		empty_visual.queue_free()
	var resource = load("res://assets/models/props/empty_pot.glb")
	if resource is PackedScene:
		empty_visual = resource.instantiate()
	else:
		empty_visual = Node3D.new()
	visual_root.add_child(empty_visual)


func _load_plant_visual() -> void:
	if plant_visual:
		plant_visual.queue_free()
		plant_visual = null
	growth_parts.clear()
	if species_id.is_empty():
		return
	var model_path := str(PlantCatalog.species(species_id).model)
	var resource = load(model_path)
	if not resource is PackedScene:
		game_state.message_requested.emit("Missing plant model: %s" % species_id, "warning")
		return
	plant_visual = resource.instantiate()
	plant_visual.name = "Species_%s" % species_id
	visual_root.add_child(plant_visual)
	_cache_growth_parts(plant_visual)
	_apply_mutation_visuals(plant_visual)


func _apply_mutation_visuals(node: Node) -> void:
	if mutation_id != "variegated":
		return
	if node is MeshInstance3D and node.mesh:
		for surface in range(node.mesh.get_surface_count()):
			var base_material: Material = node.get_active_material(surface)
			if not base_material is StandardMaterial3D:
				continue
			var standard_material := base_material as StandardMaterial3D
			var base_color: Color = standard_material.albedo_color
			var looks_green := base_color.g > base_color.r * 1.04 and base_color.g > base_color.b * 1.04
			var patch_hash := posmod((slot_id + node.name + str(surface)).hash(), 100)
			if looks_green and patch_hash < 58:
				var mutation_material := standard_material.duplicate() as StandardMaterial3D
				mutation_material.albedo_color = base_color.lerp(Color("#e2e9b5"), 0.68)
				node.set_surface_override_material(surface, mutation_material)
	for child in node.get_children():
		_apply_mutation_visuals(child)


func _cache_growth_parts(node: Node) -> void:
	var regex := RegEx.new()
	regex.compile("_g([0-9]{3})_")
	for child in node.get_children():
		if child is Node3D:
			var match := regex.search(child.name)
			if match:
				growth_parts.append({
					"node": child,
					"threshold": float(match.get_string(1)) / 1000.0,
					"base_scale": child.scale,
				})
		_cache_growth_parts(child)


func _update_visuals(force: bool = false) -> void:
	if not visual_root:
		return
	if empty_visual:
		empty_visual.visible = species_id.is_empty()
	if plant_visual:
		plant_visual.visible = not species_id.is_empty()
	for part in growth_parts:
		var node: Node3D = part.node
		if not is_instance_valid(node):
			continue
		var threshold := float(part.threshold)
		var emergence := smoothstep(threshold - 0.025, threshold + 0.115, growth)
		node.visible = emergence > 0.005
		if node.name.ends_with("_batch"):
			node.scale = Vector3(part.base_scale)
			if node is GeometryInstance3D:
				node.transparency = 1.0 - emergence
		else:
			node.scale = Vector3(part.base_scale) * lerpf(0.035, 1.0, emergence)
	if plant_visual:
		var stress := 1.0 - health
		plant_visual.rotation.z = sin(Time.get_ticks_msec() * 0.00055 + float(slot_id.hash() % 10)) * 0.008 - stress * 0.09
	if offshoot_marker:
		offshoot_marker.visible = offshoot_ready
		offshoot_marker.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.12)
	if force:
		_visual_accumulator = 0.0


func snapshot() -> Dictionary:
	return {
		"slot_id": slot_id,
		"species_id": species_id,
		"mutation_id": mutation_id,
		"soil_profile": soil_profile,
		"soil_prepared": soil_prepared,
		"feed_profile": feed_profile,
		"moisture": moisture,
		"nutrition": nutrition,
		"health": health,
		"growth": growth,
		"offshoot_progress": offshoot_progress,
		"offshoot_ready": offshoot_ready,
		"care_streak": care_streak,
	}


func apply_snapshot(data: Dictionary) -> void:
	species_id = str(data.get("species_id", ""))
	mutation_id = str(data.get("mutation_id", ""))
	soil_profile = str(data.get("soil_profile", ""))
	soil_prepared = bool(data.get("soil_prepared", false))
	feed_profile = str(data.get("feed_profile", ""))
	moisture = float(data.get("moisture", 0.0))
	nutrition = float(data.get("nutrition", 0.0))
	health = float(data.get("health", 1.0))
	growth = float(data.get("growth", 0.0))
	offshoot_progress = float(data.get("offshoot_progress", 0.0))
	offshoot_ready = bool(data.get("offshoot_ready", false))
	care_streak = float(data.get("care_streak", 0.0))
	if not species_id.is_empty():
		_load_plant_visual()
	_update_visuals(true)


func plant_readout() -> Dictionary:
	if species_id.is_empty():
		return {
			"name": "Empty pot",
			"soil": PlantCatalog.SOIL_NAMES.get(soil_profile, "No soil"),
			"prepared": soil_prepared,
		}
	var data := PlantCatalog.species(species_id)
	var display_name := str(data.name)
	if not mutation_id.is_empty():
		display_name += " (%s)" % PlantCatalog.MUTATION_NAMES.get(mutation_id, mutation_id.capitalize())
	return {
		"name": display_name,
		"group": data.group,
		"mutation": mutation_id,
		"growth": growth,
		"health": health,
		"moisture": moisture,
		"nutrition": nutrition,
		"soil": PlantCatalog.SOIL_NAMES.get(soil_profile, "No soil"),
		"preferred_soil": PlantCatalog.SOIL_NAMES.get(str(data.soil), str(data.soil)),
		"feed": PlantCatalog.FEED_NAMES.get(str(data.feed), str(data.feed)),
		"offshoot": offshoot_progress,
		"offshoot_ready": offshoot_ready,
	}
