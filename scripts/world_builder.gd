class_name GreenhouseWorldBuilder
extends Node3D

signal terminal_open_requested
signal plant_inspection_requested(plant: GreenhousePlantActor)

const MAIN_LENGTH := 23.5
const MAIN_WIDTH := 20.0
const SIDE_LENGTH := 7.5
const SIDE_WIDTH := 10.0
const WALL_HEIGHT := 6.0
const WALL_THICKNESS := 0.22

var game_state: GreenhouseGameState
var plant_actors: Array[GreenhousePlantActor] = []
var terminal_interactable: GreenhouseInteractable
var faucet_interactable: GreenhouseInteractable
var plants_root: Node3D
var delivery_root: Node3D
var delivery_pad_position := Vector3(9.0, 0.08, 6.5)
var drone_entry_position := Vector3(12.8, 5.0, 7.4)
var drone_hover_position := Vector3(9.0, 2.65, 6.5)
var player_spawn_position := Vector3(-9.2, 0.05, 1.5)
var player_spawn_yaw := -PI * 0.50

var materials: Dictionary = {}


func build(state: GreenhouseGameState, saved_plants: Array = []) -> GreenhouseWorldBuilder:
	game_state = state
	name = "GreenhouseHall"
	_build_materials()
	_build_environment()
	_build_shell()
	_build_living_department()
	_build_office_department()
	_build_storage_department()
	_build_nursery_department(saved_plants)
	_build_greenhouse_department()
	_build_water_station()
	_build_delivery_department()
	_build_atmosphere_props()
	return self


func _build_materials() -> void:
	materials = {
		"concrete": _material(Color("#59646a"), 0.93),
		"concrete_dark": _material(Color("#333e43"), 0.95),
		"rubber": _material(Color("#385565"), 0.82),
		"brick_a": _material(Color("#b9827f"), 0.90),
		"brick_b": _material(Color("#d1a38d"), 0.91),
		"brick_c": _material(Color("#a6adb0"), 0.94),
		"mortar": _material(Color("#a9bec0"), 0.97),
		"wood": _material(Color("#6b4931"), 0.79),
		"wood_light": _material(Color("#a4774f"), 0.76),
		"steel": _material(Color("#41565b"), 0.55, 0.35),
		"paint_green": _material(Color("#36675d"), 0.66, 0.10),
		"paint_yellow": _material(Color("#c6a24e"), 0.70, 0.04),
		"terracotta": _material(Color("#aa5f3e"), 0.84),
		"soil": _material(Color("#2f2118"), 0.98),
		"glass": _material(Color(0.48, 0.76, 0.77, 0.24), 0.16),
		"screen": _material(Color("#0f2526"), 0.35, 0.05, Color("#2f9b83"), 1.3),
		"delivery": _material(Color("#d4c46c"), 0.72, 0.06),
		"rug": _material(Color("#8a6d72"), 0.92),
	}


func _material(color: Color, roughness: float, metallic: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	if color.a < 0.999:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
		result.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission
		result.emission_energy_multiplier = emission_energy
	return result


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "HallEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#9bc2ca")
	environment.background_energy_multiplier = 0.55
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b9d2cc")
	environment.ambient_light_energy = 0.34
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment.fog_enabled = true
	environment.fog_light_color = Color("#adc4c1")
	environment.fog_light_energy = 0.25
	environment.fog_density = 0.004
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "SkylightSun"
	sun.rotation_degrees = Vector3(-52.0, -31.0, 0.0)
	sun.light_color = Color("#fff0cf")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	add_child(sun)
	for spec in [
		[Vector3(-14.8, 4.4, 5.0), Color("#ffd9ad"), 0.68],
		[Vector3(-7.5, 4.5, 5.2), Color("#ffd9b9"), 0.62],
		[Vector3(0.0, 4.7, 2.5), Color("#d7ecdf"), 0.74],
		[Vector3(6.8, 4.8, -4.8), Color("#d2f1e1"), 0.82],
		[Vector3(8.7, 4.4, 6.4), Color("#d6e8ef"), 0.66],
	]:
		var light := OmniLight3D.new()
		light.position = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.omni_range = 8.0
		light.shadow_enabled = true
		add_child(light)


