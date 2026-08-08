extends SceneTree

var failures: Array[String] = []
var checks := 0
var save_existed := false
var save_backup := PackedByteArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_backup_save()
	_test_catalog()
	_test_asset_manifest()
	await _test_economy_and_save()
	await _test_world_and_plants()
	await _test_long_term_plant_simulation()
	_restore_save()
	if failures.is_empty():
		print("ISOLATED_GREENHOUSE_TEST_SUITE: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILURE: %s" % failure)
		print("ISOLATED_GREENHOUSE_TEST_SUITE: FAIL (%d of %d checks)" % [failures.size(), checks])
		quit(1)


func _test_catalog() -> void:
	_expect(PlantCatalog.species_ids().size() == 12, "catalog has exactly twelve launch species")
	_expect(PlantCatalog.SOIL_NAMES.size() == 4, "catalog has four soil profiles")
	_expect(PlantCatalog.FEED_NAMES.size() == 4, "catalog has four feed profiles")
	_expect(PlantCatalog.shop_item_ids().size() == 20, "shop contains twelve starters and eight care supplies")
	var seen_names: Dictionary = {}
	for species_id in PlantCatalog.species_ids():
		var data := PlantCatalog.species(species_id)
		_expect(not seen_names.has(data.name), "%s has a unique display name" % species_id)
		seen_names[data.name] = true
		_expect(PlantCatalog.SOIL_NAMES.has(data.soil), "%s references a valid soil" % species_id)
		_expect(PlantCatalog.FEED_NAMES.has(data.feed), "%s references a valid feed" % species_id)
		_expect(float(data.water_use) > 0.0, "%s consumes water" % species_id)
		_expect(float(data.nutrition_use) > 0.0, "%s consumes nutrition" % species_id)
		_expect(float(data.optimal_low) < float(data.optimal_high), "%s has an ordered moisture range" % species_id)
		_expect(float(data.growth_seconds) >= 180.0, "%s does not grow instantly" % species_id)
		_expect(int(data.offshoot_value) > int(data.starter_price), "%s supports a profitable care loop" % species_id)
		_expect(FileAccess.file_exists(str(data.model)), "%s model exists" % species_id)
		_expect(PlantCatalog.item("starter:%s" % species_id).kind == "starter", "%s starter resolves" % species_id)
		_expect(PlantCatalog.item("offshoot:%s" % species_id).kind == "offshoot", "%s offshoot resolves" % species_id)
		var mutation_item := PlantCatalog.item("offshoot:%s#variegated" % species_id)
		_expect(mutation_item.kind == "offshoot" and int(mutation_item.price) > int(data.offshoot_value), "%s mutation offshoot has a premium" % species_id)


func _test_asset_manifest() -> void:
	var props := [
		"bed", "desk_setup", "fridge", "lower_cabinet", "microwave", "nightstand", "oven",
		"storage_shelf", "stovetop", "upper_cabinet", "greenhouse", "garden_faucet",
		"watering_can", "trowel", "secateurs", "empty_pot", "soil_bag", "fertilizer_bag",
		"plant_starter", "delivery_drone", "delivery_drone_package",
	]
	for prop_name in props:
		_expect(FileAccess.file_exists("res://assets/models/props/%s.glb" % prop_name), "%s prop exists" % prop_name)
	for sound_name in ["ambient_hall", "water_pour", "drone_motor", "ui_confirm", "ui_warning", "delivery", "harvest"]:
		var path := "res://assets/audio/%s.wav" % sound_name
		_expect(FileAccess.file_exists(path), "%s sound exists" % sound_name)
		var stream = load(path)
		_expect(stream is AudioStream and stream.get_length() > 0.20, "%s sound imports" % sound_name)


