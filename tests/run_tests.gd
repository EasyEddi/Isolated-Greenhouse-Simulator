extends SceneTree

var failures: Array[String] = []
var checks := 0
var save_existed := false
var save_backup := PackedByteArray()
var backup_save_existed := false
var backup_save_backup := PackedByteArray()
var temp_save_existed := false
var temp_save_backup := PackedByteArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_backup_save()
	_test_catalog()
	_test_asset_manifest()
	_test_settings_persistence()
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
	var care_accents: Dictionary = {}
	for item_id in PlantCatalog.CARE_ITEM_ACCENTS:
		care_accents[PlantCatalog.care_item_accent(item_id).to_html()] = true
	_expect(care_accents.size() == 8, "all care profiles have distinct visual accents")
	_expect(GreenhouseHUD.format_shift_duration(125.9) == "02:05", "shift duration formats minute sessions")
	_expect(GreenhouseHUD.format_shift_duration(3723.0) == "1:02:03", "shift duration formats long sessions")
	_expect(GreenhouseHUD.care_match_text("Aroid Mix", "Aroid Mix") == "Aroid Mix / matched", "care readout collapses matching profiles")
	_expect(GreenhouseHUD.care_match_text("None applied", "Foliage Feed") == "None / needs Foliage Feed", "care readout identifies missing feed")
	_expect(GreenhouseHUD.care_match_text("Bloom Feed", "Foliage Feed") == "Bloom Feed / needs Foliage Feed", "care readout identifies mismatched feed")
	var seen_names: Dictionary = {}
	var seen_model_hashes: Dictionary = {}
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
		var model_hash := FileAccess.get_sha256(str(data.model))
		_expect(not model_hash.is_empty() and not seen_model_hashes.has(model_hash), "%s uses a unique plant model asset" % species_id)
		seen_model_hashes[model_hash] = species_id
		var packed_model = load(str(data.model))
		_expect(packed_model is PackedScene, "%s model imports as a packed scene" % species_id)
		if packed_model is PackedScene:
			var model_root: Node = (packed_model as PackedScene).instantiate()
			var metrics := _model_metrics(model_root)
			_expect(int(metrics.meshes) > 0 and int(metrics.surfaces) > 0, "%s contains rendered mesh surfaces" % species_id)
			_expect(int(metrics.vertices) >= 100, "%s contains substantial modeled geometry" % species_id)
			_expect(int(metrics.normals) >= int(metrics.vertices), "%s has normals for every rendered vertex" % species_id)
			_expect(int(metrics.indices) >= 150, "%s contains indexed triangle geometry" % species_id)
			_expect(int(metrics.invalid_vertices) == 0, "%s contains no non-finite vertex positions" % species_id)
			_expect(int(metrics.materials) >= 2, "%s contains multiple authored materials" % species_id)
			_expect(int(metrics.invalid_bounds) == 0, "%s mesh bounds are finite and non-empty" % species_id)
			model_root.free()
		_expect(PlantCatalog.item("starter:%s" % species_id).kind == "starter", "%s starter resolves" % species_id)
		_expect(PlantCatalog.item("offshoot:%s" % species_id).kind == "offshoot", "%s offshoot resolves" % species_id)
		var mutation_item := PlantCatalog.item("offshoot:%s#variegated" % species_id)
		_expect(mutation_item.kind == "offshoot" and int(mutation_item.price) > int(data.offshoot_value), "%s mutation offshoot has a premium" % species_id)
	_expect(PlantCatalog.item("offshoot:mint#invented").is_empty(), "unknown mutation ids cannot become inventory items")
	_expect(GreenhousePlantActor.moisture_status(0.0, 0.4, 0.7) == "DROUGHT", "plant readout identifies drought")
	_expect(GreenhousePlantActor.moisture_status(0.3, 0.4, 0.7) == "DRY", "plant readout identifies dry soil")
	_expect(GreenhousePlantActor.moisture_status(0.55, 0.4, 0.7) == "IDEAL", "plant readout identifies ideal moisture")
	_expect(GreenhousePlantActor.moisture_status(0.85, 0.4, 0.7) == "WET", "plant readout identifies wet soil")
	_expect(GreenhousePlantActor.moisture_status(1.10, 0.4, 0.7) == "WATERLOGGED", "plant readout identifies waterlogging")