func _build_shell() -> void:
	var shell := Node3D.new()
	shell.name = "HallShell"
	add_child(shell)
	_add_box(shell, "MainFloor", Vector3(0, -0.12, 0), Vector3(MAIN_LENGTH, 0.24, MAIN_WIDTH), materials.concrete, true)
	_add_box(shell, "LivingWingFloor", Vector3(-15.5, -0.105, 5.0), Vector3(SIDE_LENGTH, 0.21, SIDE_WIDTH), materials.rubber, true)
	_add_floor_grid(shell)
	_add_brick_wall(shell, "SouthWall", Vector3(0, WALL_HEIGHT * 0.5, -MAIN_WIDTH * 0.5), Vector3(MAIN_LENGTH, WALL_HEIGHT, WALL_THICKNESS), false)
	_add_brick_wall(shell, "EastWall", Vector3(MAIN_LENGTH * 0.5, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, MAIN_WIDTH), true)
	_add_brick_wall(shell, "NorthWall", Vector3(-3.75, WALL_HEIGHT * 0.5, MAIN_WIDTH * 0.5), Vector3(MAIN_LENGTH + SIDE_LENGTH, WALL_HEIGHT, WALL_THICKNESS), false)
	_add_brick_wall(shell, "WestWingWall", Vector3(-19.25, WALL_HEIGHT * 0.5, 5.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, SIDE_WIDTH), true)
	_add_brick_wall(shell, "WingSouthWall", Vector3(-15.5, WALL_HEIGHT * 0.5, 0.0), Vector3(SIDE_LENGTH, WALL_HEIGHT, WALL_THICKNESS), false)
	_add_brick_wall(shell, "WestLowerWall", Vector3(-11.75, WALL_HEIGHT * 0.5, -5.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, 10.0), true)
	for x in [-16.0, -8.0, 0.0, 8.0]:
		_add_box(shell, "CeilingBeam_%s" % x, Vector3(x, 5.72, 0.0), Vector3(0.18, 0.22, 19.5), materials.steel, false)
	for z in [-7.5, -2.5, 2.5, 7.5]:
		_add_box(shell, "RoofRail_%s" % z, Vector3(0.0, 5.76, z), Vector3(23.2, 0.16, 0.16), materials.steel, false)
	for x in [-7.5, 0.0, 7.5]:
		_add_box(shell, "Skylight_%s" % x, Vector3(x, 5.80, 0.0), Vector3(5.4, 0.035, 16.5), materials.glass, false)


func _add_floor_grid(parent: Node3D) -> void:
	for x in range(-10, 12, 2):
		_add_box(parent, "FloorJointX_%d" % x, Vector3(float(x), 0.011, 0.0), Vector3(0.025, 0.012, 19.8), materials.concrete_dark, false)
	for z in range(-8, 10, 2):
		_add_box(parent, "FloorJointZ_%d" % z, Vector3(0.0, 0.012, float(z)), Vector3(23.3, 0.012, 0.025), materials.concrete_dark, false)


func _add_brick_wall(parent: Node3D, wall_name: String, center: Vector3, size: Vector3, vertical: bool) -> void:
	_add_box(parent, wall_name, center, size, materials.mortar, true)
	var length := size.z if vertical else size.x
	var rows := 14
	var columns := maxi(1, int(length / 0.82))
	var rng := RandomNumberGenerator.new()
	rng.seed = wall_name.hash()
	for row in range(rows):
		var brick_height := 0.32
		var y := 0.25 + row * 0.39
		var offset := 0.40 if row % 2 else 0.0
		for column in range(columns):
			if rng.randf() < 0.055 and row > 2:
				continue
			var along := -length * 0.5 + 0.42 + column * 0.82 + offset
			if along > length * 0.5 - 0.18:
				continue
			var color_key: String = ["brick_a", "brick_b", "brick_c"][rng.randi_range(0, 2)]
			var brick_size := Vector3(0.76, brick_height, 0.035)
			var brick_position := center
			brick_position.y = y
			if vertical:
				brick_position.z += along
				brick_position.x += -signf(center.x) * (WALL_THICKNESS * 0.5 + 0.019)
				brick_size = Vector3(0.035, brick_height, 0.76)
			else:
				brick_position.x += along
				brick_position.z += -signf(center.z) * (WALL_THICKNESS * 0.5 + 0.019)
			_add_box(parent, "%s_Brick_%d_%d" % [wall_name, row, column], brick_position, brick_size, materials[color_key], false)


