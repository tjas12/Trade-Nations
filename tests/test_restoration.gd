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
	var save = SaveManager.current_save
	check(not main.tutorial_popup.objective_label.text.is_empty(), "Tutorial objective is readable")
	check(main.get_node("UILayer/ResourceHud/HBoxContainer/WoodLabel").text == "Wood: 50", "Main scene HUD displays starting Wood")
	main._on_building_selected_for_placement(DataManager.get_building_definition(10012))
	main._ghost_building.position = Vector2(512, 256)
	var building_count: int = save.town_layouts["Vanilla"].starting_objects.size()
	main._place_building()
	check(save.town_layouts["Vanilla"].starting_objects.size() == building_count + 1, "Placement confirms a cottage and records its footprint")
	check(InventoryManager.amount(1) == 0.0 and InventoryManager.amount(10) == 0.0, "Placement deducts cottage costs exactly")
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
	save.town_layouts["Vanilla"].starting_objects.append(stockpile)
	InventoryManager.recalculate_capacity()
	check(InventoryManager.capacity(10) >= 1000.0, "Completed stockpile contributes Wood storage")
	save.inventory.resource_amounts[10] = 50.0
	var before: float = InventoryManager.amount(10)
	EconomyManager._process_producers(360.0)
	EconomyManager._process_haulers(1.0)
	check(InventoryManager.amount(10) > before, "Production and hauling deliver real Wood to inventory")
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
