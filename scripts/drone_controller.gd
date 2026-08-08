class_name GreenhouseDroneController
extends Node3D

signal delivery_landed(order: Dictionary)
signal delivery_collected(order: Dictionary)

enum FlightState {
	IDLE,
	APPROACH,
	LOWER,
	DROP,
	RISE,
	DEPART,
}

var game_state: GreenhouseGameState
var delivery_parent: Node3D
var entry_position: Vector3
var hover_position: Vector3
var pad_position: Vector3
var flight_state := FlightState.IDLE
var order_queue: Array[Dictionary] = []
var active_order: Dictionary = {}
var crate_order: Dictionary = {}
var drone_visual: Node3D
var package_visual: Node3D
var rotor_discs: Array[Node3D] = []
var delivery_crate: GreenhouseInteractable
var state_time: float = 0.0
var segment_duration: float = 1.0
var segment_start: Vector3
var segment_end: Vector3
var loaded_visual: Node3D
var empty_visual: Node3D


func configure(state: GreenhouseGameState, parent: Node3D, entry: Vector3, hover: Vector3, pad: Vector3) -> GreenhouseDroneController:
	game_state = state
	delivery_parent = parent
	entry_position = entry
	hover_position = hover
	pad_position = pad
	_build_drone()
	game_state.delivery_requested.connect(queue_order)
	return self


func _process(delta: float) -> void:
	for index in range(rotor_discs.size()):
		rotor_discs[index].rotate_y(delta * (18.0 + index * 1.8))
	if flight_state == FlightState.IDLE:
		if not order_queue.is_empty() and not is_instance_valid(delivery_crate):
			_start_next_order()
		return
	state_time += delta
	var t := clampf(state_time / maxf(segment_duration, 0.01), 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	position = segment_start.lerp(segment_end, eased)
	position.y += sin(Time.get_ticks_msec() * 0.006) * 0.035
	if segment_end != segment_start:
		var direction := (segment_end - segment_start).normalized()
		rotation.z = lerpf(rotation.z, -direction.x * 0.12, delta * 3.5)
	if t >= 1.0:
		_advance_flight()


func queue_order(order: Dictionary) -> void:
	order_queue.append(order.duplicate(true))
	if flight_state == FlightState.IDLE and not is_instance_valid(delivery_crate):
		_start_next_order()


func _start_next_order() -> void:
	if order_queue.is_empty():
		return
	active_order = order_queue.pop_front()
	visible = true
	position = entry_position
	rotation = Vector3.ZERO
	if loaded_visual:
		loaded_visual.visible = true
	if empty_visual:
		empty_visual.visible = false
	_begin_segment(FlightState.APPROACH, entry_position, hover_position + Vector3(0, 0.65, 0), 4.2)
	game_state.message_requested.emit("Delivery drone entering the hall", "neutral")


func _advance_flight() -> void:
	match flight_state:
		FlightState.APPROACH:
			_begin_segment(FlightState.LOWER, position, hover_position, 1.6)
		FlightState.LOWER:
			flight_state = FlightState.DROP
			state_time = 0.0
			_drop_crate()
			_begin_segment(FlightState.RISE, position, hover_position + Vector3(0, 0.85, 0), 1.4)
		FlightState.RISE:
			_begin_segment(FlightState.DEPART, position, entry_position, 3.6)
		FlightState.DEPART:
			flight_state = FlightState.IDLE
			visible = false
			active_order = {}
			state_time = 0.0


func _begin_segment(next_state: FlightState, from: Vector3, to: Vector3, duration: float) -> void:
	flight_state = next_state
	segment_start = from
	segment_end = to
	segment_duration = duration
	state_time = 0.0


func _drop_crate() -> void:
	if is_instance_valid(delivery_crate):
		return
	delivery_crate = GreenhouseInteractable.new()
	crate_order = active_order.duplicate(true)
	delivery_crate.name = "DeliveryCrate_%s" % str(crate_order.get("id", "order"))
	delivery_crate.position = pad_position + Vector3(0, 0.42, 0)
	delivery_crate.configure(
		"delivery_crate",
		"Collect delivery",
		_on_crate_interacted,
		"E",
		_crate_prompt,
	)
	delivery_parent.add_child(delivery_crate)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.92, 0.68, 0.78)
	collision.shape = shape
	delivery_crate.add_child(collision)
	var crate_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.92, 0.68, 0.78)
	crate_mesh.mesh = mesh
	var crate_material := StandardMaterial3D.new()
	crate_material.albedo_color = Color("#9b7047")
	crate_material.roughness = 0.90
	crate_mesh.material_override = crate_material
	delivery_crate.add_child(crate_mesh)
	for offset in [-0.28, 0.28]:
		var strap := MeshInstance3D.new()
		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.10, 0.70, 0.80)
		strap.mesh = strap_mesh
		strap.position.x = offset
		var strap_material := StandardMaterial3D.new()
		strap_material.albedo_color = Color("#d5c469")
		strap_material.roughness = 0.64
		strap.material_override = strap_material
		delivery_crate.add_child(strap)
	if loaded_visual:
		loaded_visual.visible = false
	if empty_visual:
		empty_visual.visible = true
	delivery_landed.emit(crate_order.duplicate(true))
	game_state.message_requested.emit("Package landed on the delivery pad", "good")