func _build_living_department() -> void:
	var area := Node3D.new()
	area.name = "ResidentialDepartment"
	add_child(area)
	_add_sign(area, "RESIDENTIAL", Vector3(-15.5, 3.6, 9.78), Vector3(0, PI, 0), Color("#f0cf9b"))
	_add_box(area, "LivingRug", Vector3(-16.1, 0.025, 6.4), Vector3(4.5, 0.035, 2.7), materials.rug, false)
	_add_prop(area, "Bed", "bed", Vector3(-17.5, 0.02, 7.8), 0.0, Vector3(2.2, 0.9, 1.25), Vector3(0, 0.45, 0))
	_add_prop(area, "Nightstand", "nightstand", Vector3(-15.7, 0.02, 8.1), 0.0, Vector3(0.7, 0.7, 0.7), Vector3(0, 0.35, 0))
	_add_prop(area, "Fridge", "fridge", Vector3(-18.15, 0.02, 2.0), PI * 0.5, Vector3(0.82, 1.9, 0.72), Vector3(0, 0.95, 0))
	for index in range(2):
		_add_prop(area, "LowerCabinet_%d" % index, "lower_cabinet", Vector3(-16.75 + index * 1.1, 0.02, 1.75), PI, Vector3(1.05, 0.75, 0.70), Vector3(0, 0.38, 0))
	_add_prop(area, "Oven", "oven", Vector3(-14.55, 0.02, 1.75), PI, Vector3(0.9, 0.9, 0.78), Vector3(0, 0.45, 0))
	_add_prop(area, "Stovetop", "stovetop", Vector3(-14.55, 0.93, 1.72), PI, Vector3.ZERO)
	_add_prop(area, "Microwave", "microwave", Vector3(-16.75, 0.88, 1.65), PI, Vector3.ZERO)
	_add_box(area, "KitchenBacksplash", Vector3(-16.2, 1.15, 0.18), Vector3(4.6, 1.2, 0.08), materials.paint_green, false)


func _build_office_department() -> void:
	var area := Node3D.new()
	area.name = "OfficeDepartment"
	add_child(area)
	_add_sign(area, "OPERATIONS", Vector3(-7.8, 3.6, 9.78), Vector3(0, PI, 0), Color("#a7d5c4"))
	_add_prop(area, "OfficeDesk", "desk_setup", Vector3(-8.1, 0.02, 8.35), PI, Vector3(2.5, 1.25, 1.0), Vector3(0, 0.62, 0))
	terminal_interactable = GreenhouseInteractable.new()
	terminal_interactable.name = "OnlineShopTerminal"
	terminal_interactable.position = Vector3(-8.1, 1.23, 7.92)
	terminal_interactable.configure("terminal", "Use terminal", _on_terminal_interacted, "F")
	area.add_child(terminal_interactable)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.88, 0.58, 0.16)
	collision.shape = shape
	terminal_interactable.add_child(collision)
	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.82, 0.50, 0.035)
	screen.mesh = screen_mesh
	screen.material_override = materials.screen
	screen.position.z = -0.085
	terminal_interactable.add_child(screen)
	_add_box(area, "OfficeMat", Vector3(-8.1, 0.02, 6.95), Vector3(3.2, 0.035, 2.5), materials.paint_green, false)


func _on_terminal_interacted(_player, _selected_item: String) -> bool:
	terminal_open_requested.emit()
	return true