func _test_asset_manifest() -> void:
	var props := [
		"bed", "desk_setup", "fridge", "lower_cabinet", "microwave", "nightstand", "oven",
		"storage_shelf", "stovetop", "upper_cabinet", "greenhouse", "garden_faucet",
		"watering_can", "trowel", "secateurs", "empty_pot", "soil_bag", "fertilizer_bag",
		"plant_starter", "delivery_drone", "delivery_drone_package",
	]
	for prop_name in props:
		_expect(FileAccess.file_exists("res://assets/models/props/%s.glb" % prop_name), "%s prop exists" % prop_name)
	for sound_name in [
		"ambient_hall", "water_pour", "drone_motor", "ui_confirm", "ui_warning", "delivery", "harvest",
		"footstep_1", "footstep_2", "footstep_3", "footstep_4",
	]:
		var path := "res://assets/audio/%s.wav" % sound_name
		_expect(FileAccess.file_exists(path), "%s sound exists" % sound_name)
		var stream = load(path)
		_expect(stream is AudioStream and stream.get_length() > 0.20, "%s sound imports" % sound_name)


func _test_settings_persistence() -> void:
	var test_path := "user://isolated_greenhouse_settings_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	var settings := GreenhouseSettings.new()
	settings.config_path = test_path
	settings.set_look_sensitivity(0.0034)
	settings.set_master_volume(0.37)
	settings.set_fullscreen(true)
	var loaded := GreenhouseSettings.new()
	loaded.config_path = test_path
	loaded.load_and_apply()
	_expect(is_equal_approx(loaded.look_sensitivity, 0.0034), "look sensitivity preference round-trips")
	_expect(is_equal_approx(loaded.master_volume, 0.37), "master volume preference round-trips")
	_expect(loaded.fullscreen, "fullscreen preference round-trips")
	settings.free()
	loaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, false)
		AudioServer.set_bus_volume_db(master_bus, 0.0)