func _test_economy_and_save() -> void:
	var state := GreenhouseGameState.new()
	root.add_child(state)
	await process_frame
	state.new_game()
	_expect(state.currency == 85, "new shift starts with 85 leaves")
	_expect(state.item_count("watering_can") == 1, "watering can starts on the rack")
	var original_hotbar := state.hotbar.duplicate()
	state.equip_item("watering_can")
	_expect(state.selected_hotbar_index == 0 and state.hotbar == original_hotbar, "equipping an existing tool selects without duplicating it")
	var repaired_hotbar := state._normalized_hotbar(["watering_can", "unknown:item"])
	_expect(repaired_hotbar.size() == 5 and repaired_hotbar[1] == "trowel", "short or invalid save hotbars repair to five usable slots")
	var empty_warnings := [0]
	state.message_requested.connect(func(_text, tone):
		if tone == "warning":
			empty_warnings[0] += 1
	)
	state.watering_can_liters = 0.01
	state.consume_water(0.02)
	state.consume_water(0.02)
	_expect(empty_warnings[0] == 1, "empty watering can warning fires once per emptying")
	state.refill_watering_can()
	state.consume_water(5.0)
	_expect(empty_warnings[0] == 2, "refilling rearms the empty watering can warning")
	_expect(not state.add_to_cart("unknown:item"), "unknown items cannot enter cart")
	_expect(state.add_to_cart("starter:mint"), "starter enters cart")
	_expect(state.add_to_cart("soil:moist"), "soil enters cart")
	_expect(state.add_to_cart("feed:herb"), "feed enters cart")
	_expect(state.cart_total() == 30, "cart calculates deterministic total")
	_expect(state.checkout_cart(), "affordable cart checks out")
	_expect(state.currency == 55, "checkout deducts leaves")
	_expect(state.pending_orders.size() == 1, "checkout creates pending order")
	_expect(state.objective_index == 1, "checkout advances onboarding")
	var order: Dictionary = state.pending_orders[0]
	state.collect_delivery(str(order.id), Dictionary(order.items))
	_expect(state.pending_orders.is_empty(), "collection clears pending order")
	_expect(state.item_count("starter:mint") == 1, "collection grants starter")
	_expect(state.objective_index == 2, "collection advances onboarding")
	state.objective_index = 4
	state.register_care_action("water")
	_expect(state.objective_index == 4, "watering alone does not complete the two-part care objective")
	state.register_care_action("feed")
	_expect(state.objective_index == 5, "watering and feeding complete the care objective together")
	_expect(state.add_to_cart("starter:mint"), "a rapid follow-up order enters the cart")
	_expect(state.checkout_cart(), "a rapid follow-up order checks out")
	var follow_up_order: Dictionary = state.pending_orders[0]
	_expect(str(follow_up_order.id) != str(order.id), "rapid consecutive orders receive unique ids")
	state.collect_delivery(str(follow_up_order.id), Dictionary(follow_up_order.items))
	var before_failed_checkout := state.currency
	state.cart = {"starter:alocasia_polly": 100}
	_expect(not state.checkout_cart(), "unaffordable order is rejected")
	_expect(state.currency == before_failed_checkout, "failed checkout preserves leaves")
	state.cart.clear()
	state.currency = 123
	state.add_item("offshoot:mint", 2)
	state.tutorial_care_actions = {"water": true}
	_expect(state.add_to_cart("soil:loam"), "pending save test order enters cart")
	_expect(state.checkout_cart(), "pending save test order checks out")
	var saved_order_id := str(state.pending_orders[0].id)
	var snapshot := [{"slot_id": "test", "species_id": "mint", "growth": 0.5}]
	_expect(state.save_game(snapshot), "save file writes")
	var loaded := GreenhouseGameState.new()
	root.add_child(loaded)
	await process_frame
	var payload := loaded.load_game()
	_expect(not payload.is_empty(), "save file loads")
	_expect(loaded.currency == 116, "currency round-trips")
	_expect(loaded.item_count("offshoot:mint") == 2, "inventory round-trips")
	_expect(loaded.plants_snapshot.size() == 1, "plant snapshots round-trip")
	_expect(bool(loaded.tutorial_care_actions.get("water", false)), "partial care tutorial progress round-trips")
	_expect(loaded.pending_orders.size() == 1 and str(loaded.pending_orders[0].id) == saved_order_id, "pending drone order round-trips")
	state.queue_free()
	loaded.queue_free()
	await process_frame