func _build_storage_department() -> void:
	var area := Node3D.new()
	area.name = "StorageDepartment"
	add_child(area)
	_add_sign(area, "STORAGE", Vector3(-3.25, 3.5, 9.78), Vector3(0, PI, 0), Color("#e1c46d"))
	for index in range(3):
		var x := -4.8 + index * 1.8
		_add_prop(area, "StorageShelf_%d" % index, "storage_shelf", Vector3(x, 0.02, 8.45), PI, Vector3(1.82, 1.8, 0.72), Vector3(0, 0.9, 0))
	for index in range(4):
		_add_prop(area, "SoilBag_%d" % index, "soil_bag", Vector3(-4.9 + index * 0.46, 0.11, 7.95), PI * 0.5, Vector3.ZERO)
		_add_prop(area, "FeedBag_%d" % index, "fertilizer_bag", Vector3(-2.8 + index * 0.46, 0.11, 7.95), PI * 0.5, Vector3.ZERO)
	_add_box(area, "StorageLane", Vector3(-3.0, 0.025, 6.55), Vector3(6.4, 0.035, 1.0), materials.delivery, false)


func _build_nursery_department(saved_plants: Array) -> void:
	var area := Node3D.new()
	area.name = "NurseryDepartment"
	add_child(area)
	plants_root = Node3D.new()
	plants_root.name = "PlantSlots"
	area.add_child(plants_root)
	_add_sign(area, "NURSERY", Vector3(4.5, 3.5, 9.78), Vector3(0, PI, 0), Color("#9ad2a5"))
	var bench_specs := [
		[Vector3(2.4, 0.0, 4.35), 0.0],
		[Vector3(6.9, 0.0, 4.35), 0.0],
		[Vector3(2.4, 0.0, 1.65), PI],
	]
	var slot_positions: Array[Vector3] = []
	for bench_index in range(bench_specs.size()):
		var bench_position: Vector3 = bench_specs[bench_index][0]
		_add_potting_bench(area, "NurseryBench_%d" % bench_index, bench_position, float(bench_specs[bench_index][1]))
		for slot_index in range(4):
			slot_positions.append(bench_position + Vector3(-1.35 + slot_index * 0.9, 0.94, 0.0))
	var defaults := _default_plant_snapshots()
	var snapshots := saved_plants if not saved_plants.is_empty() else defaults
	for index in range(slot_positions.size()):
		var slot_snapshot: Dictionary = {}
		if index < snapshots.size():
			slot_snapshot = Dictionary(snapshots[index]).duplicate(true)
		slot_snapshot["slot_id"] = "nursery_%02d" % index
		_add_plant_slot(slot_positions[index], slot_snapshot)


func _build_greenhouse_department() -> void:
	var area := Node3D.new()
	area.name = "GreenhouseDepartment"
	add_child(area)
	_add_sign(area, "GREENHOUSE", Vector3(6.8, 3.3, -9.77), Vector3.ZERO, Color("#b9e6c8"))
	_add_prop(area, "GreenhouseShell", "greenhouse", Vector3(7.0, 0.02, -5.9), 0.0, Vector3.ZERO)
	_add_box(area, "GreenhouseBackCollision", Vector3(7.0, 1.35, -7.18), Vector3(5.0, 2.7, 0.10), materials.glass, true)
	_add_box(area, "GreenhouseLeftCollision", Vector3(4.52, 1.35, -5.9), Vector3(0.10, 2.7, 2.5), materials.glass, true)
	_add_box(area, "GreenhouseRightCollision", Vector3(9.48, 1.35, -5.9), Vector3(0.10, 2.7, 2.5), materials.glass, true)
	_add_box(area, "GreenhouseFrontLeft", Vector3(5.55, 1.35, -4.64), Vector3(2.05, 2.7, 0.10), materials.glass, true)
	_add_box(area, "GreenhouseFrontRight", Vector3(8.65, 1.35, -4.64), Vector3(1.65, 2.7, 0.10), materials.glass, true)
	_add_potting_bench(area, "GreenhouseBench", Vector3(7.0, 0.0, -6.45), 0.0)
	for index in range(4):
		var snapshot := {
			"slot_id": "greenhouse_%02d" % index,
			"species_id": ["boston_fern", "sunflower", "lavender", "echeveria"][index],
			"soil_profile": ["moist", "loam", "gritty", "gritty"][index],
			"soil_prepared": true,
			"feed_profile": ["foliage", "bloom", "herb", "succulent"][index],
			"moisture": [0.70, 0.58, 0.34, 0.25][index],
			"nutrition": 0.58,
			"health": 0.94,
			"growth": [0.76, 0.85, 0.68, 0.72][index],
			"offshoot_progress": 0.20,
		}
		_add_plant_slot(Vector3(5.65 + index * 0.9, 0.94, -6.45), snapshot)