func _test_economy_and_save() -> void:
	var state := GreenhouseGameState.new()
	root.add_child(state)
	await process_frame
	state.new_game()
	_expect(state.currency == 85, "new shift starts with 85 leaves")
	_expect(state.item_count("watering_can") == 1, "watering can starts on the rack")
	state.add_item("unknown:item", 4)
	_expect(state.item_count("unknown:item") == 0, "runtime inventory rejects unknown items")
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
	_expect(not state.add_to_cart("offshoot:mint"), "sale stock cannot be smuggled into a purchase order")
	_expect(state.add_to_cart("starter:mint"), "starter enters cart")
	_expect(state.add_to_cart("soil:moist"), "soil enters cart")
	_expect(state.add_to_cart("feed:herb"), "feed enters cart")
	_expect(state.cart_total() == 30, "cart calculates deterministic total")
	_expect(state.checkout_cart(), "affordable cart checks out")
	_expect(state.currency == 55, "checkout deducts leaves")
	_expect(state.pending_orders.size() == 1, "checkout creates pending order")
	_expect(state.objective_index == 1, "checkout advances onboarding")
	var order: Dictionary = state.pending_orders[0]
	_expect(state.collect_delivery(str(order.id)), "paid order can be collected")
	_expect(state.pending_orders.is_empty(), "collection clears pending order")
	_expect(state.item_count("starter:mint") == 1, "collection grants starter")
	_expect(state.objective_index == 2, "collection advances onboarding")
	var starter_count_after_collection := state.item_count("starter:mint")
	_expect(not state.collect_delivery(str(order.id)), "a delivery cannot be collected twice")
	_expect(state.item_count("starter:mint") == starter_count_after_collection, "duplicate delivery attempt grants no stock")
	state.objective_index = 4
	state.register_care_action("water")
	_expect(state.objective_index == 4, "watering alone does not complete the two-part care objective")
	state.register_care_action("feed")
	_expect(state.objective_index == 5, "watering and feeding complete the care objective together")
	_expect(state.add_to_cart("starter:mint"), "a rapid follow-up order enters the cart")
	_expect(state.checkout_cart(), "a rapid follow-up order checks out")
	var follow_up_order: Dictionary = state.pending_orders[0]
	_expect(str(follow_up_order.id) != str(order.id), "rapid consecutive orders receive unique ids")
	state.collect_delivery(str(follow_up_order.id))
	var before_failed_checkout := state.currency
	state.cart = {"starter:alocasia_polly": 100}
	_expect(not state.checkout_cart(), "unaffordable order is rejected")
	_expect(state.currency == before_failed_checkout, "failed checkout preserves leaves")
	state.cart = {"starter:mint": -5}
	_expect(not state.checkout_cart(), "negative cart quantities are rejected")
	_expect(state.currency == before_failed_checkout, "invalid cart cannot create leaves")
	state.cart.clear()
	state.currency = 123
	state.add_item("offshoot:mint", 2)
	state.tutorial_care_actions = {"water": true}
	state.storage_snapshot = [{"slot_id": "storage_00", "item_id": "soil:moist"}]
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
	_expect(loaded.storage_snapshot.size() == 1 and str(loaded.storage_snapshot[0].item_id) == "soil:moist", "storage shelf round-trips")
	_expect(state.save_game(snapshot), "second save creates a recoverable backup")
	var corrupt_file := FileAccess.open(GreenhouseGameState.SAVE_PATH, FileAccess.WRITE)
	corrupt_file.store_string("{not valid json")
	corrupt_file.close()
	var recovered := GreenhouseGameState.new()
	root.add_child(recovered)
	await process_frame
	var recovered_payload := recovered.load_game()
	_expect(not recovered_payload.is_empty() and recovered.currency == 116, "corrupt primary save recovers from the previous valid backup")
	_expect(GreenhouseGameState.has_save_file(), "continue remains available when only backup is valid")
	var malformed_payload := {
		"version": GreenhouseGameState.SAVE_VERSION,
		"currency": -400,
		"inventory": {"starter:mint": 2, "watering_can": -3, "offshoot:mint#invented": 5, "unknown:item": 99},
		"pending_orders": [
			{"id": "", "items": {"starter:mint": 1}, "total": -4},
			{"id": "valid-order", "items": {"starter:mint": 2, "offshoot:mint": 4, "unknown:item": 8}, "total": -99},
		],
		"hotbar": ["unknown:item"],
		"selected_hotbar_index": 99,
		"watering_can_liters": 999.0,
		"objective_index": 999,
		"plants": [{"slot_id": "nursery_00", "species_id": "invented_species", "growth": 999.0}],
		"storage": [{"slot_id": "storage_00", "item_id": "unknown:item"}, {"slot_id": "storage_01", "item_id": "soil:moist"}],
		"total_sales": -8,
		"total_harvests": -3,
		"session_seconds": -90.0,
		"next_order_sequence": 0,
		"tutorial_care_actions": {"water": true, "cheat": true},
	}
	var malformed_file := FileAccess.open(GreenhouseGameState.SAVE_PATH, FileAccess.WRITE)
	malformed_file.store_string(JSON.stringify(malformed_payload))
	malformed_file.close()
	var sanitized := GreenhouseGameState.new()
	root.add_child(sanitized)
	await process_frame
	sanitized.load_game()
	_expect(sanitized.currency == 0, "negative saved currency clamps to zero")
	_expect(sanitized.item_count("starter:mint") == 2 and sanitized.item_count("unknown:item") == 0, "inventory loader keeps only known positive stacks")
	_expect(sanitized.item_count("watering_can") == 1 and sanitized.item_count("trowel") == 1 and sanitized.item_count("secateurs") == 1, "damaged saves recover missing essential tools")
	_expect(sanitized.pending_orders.size() == 1 and str(sanitized.pending_orders[0].id) == "valid-order", "delivery loader rejects malformed and duplicate-prone orders")
	_expect(Dictionary(sanitized.pending_orders[0].items) == {"starter:mint": 2}, "delivery loader only restores purchasable item stacks")
	_expect(int(sanitized.pending_orders[0].total) == int(PlantCatalog.item("starter:mint").price) * 2, "delivery total is recomputed from catalog prices")
	_expect(sanitized.watering_can_liters == sanitized.watering_can_capacity and sanitized.objective_index == GreenhouseGameState.OBJECTIVES.size() - 1, "saved meters and progress clamp to playable bounds")
	_expect(sanitized.storage_snapshot.size() == 1 and str(sanitized.storage_snapshot[0].item_id) == "soil:moist", "storage loader drops unknown items")
	_expect(sanitized.total_sales == 0 and sanitized.total_harvests == 0 and sanitized.session_seconds == 0.0, "negative lifetime counters clamp to zero")
	_expect(sanitized.tutorial_care_actions == {"water": true}, "tutorial loader keeps only recognized actions")
	var damaged_plant := GreenhousePlantActor.new()
	root.add_child(damaged_plant)
	damaged_plant.configure("damaged", sanitized, Dictionary(malformed_payload.plants[0]))
	_expect(damaged_plant.species_id.is_empty() and damaged_plant.growth == 0.0, "unknown saved species safely restores as an empty pot")
	state.queue_free()
	loaded.queue_free()
	recovered.queue_free()
	sanitized.queue_free()
	damaged_plant.queue_free()
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
		_expect(actor.plant_visual != null, "%s visual instantiates in the plant actor" % species_id)
		_expect(actor.growth_parts.size() >= 3, "%s exposes multiple continuous growth parts" % species_id)
		for _minute in range(6):
			actor.moisture = (float(data.optimal_low) + float(data.optimal_high)) * 0.5
			actor.nutrition = 0.82
			actor._process(60.0)
		_expect(actor.growth > growth_before, "%s advances during six minutes of matching care" % species_id)
		_expect(actor.growth >= 0.0 and actor.growth <= 1.0, "%s keeps long-term growth bounded" % species_id)
		_expect(actor.health >= 0.08 and actor.health <= 1.0, "%s keeps long-term health bounded" % species_id)
		_expect(actor.moisture >= -0.08 and actor.moisture <= 1.16, "%s keeps long-term moisture bounded" % species_id)
		var offshoot_item := "offshoot:%s" % species_id
		var inventory_before := state.item_count(offshoot_item)
		var repeated_harvests := 0
		for _step in range(240):
			if actor.moisture < float(data.optimal_low) + 0.12:
				actor.moisture = (float(data.optimal_low) + float(data.optimal_high)) * 0.5
			if actor.nutrition < 0.40:
				actor.nutrition = 0.85
			actor._process(15.0)
			if actor.offshoot_ready and actor.interact(null, "secateurs"):
				repeated_harvests += 1
			if repeated_harvests >= 3:
				break
		_expect(repeated_harvests == 3, "%s supports repeated offshoot harvests during a one-hour care soak" % species_id)
		_expect(state.item_count(offshoot_item) - inventory_before == repeated_harvests, "%s repeated harvests preserve exact inventory accounting" % species_id)
		_expect(actor.health >= 0.68, "%s remains healthy under a sustained matching-care routine" % species_id)
		var saved := actor.snapshot()
		actor.apply_snapshot(saved)
		_expect(actor.species_id == species_id and is_equal_approx(actor.growth, float(saved.growth)), "%s survives a snapshot round-trip" % species_id)
		actor.queue_free()
		await process_frame

	var preferred := PlantCatalog.species("monstera_deliciosa")
	var correct := GreenhousePlantActor.new()
	var wrong := GreenhousePlantActor.new()
	var wrong_feed := GreenhousePlantActor.new()
	root.add_child(correct)
	root.add_child(wrong)
	root.add_child(wrong_feed)
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
	var wrong_feed_baseline := baseline.duplicate(true)
	wrong_feed_baseline.feed_profile = "bloom"
	wrong_feed.configure("feed_wrong", state, wrong_feed_baseline)
	correct._process(45.0)
	wrong._process(45.0)
	wrong_feed._process(45.0)
	_expect(correct.growth > wrong.growth, "matching soil grows faster than a mismatched mix")
	_expect(correct.growth > wrong_feed.growth, "matching feed grows faster than mismatched fertilizer")
	_expect(wrong_feed.growth > float(baseline.growth), "mismatched fertilizer still permits limited growth")
	correct.moisture = 1.16
	var overwatered_health := correct.health
	correct._process(8.0)
	_expect(correct.health < overwatered_health, "sustained overwatering damages health")
	wrong.moisture = 0.0
	var drought_health := wrong.health
	wrong._process(8.0)
	_expect(wrong.health < drought_health, "sustained drought damages health")
	correct.growth = 1.0
	correct.health = 0.90
	correct.moisture = 0.62
	correct.nutrition = 0.0
	correct.offshoot_progress = 0.25
	correct._process(20.0)
	_expect(is_equal_approx(correct.offshoot_progress, 0.25), "mature plant cannot produce an offshoot without nutrition")
	wrong_feed.growth = 1.0
	wrong_feed.health = 0.90
	wrong_feed.moisture = 0.62
	wrong_feed.nutrition = 0.80
	wrong_feed.offshoot_progress = 0.25
	wrong_feed._process(20.0)
	_expect(is_equal_approx(wrong_feed.offshoot_progress, 0.25), "mismatched fertilizer cannot drive offshoot production")
	correct.nutrition = 0.80
	correct._process(20.0)
	_expect(correct.offshoot_progress > 0.25, "mature well-fed plant advances offshoot growth")
	correct.health = 0.20
	correct.moisture = 0.62
	correct.nutrition = 0.80
	correct._process(20.0)
	_expect(correct.health > 0.20, "matching care recovers a stressed plant")
	correct.queue_free()
	wrong.queue_free()
	wrong_feed.queue_free()
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
	_expect(world.storage_slots.size() == 12, "world builds twelve interactive storage slots")
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
	var shelf_slot: GreenhouseStorageSlot = world.storage_slots[0]
	var shelf_item := shelf_slot.stored_item_id
	var combined_stock_before := state.item_count(shelf_item) + 1
	_expect(shelf_slot.get_interaction_prompt("").begins_with("E  Take"), "occupied shelf slot advertises retrieval")
	_expect(shelf_slot.interact(null, ""), "occupied shelf slot releases its item")
	_expect(shelf_slot.stored_item_id.is_empty(), "retrieved shelf slot becomes empty")
	_expect(state.item_count(shelf_item) == combined_stock_before, "retrieval transfers exactly one item into inventory")
	_expect(shelf_slot.interact(null, shelf_item), "empty shelf slot accepts selected inventory item")
	_expect(shelf_slot.stored_item_id == shelf_item, "stored shelf item keeps its identity")
	_expect(state.item_count(shelf_item) + 1 == combined_stock_before, "storage transfer neither duplicates nor loses stock")
	var storage_before := world.storage_snapshots()
	world.reset_storage()
	world.restore_storage_snapshots(storage_before)
	_expect(world.storage_snapshots() == storage_before, "storage layout survives snapshot restore")
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
		_expect(empty_slot.interact(null, "feed:herb"), "matching fertilizer can be applied")
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
		state.add_item("offshoot:mint")
		var propagation_slot: GreenhousePlantActor
		for candidate in world.plant_actors:
			if candidate.species_id.is_empty() and candidate != empty_slot:
				propagation_slot = candidate
				break
		_expect(propagation_slot != null, "world retains a pot for offshoot propagation")
		if propagation_slot:
			state.add_item("soil:moist")
			_expect(propagation_slot.interact(null, "soil:moist"), "propagation pot accepts species soil")
			_expect(propagation_slot.interact(null, "trowel"), "propagation soil can be prepared")
			_expect(propagation_slot.get_interaction_prompt("offshoot:mint").begins_with("E  Plant"), "prepared pot advertises offshoot planting")
			_expect(propagation_slot.interact(null, "offshoot:mint"), "harvested offshoot can be replanted")
			_expect(propagation_slot.species_id == "mint" and propagation_slot.growth >= 0.14, "replanted offshoot starts as an established young plant")
		var leaves_before_sale := state.currency
		_expect(state.sell_offshoot("offshoot:mint"), "harvested offshoot sells")
		_expect(state.currency > leaves_before_sale, "sale awards leaves")
	var clone_slot: GreenhousePlantActor
	for candidate in world.plant_actors:
		if candidate.species_id.is_empty():
			clone_slot = candidate
			break
	if clone_slot:
		state.add_item("soil:aroid")
		state.add_item("offshoot:monstera_deliciosa#variegated")
		clone_slot.interact(null, "soil:aroid")
		clone_slot.interact(null, "trowel")
		_expect(clone_slot.interact(null, "offshoot:monstera_deliciosa#variegated"), "variegated offshoot can be propagated")
		_expect(clone_slot.mutation_id == "variegated", "propagated offshoot inherits its mutation")
	state.add_item("offshoot:monstera_deliciosa#variegated")
	var premium_before := state.currency
	_expect(state.sell_offshoot("offshoot:monstera_deliciosa#variegated"), "variegated offshoot sells")
	_expect(state.currency - premium_before > int(PlantCatalog.species("monstera_deliciosa").offshoot_value), "mutation sale awards a premium")
	var snapshots := world.plant_snapshots()
	var saved_mutations := 0
	for snapshot in snapshots:
		if not str(snapshot.get("mutation_id", "")).is_empty():
			saved_mutations += 1
	_expect(snapshots.size() == world.plant_actors.size(), "world serializes every station")
	world.restore_plant_snapshots(snapshots)
	_expect(world.plant_snapshots().size() == snapshots.size(), "world restores station snapshots")
	var restored_mutations := 0
	for snapshot in world.plant_snapshots():
		if not str(snapshot.get("mutation_id", "")).is_empty():
			restored_mutations += 1
	_expect(restored_mutations == saved_mutations, "mutation metadata survives world snapshot restore")
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


