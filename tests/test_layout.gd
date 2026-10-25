extends Node
var failures := 0

func check(value: bool, text: String) -> void:
	print("[LayoutTests] %s: %s" % ["PASS" if value else "FAIL", text])
	if not value: failures += 1

func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	call_deferred("run")

func run() -> void:
	GameManager.start_new_game()
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var definition := BuildingDefinition.new()
	definition.width = 2
	definition.height = 3
	var instance := BuildingInstance.new()
	instance.x = 5
	instance.y = 5
	var expected := [Vector2i(6, 8), Vector2i(8, 5), Vector2i(5, 4), Vector2i(4, 6)]
	for turn in range(4):
		instance.rotation_degrees = turn * 90
		check(TownGridGeometry.cells(instance, definition).size() == 6 and TownGridGeometry.entrance_cell(instance, definition) == expected[turn], "Quarter-turn %d rotates rectangle and entrance together" % turn)
	var rectangle := BuildingInstance.new()
	rectangle.def_id = 151 # Existing 2 by 3 Bench definition, not a special test geometry.
	rectangle.x = 14
	rectangle.y = 10
	check(TownPaths.layout_reason(rectangle).is_empty(), "Rectangular footprint fits near town boundary in default view")
	rectangle.rotation_degrees = 90
	check(TownPaths.layout_reason(rectangle) == "Outside town boundary", "Quarter turn revalidates swapped width near boundary")
	rectangle.x = 6
	rectangle.y = 0
	var neighbour := BuildingInstance.new()
	neighbour.instance_id = "layout_neighbour"
	neighbour.def_id = 10012
	neighbour.x = 8
	neighbour.y = 0
	SaveManager.current_save.town_layouts["Vanilla"].starting_objects.append(neighbour)
	check(TownPaths.layout_reason(rectangle) == "Overlaps a building", "Rotated rectangular footprint checks adjacent building")
	SaveManager.current_save.town_layouts["Vanilla"].starting_objects.erase(neighbour)
	rectangle.x = 10
	rectangle.y = 10
	rectangle.rotation_degrees = 0
	neighbour.x = 10
	neighbour.y = 13
	SaveManager.current_save.town_layouts["Vanilla"].starting_objects.append(neighbour)
	check(TownPaths.layout_reason(rectangle) == "Entrance is blocked", "Clear footprint with blocked directional entrance is rejected")
	SaveManager.current_save.town_layouts["Vanilla"].starting_objects.erase(neighbour)
	var camp = SaveManager.current_save.town_layouts["Vanilla"].starting_objects[1]
	WorkerManager.assign_worker(camp)
	WorkerManager.assign_hauler(camp)
	WorkerManager._update_travel(60)
	camp.cycle_reserved = true
	camp.cycle_elapsed = 3.5
	camp.stored_resources[10] = 7.0
	var gold: float = InventoryManager.amount(1)
	var snapshot: Array = [camp.x, camp.y, camp.rotation_degrees, camp.assigned_worker_ids.duplicate(), camp.assigned_hauler_ids.duplicate(), camp.cycle_elapsed, camp.stored_resources.duplicate()]
	main._start_rotate(camp, 1)
	check(main._ghost_building.building_instance.rotation_degrees == 90 and camp.rotation_degrees == 0, "Existing rotation previews before mutating original")
	main._cancel_placement()
	check(snapshot == [camp.x, camp.y, camp.rotation_degrees, camp.assigned_worker_ids, camp.assigned_hauler_ids, camp.cycle_elapsed, camp.stored_resources] and InventoryManager.amount(1) == gold, "Cancel restores exact original identity, production, staffing and resources")
	main._start_rotate(camp, 1)
	check(main._check_placement_validity(), "Rotated camp has reachable entrance")
	var ghost_scale: Vector2 = main._ghost_building.sprite_2d.scale
	main._place_building()
	for node in main.world_container.get_children():
		if node.get("building_instance") == camp:
			check(node.sprite_2d.scale == ghost_scale, "Confirmed artwork scale matches rotation ghost")
	WorkerManager._update_travel(60)
	check(camp.rotation_degrees == 90 and camp.cycle_elapsed == 3.5 and camp.assigned_worker_ids.size() == 1 and camp.stored_resources[10] == 7, "Confirm rotation preserves production and staff")
	var worker = EconomyManager._find_villager_by_id(camp.assigned_worker_ids[0])
	check(worker.activity == "working" and Vector2i(worker.map_position) == TownPaths.entrance(camp), "Worker reaches rotated entrance")
	main._start_move(camp)
	main._ghost_building.position = Vector2.ZERO
	check(not main._check_placement_validity(), "Edit overlapping Town Hall is rejected")
	main._place_building()
	main._cancel_placement()
	check(camp.x == 4 and camp.y == 0 and camp.rotation_degrees == 90, "Blocked confirm/cancel leaves old building intact")
	check(BuildingVisuals.orientations(DataManager.get_building_definition(35)) == [0], "Bakery signage is not mirrored")
	var edge := BuildingInstance.new()
	edge.instance_id = "legacy_edge_camp"
	edge.def_id = 10008
	edge.x = 14
	edge.y = 14
	SaveManager.current_save.town_layouts["Vanilla"].starting_objects.append(edge)
	SaveManager.current_save.save_version = 2
	SaveManager.save_to_slot(993)
	SaveManager.load_from_slot(993)
	camp = WorkerManager.instance_by_id(camp.instance_id)
	check(SaveManager.current_save.save_version == 4 and camp.rotation_degrees == 90, "Version-2 save migrates and retains supported orientation")
	var gold_before: float = InventoryManager.amount(1)
	var wood_before: float = InventoryManager.amount(10)
	var path := [Vector2i(10, 10), Vector2i(10, 10), Vector2i(11, 10)]
	check(GroundDecorations.apply_stroke("dirt", path) and InventoryManager.amount(1) == gold_before - 2, "Path stroke charges once per unique tile")
	GroundDecorations.apply_stroke("dirt", path)
	check(InventoryManager.amount(1) == gold_before - 2, "Repainting existing paths is free")
	GroundDecorations.apply_stroke("flowers", [Vector2i(12, 10)])
	GroundDecorations.apply_stroke("fence", [Vector2i(13, 10)])
	check(InventoryManager.amount(10) == wood_before - 2 and not TownPaths.blocked_cells().has(Vector2i(13, 10)), "Flowers/fence use configured costs and never block movement")
	GroundDecorations.apply_stroke("erase", [Vector2i(10, 10)])
	check(not SaveManager.current_save.ground_decorations.has(Vector2i(10, 10)) and InventoryManager.amount(1) == gold_before - 4, "Erase removes decorations without refunds")
	var stock: float = InventoryManager.amount(1)
	SaveManager.current_save.inventory.resource_amounts[1] = 0
	check(not GroundDecorations.apply_stroke("dirt", [Vector2i(12, 12)]) and not SaveManager.current_save.ground_decorations.has(Vector2i(12, 12)), "Unaffordable stroke applies nothing")
	SaveManager.current_save.inventory.resource_amounts[1] = stock
	SaveManager.save_to_slot(993)
	SaveManager.load_from_slot(993)
	check(SaveManager.current_save.ground_decorations.get(Vector2i(12, 10)) == "flowers", "Decorations survive save/reload")
	var migrated_edge = WorkerManager.instance_by_id("legacy_edge_camp")
	check(migrated_edge.x == 14 and migrated_edge.y == 14 and migrated_edge.legacy_entrance.x >= 0 and not TownPaths.blocked_cells().has(TownPaths.entrance(migrated_edge)), "Legacy boundary building keeps usable access without relocation")
	SaveManager.delete_slot(993)
	main._refresh_world()
	main._on_building_selected_for_placement(DataManager.get_building_definition(10012))
	main._ghost_building.position = TownGridGeometry.cell_to_world(Vector2(8, 4))
	main._place_building()
	EconomyManager._update_construction(4)
	WorkerManager._update_travel(4)
	GroundDecorations.apply_stroke("dirt", [Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3)])
	GroundDecorations.apply_stroke("flowers", [Vector2i(6, 4)])
	GroundDecorations.apply_stroke("fence", [Vector2i(6, 5)])
	main._center_town()
	main.building_popup.show_for_building(WorkerManager.instance_by_id(camp.instance_id))
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://layout-scale-town.png")
	get_window().size = Vector2i(1536, 864)
	await get_tree().process_frame
	check(main.building_popup.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x and main.building_popup.close_button.get_global_rect().position.x > 1100, "Compact building panel anchors correctly at larger desktop size")
	main.queue_free()
	await get_tree().process_frame
	print("[LayoutTests] %d failures" % failures)
	get_tree().quit(1 if failures else 0)
