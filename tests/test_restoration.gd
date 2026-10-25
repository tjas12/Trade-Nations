extends Node

var failures: int = 0

func check(condition: bool, description: String) -> void:
	print("[RestorationTests] %s: %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://restoration-launch.png")
		var probe := Sprite2D.new()
		probe.texture = load("res://assets/art/converted/LITTLECOTTAGE.png")
		probe.centered = false
		probe.position = Vector2(900, 400)
		LegacyArt.apply(probe)
		add_child(probe)
		await RenderingServer.frame_post_draw
		var pixels = FileAccess.get_file_as_bytes("res://original/TradeNations.app/bundle/LITTLECOTTAGE.RAW")
		var reference = Image.create_from_data(pixels.decode_u32(0), pixels.decode_u32(4), false, Image.FORMAT_RGBA8, pixels.slice(9))
		var expected := reference.get_pixel(30, 30)
		var rendered := get_viewport().get_texture().get_image().get_pixel(930, 430)
		check(absf(expected.r - rendered.r) < 0.05 and absf(expected.g - rendered.g) < 0.05 and absf(expected.b - rendered.b) < 0.05, "Rendered cottage matches native RAW orientation and color channels")
		probe.queue_free()
	var save = SaveManager.current_save
	check(not main.tutorial_popup.objective_label.text.is_empty(), "Tutorial objective is readable")
	check(main.get_node("UILayer/ResourceHud/HBoxContainer/WoodLabel").text == "Wood: 50", "Main scene HUD displays starting Wood")
	main._on_building_selected_for_placement(DataManager.get_building_definition(10012))
	main._ghost_building.position = TownGridGeometry.cell_to_world(Vector2(8, 4))
	var building_count: int = save.town_layouts["Vanilla"].starting_objects.size()
	main._place_building()
	check(save.town_layouts["Vanilla"].starting_objects.size() == building_count + 1, "Placement confirms a cottage and records its footprint")
	check(InventoryManager.amount(1) == 30.0 and InventoryManager.amount(10) == 30.0, "Placement deducts cottage costs exactly")
	EconomyManager._update_construction(4)
	TutorialManager.refresh()
	check(save.player_state.mayor_level == 1, "First cottage advances past level zero using original XML threshold")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(500, 350)
	var anchor: Vector2 = main.world_container.to_local(wheel.position)
	main._unhandled_input(wheel)
	check(main.world_container.scale.x > 1.0 and main.world_container.to_global(anchor).distance_to(wheel.position) < 0.01, "Zoom keeps the pointed town location stationary")
	var camp = save.town_layouts["Vanilla"].starting_objects[1]
	var popup = main.get_node("UILayer/BuildingPopup")
	popup.show_for_building(save.town_layouts["Vanilla"].starting_objects[0])
	popup.show_for_building(camp)
	check(popup.name_label.text == "Logging Camp" and popup.assign_worker_button.visible, "Popup refreshes immediately after selecting a non-producer")
	check(WorkerManager.assign_worker(camp), "Assign actual production worker")
	check(WorkerManager.assign_hauler(camp), "Assign actual hauler")
	check(main.world_container.get_child_count() >= 4, "Assignment creates walker nodes without pre-ready label failure")
	var stockpile = BuildingInstance.new()
	stockpile.instance_id = "audit_stockpile"
	stockpile.def_id = 25
	stockpile.x = 6
	stockpile.y = 6
	save.town_layouts["Vanilla"].starting_objects.append(stockpile)
	InventoryManager.recalculate_capacity()
	check(InventoryManager.capacity(10) >= 1000.0, "Completed stockpile contributes Wood storage")
	save.inventory.resource_amounts[10] = 50.0
	var before: float = InventoryManager.amount(10)
	WorkerManager._update_travel(60)
	EconomyManager._process_producers(360.0)
	EconomyManager._process_haulers(1.0)
	check(InventoryManager.amount(10) > before, "Production and hauling deliver real Wood to inventory")
	camp.stored_resources[10] = 5.0
	before = InventoryManager.amount(10)
	main._collect_resources()
	check(is_equal_approx(InventoryManager.amount(10), before + 5.0) and camp.stored_resources[10] == 0.0, "Collect control conserves local and global stock")
	popup._release_staff()
	check(camp.assigned_worker_ids.is_empty() and camp.assigned_hauler_ids.is_empty() and WorkerManager.idle_villagers().size() == 4, "Release staff makes citizens available for another building")
	WorkerManager.assign_worker(camp)
	WorkerManager.assign_hauler(camp)
	var home := BuildingInstance.new()
	home.instance_id = "audit_arrival_home"
	home.def_id = 10012
	save.town_layouts["Vanilla"].starting_objects.append(home)
	WorkerManager._on_housing_placed(home)
	check(WorkerManager.total_population() == 6, "Additional housing creates individual citizens up to capacity")
	check(InventoryManager.capacity(40) >= 500.0, "Prototype town can store Wheat for feeding staff")
	WorkerManager._update_travel(60)
	EconomyManager.simulation_speed = 360.0
	EconomyManager._process(1.0)
	check(InventoryManager.amount(10) > before + 5.0, "Explicit prototype speed advances gathering without changing recipe rate")
	EconomyManager.simulation_speed = 1.0
	var before_trade: float = InventoryManager.amount(10)
	check(SocialManager.sell_to_market(10, 3), "Local market sale succeeds")
	check(is_equal_approx(InventoryManager.amount(10), before_trade - 3.0) and InventoryManager.amount(1) > 0.0, "Market exchanges actual Wood for Gold")
	check(InventoryManager.add(10, -1.0) == 0.0 and not InventoryManager.remove(10, -1.0), "Inventory rejects negative transactions")
	var slot: int = 998
	save.player_state.xp_total = 11.0
	check(SaveManager.save_to_slot(slot), "First save writes and validates")
	save.player_state.xp_total = 22.0
	check(SaveManager.save_to_slot(slot), "Second save preserves previous generation")
	var loaded = SaveManager.load_from_slot(slot)
	check(loaded != null and loaded.player_state.xp_total == 22.0, "Load bypasses cached nested resources")
	var restored_camp = loaded.town_layouts["Vanilla"].starting_objects[1]
	check(restored_camp.assigned_worker_ids.size() == 1 and restored_camp.assigned_hauler_ids.size() == 1, "Assignments round-trip")
	before = InventoryManager.amount(10)
	WorkerManager._update_travel(60)
	EconomyManager._process_producers(360.0)
	EconomyManager._process_haulers(1.0)
	check(InventoryManager.amount(10) > before, "Loaded assignments resume simulation")
	# Valid resource syntax with missing mandatory state simulates structural corruption
	# without intentionally generating parser errors in the clean test log.
	var incomplete = SaveGame.new()
	ResourceSaver.save(incomplete, "user://saves/slot_998.tres")
	loaded = SaveManager.load_from_slot(slot)
	check(loaded != null and loaded.player_state.xp_total == 11.0, "Invalid primary recovers previous backup generation")
	SaveManager.delete_slot(slot)
	check(not FileAccess.file_exists("user://saves/slot_998.backup.tres"), "Deleting test slot removes backup")
	main.queue_free()
	await get_tree().process_frame
	print("[RestorationTests] %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