func _model_metrics(root_node: Node) -> Dictionary:
	var metrics := {
		"meshes": 0,
		"surfaces": 0,
		"vertices": 0,
		"normals": 0,
		"indices": 0,
		"materials": 0,
		"invalid_bounds": 0,
		"invalid_vertices": 0,
	}
	_accumulate_model_metrics(root_node, metrics)
	return metrics


func _accumulate_model_metrics(node: Node, metrics: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh:
		metrics.meshes = int(metrics.meshes) + 1
		var bounds: AABB = node.mesh.get_aabb()
		if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.length_squared() <= 0.000001:
			metrics.invalid_bounds = int(metrics.invalid_bounds) + 1
		for surface in range(node.mesh.get_surface_count()):
			metrics.surfaces = int(metrics.surfaces) + 1
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				var vertices := PackedVector3Array(arrays[Mesh.ARRAY_VERTEX])
				metrics.vertices = int(metrics.vertices) + vertices.size()
				for vertex in vertices:
					if not vertex.is_finite():
						metrics.invalid_vertices = int(metrics.invalid_vertices) + 1
			if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				metrics.normals = int(metrics.normals) + PackedVector3Array(arrays[Mesh.ARRAY_NORMAL]).size()
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
				metrics.indices = int(metrics.indices) + PackedInt32Array(arrays[Mesh.ARRAY_INDEX]).size()
			if node.mesh.surface_get_material(surface) != null:
				metrics.materials = int(metrics.materials) + 1
	for child in node.get_children():
		_accumulate_model_metrics(child, metrics)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  PASS: %s" % label)
	else:
		failures.append(label)


func _backup_save() -> void:
	save_existed = FileAccess.file_exists(GreenhouseGameState.SAVE_PATH)
	if save_existed:
		save_backup = FileAccess.get_file_as_bytes(GreenhouseGameState.SAVE_PATH)
	backup_save_existed = FileAccess.file_exists(GreenhouseGameState.SAVE_BACKUP_PATH)
	if backup_save_existed:
		backup_save_backup = FileAccess.get_file_as_bytes(GreenhouseGameState.SAVE_BACKUP_PATH)
	temp_save_existed = FileAccess.file_exists(GreenhouseGameState.SAVE_TEMP_PATH)
	if temp_save_existed:
		temp_save_backup = FileAccess.get_file_as_bytes(GreenhouseGameState.SAVE_TEMP_PATH)


func _restore_save() -> void:
	_restore_save_file(GreenhouseGameState.SAVE_PATH, save_existed, save_backup)
	_restore_save_file(GreenhouseGameState.SAVE_BACKUP_PATH, backup_save_existed, backup_save_backup)
	_restore_save_file(GreenhouseGameState.SAVE_TEMP_PATH, temp_save_existed, temp_save_backup)


func _restore_save_file(path: String, existed: bool, contents: PackedByteArray) -> void:
	if existed:
		var target := FileAccess.open(path, FileAccess.WRITE)
		if target:
			target.store_buffer(contents)
			target.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