func _test_long_term_plant_simulation() -> void:
	var state := GreenhouseGameState.new()
	root.add_child(state)
	await process_frame
	state.new_game()
	for species_id in PlantCatalog.species_ids():
		var data := PlantCatalog.species(species_id)
		var actor := GreenhousePlantActor.new()
		root.add_child(actor)
		actor.configure("soak_%s" % species_id, state, {
			"slot_id": "soak_%s" % species_id,
			"species_id": species_id,
			"soil_profile": data.soil,
			"soil_prepared": true,
			"feed_profile": data.feed,
			"moisture": (float(data.optimal_low) + float(data.optimal_high)) * 0.5,
			"nutrition": 0.82,
			"health": 0.90,
			"growth": 0.05,
			"offshoot_progress": 0.0,
		})
		var growth_before := actor.growth
		for _minute in range(6):
			actor.moisture = (float(data.optimal_low) + float(data.optimal_high)) * 0.5
			actor.nutrition = 0.82
			actor._process(60.0)
		_expect(actor.growth > growth_before, "%s advances during six minutes of matching care" % species_id)
		_expect(actor.growth >= 0.0 and actor.growth <= 1.0, "%s keeps long-term growth bounded" % species_id)
		_expect(actor.health >= 0.08 and actor.health <= 1.0, "%s keeps long-term health bounded" % species_id)
		_expect(actor.moisture >= -0.08 and actor.moisture <= 1.16, "%s keeps long-term moisture bounded" % species_id)
		var saved := actor.snapshot()
		actor.apply_snapshot(saved)
		_expect(actor.species_id == species_id and is_equal_approx(actor.growth, float(saved.growth)), "%s survives a snapshot round-trip" % species_id)
		actor.queue_free()
		await process_frame

	var preferred := PlantCatalog.species("monstera_deliciosa")
	var correct := GreenhousePlantActor.new()
	var wrong := GreenhousePlantActor.new()
	root.add_child(correct)
	root.add_child(wrong)
	await process_frame
	var baseline := {
		"species_id": "monstera_deliciosa", "soil_profile": preferred.soil,
		"soil_prepared": true, "feed_profile": preferred.feed, "moisture": 0.62,
		"nutrition": 0.85, "health": 0.90, "growth": 0.20,
	}
	correct.configure("soil_correct", state, baseline)
	var wrong_baseline := baseline.duplicate(true)
	wrong_baseline.soil_profile = "gritty"
	wrong.configure("soil_wrong", state, wrong_baseline)
	correct._process(45.0)
	wrong._process(45.0)
	_expect(correct.growth > wrong.growth, "matching soil grows faster than a mismatched mix")
	correct.moisture = 1.16
	var overwatered_health := correct.health
	correct._process(8.0)
	_expect(correct.health < overwatered_health, "sustained overwatering damages health")
	wrong.moisture = 0.0
	var drought_health := wrong.health
	wrong._process(8.0)
	_expect(wrong.health < drought_health, "sustained drought damages health")
	correct.queue_free()
	wrong.queue_free()
	state.queue_free()
	await process_frame