func _build_water_station() -> void:
	var area := Node3D.new()
	area.name = "WaterDepartment"
	add_child(area)
	_add_sign(area, "WATER", Vector3(-11.56, 3.0, -6.5), Vector3(0, PI * 0.5, 0), Color("#8cc4d8"))
	_add_box(area, "WaterCounter", Vector3(-10.7, 0.52, -7.2), Vector3(1.65, 1.04, 0.72), materials.steel, true)
	_add_prop(area, "GardenFaucet", "garden_faucet", Vector3(-10.85, 1.08, -7.45), PI * 0.5, Vector3.ZERO)
	faucet_interactable = GreenhouseInteractable.new()
	faucet_interactable.name = "WaterFaucet"
	faucet_interactable.position = Vector3(-10.7, 1.18, -7.05)
	faucet_interactable.configure("faucet", "Refill watering can", _on_faucet_interacted, "E")
	area.add_child(faucet_interactable)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 0.5, 0.4)
	collision.shape = shape
	faucet_interactable.add_child(collision)


func _on_faucet_interacted(_player, selected_item: String) -> bool:
	if selected_item != "watering_can":
		game_state.message_requested.emit("Equip the watering can first", "warning")
		return false
	game_state.refill_watering_can()
	return true


func _build_delivery_department() -> void:
	delivery_root = Node3D.new()
	delivery_root.name = "DeliveryDepartment"
	add_child(delivery_root)
	_add_sign(delivery_root, "DELIVERY", Vector3(11.55, 3.2, 6.5), Vector3(0, -PI * 0.5, 0), Color("#e2c96f"))
	_add_box(delivery_root, "DeliveryPad", delivery_pad_position, Vector3(2.5, 0.08, 2.5), materials.delivery, false)
	_add_box(delivery_root, "DeliveryPadInner", delivery_pad_position + Vector3(0, 0.05, 0), Vector3(1.55, 0.03, 1.55), materials.concrete_dark, false)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var marker_position := delivery_pad_position + Vector3(cos(angle) * 0.86, 0.09, sin(angle) * 0.86)
		_add_box(delivery_root, "PadMarker_%s" % angle, marker_position, Vector3(0.34, 0.025, 0.34), materials.delivery, false)


func _build_atmosphere_props() -> void:
	var props := Node3D.new()
	props.name = "AtmosphereProps"
	add_child(props)
	for index in range(7):
		_add_box(props, "OverheadDuct_%d" % index, Vector3(-8.0 + index * 3.0, 5.15, -8.8), Vector3(2.4, 0.38, 0.48), materials.steel, false)
	for index in range(6):
		var planter_position := Vector3(-8.8 + index * 3.4, 0.18, -9.25)
		_add_box(props, "WallPlanter_%d" % index, planter_position, Vector3(1.1, 0.36, 0.45), materials.terracotta, false)
		_add_box(props, "WallPlanterSoil_%d" % index, planter_position + Vector3(0, 0.20, 0), Vector3(0.92, 0.06, 0.34), materials.soil, false)
	for index in range(8):
		var height := 0.8 + (index % 3) * 0.32
		_add_box(props, "Pipe_%d" % index, Vector3(-10.9 + index * 3.0, height, 9.62), Vector3(0.06, height * 1.5, 0.06), materials.steel, false)


func _add_potting_bench(parent: Node3D, bench_name: String, position: Vector3, yaw: float) -> void:
	var bench := Node3D.new()
	bench.name = bench_name
	bench.position = position
	bench.rotation.y = yaw
	parent.add_child(bench)
	_add_box(bench, "Top", Vector3(0, 0.78, 0), Vector3(3.9, 0.14, 0.82), materials.wood_light, true)
	for x in [-1.72, 1.72]:
		for z in [-0.30, 0.30]:
			_add_box(bench, "Leg_%s_%s" % [x, z], Vector3(x, 0.38, z), Vector3(0.12, 0.76, 0.12), materials.steel, true)
	_add_box(bench, "LowerShelf", Vector3(0, 0.28, 0), Vector3(3.72, 0.09, 0.68), materials.wood, false)