func _crate_prompt(_selected_item: String) -> String:
	var item_total := 0
	for item_id in Dictionary(crate_order.get("items", {})):
		item_total += int(crate_order.items[item_id])
	return "E  Collect delivery (%d items)" % item_total


func _on_crate_interacted(_player, _selected_item: String) -> bool:
	if crate_order.is_empty() or not is_instance_valid(delivery_crate):
		return false
	var collected := crate_order.duplicate(true)
	game_state.collect_delivery(str(crate_order.id), Dictionary(crate_order.items))
	delivery_crate.queue_free()
	delivery_crate = null
	crate_order = {}
	delivery_collected.emit(collected)
	return true


func _build_drone() -> void:
	name = "DeliveryDrone"
	visible = false
	var loaded_resource = load("res://assets/models/props/delivery_drone_package.glb")
	if loaded_resource is PackedScene:
		loaded_visual = loaded_resource.instantiate()
		drone_visual = loaded_visual
		add_child(loaded_visual)
	else:
		drone_visual = Node3D.new()
		add_child(drone_visual)
	var empty_resource = load("res://assets/models/props/delivery_drone.glb")
	if empty_resource is PackedScene:
		empty_visual = empty_resource.instantiate()
		empty_visual.visible = false
		add_child(empty_visual)
	package_visual = loaded_visual
	var disc_material := StandardMaterial3D.new()
	disc_material.albedo_color = Color(0.25, 0.78, 0.82, 0.20)
	disc_material.emission_enabled = true
	disc_material.emission = Color("#5fb4b6")
	disc_material.emission_energy_multiplier = 0.45
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for offset in [Vector3(-0.48, 0.08, -0.38), Vector3(0.48, 0.08, -0.38), Vector3(-0.48, 0.08, 0.38), Vector3(0.48, 0.08, 0.38)]:
		var disc := MeshInstance3D.new()
		var disc_mesh := CylinderMesh.new()
		disc_mesh.top_radius = 0.28
		disc_mesh.bottom_radius = 0.28
		disc_mesh.height = 0.012
		disc.mesh = disc_mesh
		disc.material_override = disc_material
		disc.position = offset
		add_child(disc)
		rotor_discs.append(disc)


func force_complete_active_delivery() -> void:
	if active_order.is_empty() and not order_queue.is_empty():
		active_order = order_queue.pop_front()
	if active_order.is_empty():
		return
	position = hover_position
	_drop_crate()
	flight_state = FlightState.IDLE
	visible = false