func _test_world_and_plants() -> void:
	var state := GreenhouseGameState.new()
	root.add_child(state)
	await process_frame
	state.new_game()
	var world := GreenhouseWorldBuilder.new()
	root.add_child(world)
	world.build(state)
	await process_frame
	_expect(world.plant_actors.size() == 16, "world builds sixteen physical plant stations")
	_expect(world.delivery_root != null, "world builds delivery department")
	_expect(world.terminal_interactable != null, "world builds terminal interaction")
	_expect(world.faucet_interactable != null, "world builds faucet interaction")
	_expect(_count_rendered_instances(world) > 1500, "hall contains detailed rendered geometry")
	_expect(_count_nodes_of_type(world, "CollisionShape3D") > 20, "hall contains gameplay collision")
	var empty_slot: GreenhousePlantActor
	var mutation_count := 0
	for plant in world.plant_actors:
		_expect(plant.growth >= 0.0 and plant.growth <= 1.0, "%s growth is bounded" % plant.slot_id)
		_expect(plant.health >= 0.0 and plant.health <= 1.0, "%s health is bounded" % plant.slot_id)
		if plant.species_id.is_empty() and empty_slot == null:
			empty_slot = plant
		if not plant.mutation_id.is_empty():
			mutation_count += 1
	_expect(empty_slot != null, "world leaves preparation space for the player")
	_expect(mutation_count == 2, "world contains two discoverable rare specimens")
	var healthy_color := Color("#4e9b61")
	var stressed_color := GreenhousePlantActor.health_tinted_color(healthy_color, 0.10)
	_expect(not stressed_color.is_equal_approx(healthy_color), "poor health computes visible foliage discoloration")
	if empty_slot:
		empty_slot.mutation_chance = 0.0
		state.add_item("soil:moist")
		state.add_item("starter:mint")
		state.add_item("feed:herb")
		_expect(empty_slot.interact(null, "soil:moist"), "correct soil can enter empty pot")
		_expect(empty_slot.soil_visual.visible, "prepared soil is visibly present in empty pot")
		_expect(not empty_slot.interact(null, "starter:mint"), "starter cannot bypass soil preparation")
		_expect(empty_slot.interact(null, "trowel"), "trowel prepares soil")
		_expect(empty_slot.interact(null, "starter:mint"), "prepared pot accepts starter")
		_expect(not empty_slot.soil_visual.visible, "prepared soil marker hides after planting")
		var growth_before := empty_slot.growth
		empty_slot.moisture = 0.66
		empty_slot.nutrition = 0.70
		empty_slot._process(4.0)
		_expect(empty_slot.growth > growth_before, "healthy care advances continuous growth")
		var health_before_drought := empty_slot.health
		empty_slot.moisture = 0.0
		empty_slot._process(12.0)
		_expect(empty_slot.health < health_before_drought, "drought reduces health")
		empty_slot.health = 0.95
		empty_slot.moisture = 0.68
		empty_slot.nutrition = 0.80
		empty_slot.growth = 1.0
		empty_slot.offshoot_progress = 0.999
		empty_slot._process(1.0)
		_expect(empty_slot.offshoot_ready, "mature healthy plant produces offshoot")
		_expect(empty_slot.offshoot_marker.visible, "ready offshoot has a visible daughter plant")
		_expect(empty_slot.interact(null, "secateurs"), "secateurs harvest ready offshoot")
		_expect(not empty_slot.offshoot_marker.visible, "daughter plant hides after harvest")
		var leaves_before_sale := state.currency
		_expect(state.sell_offshoot("offshoot:mint"), "harvested offshoot sells")
		_expect(state.currency > leaves_before_sale, "sale awards leaves")
	state.add_item("offshoot:monstera_deliciosa#variegated")
	var premium_before := state.currency
	_expect(state.sell_offshoot("offshoot:monstera_deliciosa#variegated"), "variegated offshoot sells")
	_expect(state.currency - premium_before > int(PlantCatalog.species("monstera_deliciosa").offshoot_value), "mutation sale awards a premium")
	var snapshots := world.plant_snapshots()
	_expect(snapshots.size() == world.plant_actors.size(), "world serializes every station")
	world.restore_plant_snapshots(snapshots)
	_expect(world.plant_snapshots().size() == snapshots.size(), "world restores station snapshots")
	var restored_mutations := 0
	for snapshot in world.plant_snapshots():
		if not str(snapshot.get("mutation_id", "")).is_empty():
			restored_mutations += 1
	_expect(restored_mutations == mutation_count, "mutation metadata survives world snapshot restore")
	world.queue_free()
	state.queue_free()
	await process_frame


func _count_nodes_of_type(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		count += _count_nodes_of_type(child, type_name)
	return count


func _count_rendered_instances(node: Node) -> int:
	var count := 0
	if node is MultiMeshInstance3D and node.multimesh:
		count += node.multimesh.instance_count
	elif node is MeshInstance3D:
		count += 1
	for child in node.get_children():
		count += _count_rendered_instances(child)
	return count


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  PASS: %s" % label)
	else:
		failures.append(label)


func _backup_save() -> void:
	save_existed = FileAccess.file_exists(GreenhouseGameState.SAVE_PATH)
	if save_existed:
		var source := FileAccess.open(GreenhouseGameState.SAVE_PATH, FileAccess.READ)
		if source:
			save_backup = source.get_buffer(source.get_length())


func _restore_save() -> void:
	var global_path := ProjectSettings.globalize_path(GreenhouseGameState.SAVE_PATH)
	if save_existed:
		var target := FileAccess.open(GreenhouseGameState.SAVE_PATH, FileAccess.WRITE)
		if target:
			target.store_buffer(save_backup)
	elif FileAccess.file_exists(GreenhouseGameState.SAVE_PATH):
		DirAccess.remove_absolute(global_path)