func _add_plant_slot(position: Vector3, snapshot: Dictionary) -> void:
	var actor := GreenhousePlantActor.new()
	actor.name = "PlantSlot_%s" % str(snapshot.get("slot_id", plant_actors.size()))
	actor.position = position
	plants_root.add_child(actor)
	actor.configure(str(snapshot.get("slot_id", actor.name)), game_state, snapshot)
	actor.inspection_requested.connect(_on_plant_inspection)
	plant_actors.append(actor)


func _on_plant_inspection(plant: GreenhousePlantActor) -> void:
	plant_inspection_requested.emit(plant)


func _default_plant_snapshots() -> Array:
	var specs := [
		["monstera_deliciosa", "aroid", "foliage", 0.58, 0.72],
		["peace_lily", "moist", "bloom", 0.63, 0.82],
		["aloe_vera", "gritty", "succulent", 0.26, 0.68],
		["mint", "moist", "herb", 0.68, 0.46],
		["golden_pothos", "aroid", "foliage", 0.54, 0.61],
		["snake_plant", "gritty", "succulent", 0.24, 0.74],
		["lily", "loam", "bloom", 0.50, 0.38],
		["alocasia_polly", "aroid", "foliage", 0.57, 0.57],
	]
	var result: Array = []
	for index in range(12):
		if index < specs.size():
			var spec: Array = specs[index]
			result.append({
				"slot_id": "nursery_%02d" % index,
				"species_id": spec[0],
				"soil_profile": spec[1],
				"soil_prepared": true,
				"feed_profile": spec[2],
				"moisture": spec[3],
				"nutrition": 0.52,
				"health": 0.90,
				"growth": spec[4],
				"offshoot_progress": 0.15 if index % 2 else 0.35,
			})
		else:
			result.append({"slot_id": "nursery_%02d" % index})
	return result


func _add_prop(parent: Node3D, prop_name: String, model_name: String, position: Vector3, yaw: float = 0.0, collision_size: Vector3 = Vector3.ZERO, collision_offset: Vector3 = Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	root.name = prop_name
	root.position = position
	root.rotation.y = yaw
	parent.add_child(root)
	var resource = load("res://assets/models/props/%s.glb" % model_name)
	if resource is PackedScene:
		root.add_child(resource.instantiate())
	if collision_size.length_squared() > 0.001:
		var body := StaticBody3D.new()
		body.position = collision_offset
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = collision_size
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
	return root


func _add_box(parent: Node3D, box_name: String, position: Vector3, size: Vector3, mat: Material, collision_enabled: bool) -> Node3D:
	var root: Node3D
	if collision_enabled:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()
	root.name = box_name
	root.position = position
	parent.add_child(root)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	return root


func _add_sign(parent: Node3D, text: String, position: Vector3, rotation: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = "Sign_%s" % text
	label.text = text
	label.position = position
	label.rotation = rotation
	label.font_size = 42
	label.outline_size = 8
	label.modulate = color
	label.outline_modulate = Color("#162a27")
	label.pixel_size = 0.005
	parent.add_child(label)


func plant_snapshots() -> Array:
	var snapshots: Array = []
	for plant in plant_actors:
		snapshots.append(plant.snapshot())
	return snapshots


func restore_plant_snapshots(snapshots: Array) -> void:
	var by_slot: Dictionary = {}
	for snapshot in snapshots:
		if snapshot is Dictionary:
			by_slot[str(snapshot.get("slot_id", ""))] = snapshot
	for plant in plant_actors:
		if by_slot.has(plant.slot_id):
			plant.apply_snapshot(Dictionary(by_slot[plant.slot_id]))


func reset_plants() -> void:
	var defaults := _default_plant_snapshots()
	var nursery_index := 0
	for plant in plant_actors:
		if plant.slot_id.begins_with("nursery_"):
			plant.apply_snapshot(Dictionary(defaults[nursery_index]))
			nursery_index += 1
