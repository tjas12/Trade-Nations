extends Node

const TownPanels = preload("res://scripts/ui/town_panels.gd")
var failures := 0
var main

func check(value: bool, message: String) -> void:
	print("[PlayableTests] %s: %s" % ["PASS" if value else "FAIL", message])
	if not value:
		failures += 1

func step(seconds: int) -> void:
	for second in range(seconds):
		EconomyManager._update_construction(1)
		WorkerManager._process(1)
		EconomyManager._process_producers(1)
		EconomyManager._process_haulers(1)
		TutorialManager.refresh()

func place(id: int, cell: Vector2i) -> BuildingInstance:
	main._on_building_selected_for_placement(DataManager.get_building_definition(id))
	if not main._ghost_building:
		check(false, "Affordable/unlocked placement %d" % id)
		return null
	main._ghost_building.position = TownGridGeometry.cell_to_world(Vector2(cell))
	main._place_building()
	return SaveManager.current_save.town_layouts["Vanilla"].starting_objects.back()

func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	call_deferred("run")

func run() -> void:
	GameManager.start_new_game()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var save = SaveManager.current_save
	check(save.save_version == 4 and save.player_state.active_land_size == 16, "New town has versioned save and compact expandable plot")
	check(save.villagers.size() == 2 and WorkerManager.housing_capacity() == 2, "Starting pair has Town Hall housing")
	var cottage = place(10012, Vector2i(7, 1))
	check(cottage != null and not cottage.construction_complete and save.villagers.size() == 2, "Housing waits for construction")
	step(4)
	check(save.villagers.size() == 4 and WorkerManager.idle_villagers().size() == 4, "Completed cottage adds real idle villagers")
	check(save.objective_claims.size() == 2, "Housing and arrival objectives reward actual state")
	var camp = save.town_layouts["Vanilla"].starting_objects[1]
	check(WorkerManager.assign_worker(camp) and WorkerManager.assign_hauler(camp), "Logging worker and hauler assigned")
	check(not WorkerManager.assign_worker(camp), "Worker slot limit enforced")
	step(30)
	check(save.economy_stats.produced.get(10, 0) >= 8 and InventoryManager.amount(10) >= 8, "Reliable wood production and hauling")
	var farm = place(11, Vector2i(7, 5))
	step(5)
	check(farm != null and WorkerManager.assign_worker(farm), "Farm uses an available citizen")
	check(DataManager.get_building_definition(11).width == 2, "Farm stays 2 by 2")
	step(35)
	main._collect_resources()
	check(save.economy_stats.produced.get(40, 0) >= 8, "Farm produces Wheat in complete cycles")
	var farmer = EconomyManager._find_villager_by_id(farm.assigned_worker_ids[0])
	farmer.is_hungry = true
	check(EconomyManager.pause_reason(farm).is_empty(), "Hungry farmers can gather food to avoid a food deadlock")
	farmer.is_hungry = false
	for wait_second in range(120):
		if EconomyManager.can_afford(DataManager.get_building_definition(35).cost): break
		step(1)
	var bakery = place(35, Vector2i(10, 5))
	if bakery == null:
		get_tree().quit(1)
		return
	step(6)
	check(bakery != null and WorkerManager.assign_worker(bakery), "Existing Baker Shop has a processing worker")
	check(WorkerManager.idle_villagers().is_empty(), "Four unique citizens occupy four jobs")
	step(15)
	var before_wheat: float = InventoryManager.amount(40)
	var before_cookies: float = InventoryManager.amount(90040)
	# Save with inputs reserved and a partial cycle.
	check(bakery.cycle_reserved and bakery.cycle_elapsed > 0, "Processing reserves inputs once at cycle start")
	var elapsed: float = bakery.cycle_elapsed
	check(SaveManager.save_to_slot(996), "Save mid-cycle")
	SaveManager.load_from_slot(996)
	save = SaveManager.current_save
	bakery = WorkerManager.instance_by_id(bakery.instance_id)
	check(bakery.cycle_reserved and bakery.cycle_elapsed == elapsed and InventoryManager.amount(40) == before_wheat, "Mid-cycle progress and paid inputs survive load")
	WorkerManager._update_travel(60)
	EconomyManager._process_producers(18)
	check(InventoryManager.amount(90040) == before_cookies + 2 and InventoryManager.amount(40) == before_wheat, "Completion gives exactly one output without charging inputs again")
	TutorialManager.refresh()
	check(TownPanels.sell_goods(90040, 2), "Market sells produced Cookies for Gold")
	TutorialManager.refresh()
	check(save.objective_claims.has("market"), "Sale objective rewards actual recorded sales")
	check(not TownPanels.sell_goods(90040, 999) and not InventoryManager.remove(10, -1), "Transactions reject overspending and negative quantities")
	step(90)
	main._collect_resources()
	var wood: int = floori(InventoryManager.amount(10))
	TownPanels.sell_goods(10, maxi(0, wood - 40))
	var old_size: int = save.player_state.active_land_size
	var expansion := TownPanels.expand()
	check(save.player_state.active_land_size == old_size + 8, "Earned economy funds visibly larger buildable plot: " + expansion)
	TutorialManager.refresh()
	check(save.objective_claims.size() == 8, "All eight introductory objectives complete")
	var gold: float = InventoryManager.amount(1)
	check(SaveManager.save_to_slot(996), "Save complete economy")
	for repeat in range(3):
		SaveManager.load_from_slot(996)
		TutorialManager.refresh()
	check(InventoryManager.amount(1) == gold and WorkerManager.total_population() == 4 and SaveManager.current_save.objective_claims.size() == 8, "Repeated loads do not duplicate villagers, rewards, or resources")
	check(SaveManager.current_save.player_state.active_land_size == old_size + 8, "Expansion persists")
	bakery = WorkerManager.instance_by_id(bakery.instance_id)
	var wheat_saved: float = InventoryManager.amount(40)
	var goods_saved: float = InventoryManager.amount(90040)
	bakery.cycle_reserved = false
	bakery.cycle_elapsed = 0
	SaveManager.current_save.inventory.resource_amounts[40] = 0
	WorkerManager._update_travel(60)
	EconomyManager._process_cycle(bakery, DataManager.get_production_recipe(40), 100)
	check(not bakery.cycle_reserved and bakery.cycle_elapsed == 0 and InventoryManager.amount(90040) == goods_saved, "Missing input pauses processing without free outputs")
	SaveManager.current_save.inventory.resource_amounts[40] = wheat_saved
	for id in bakery.assigned_worker_ids.duplicate(): WorkerManager.unassign(id)
	EconomyManager._process_cycle(bakery, DataManager.get_production_recipe(40), 100)
	check(InventoryManager.amount(40) == wheat_saved and InventoryManager.amount(90040) == goods_saved, "Unstaffed production consumes and produces nothing")
	# Migrated version-1 save with a cottage, two citizens, and conflicting job arrays.
	save = SaveManager.current_save
	save.save_version = 1
	save.villagers.resize(2)
	camp = save.town_layouts["Vanilla"].starting_objects[1]
	farm = WorkerManager.instance_by_id(farm.instance_id)
	farm.assigned_worker_ids = camp.assigned_worker_ids.duplicate()
	SaveManager.save_to_slot(995)
	SaveManager.load_from_slot(995)
	save = SaveManager.current_save
	check(save.save_version == 4 and save.villagers.size() == 4, "Legacy save migration repairs housing")
	var jobs: Dictionary = {}
	var unique := true
	for instance in save.town_layouts["Vanilla"].starting_objects:
		for id in instance.assigned_worker_ids + instance.assigned_hauler_ids:
			if jobs.has(id): unique = false
			jobs[id] = true
	check(unique, "Migration removes duplicate jobs without deleting buildings")
	var blocked := TownPaths.blocked_cells()
	var route := TownPaths.route(Vector2i(3, 3), Vector2i(9, 7))
	var clear := not route.is_empty()
	for cell in route:
		clear = clear and not blocked.has(cell)
	check(clear, "Grid paths go around occupied building footprints")
	farm = WorkerManager.instance_by_id(farm.instance_id)
	main._start_move(farm)
	main._ghost_building.position = TownGridGeometry.cell_to_world(Vector2(12, 10))
	main._place_building()
	check(farm.x == 12 and farm.y == 10 and main._occupied_coords.has(Vector2i(12, 10)) and not main._occupied_coords.has(Vector2i(7, 5)), "Moving updates occupancy and preserves the instance")
	WorkerManager.assign_worker(farm)
	main._demolish(farm)
	check(WorkerManager.instance_by_id(farm.instance_id) == null and not main._occupied_coords.has(Vector2i(12, 10)), "Demolition frees occupied cells")
	var orphan := false
	for citizen in save.villagers:
		orphan = orphan or citizen.assigned_building_instance_id == farm.instance_id
	check(not orphan, "Demolition leaves no orphaned assignments")
	main.building_popup.show_for_building(camp)
	await get_tree().process_frame
	check(get_viewport().get_visible_rect().has_point(main.building_popup.close_button.get_global_rect().get_center()), "Building Close stays reachable at desktop minimum size")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://first-playable-panel.png")
	main.building_popup.hide()
	var archive := SaveManager.archive_current_town()
	check(archive >= 2 and FileAccess.file_exists("user://saves/slot_%d.tres" % archive), "New-town archive uses a free numbered slot")
	var old_population := WorkerManager.total_population()
	SaveManager.load_from_slot(archive)
	check(WorkerManager.total_population() == old_population, "Archived town reloads with its citizens")
	SaveManager.delete_slot(archive)
	var broken := SaveGame.new()
	ResourceSaver.save(broken, "user://saves/slot_994.tres")
	check(not SaveManager.save_to_slot(994), "Unreadable sole save is never overwritten")
	SaveManager.delete_slot(994)
	SaveManager.delete_slot(995)
	SaveManager.delete_slot(996)
	main._refresh_world()
	main._center_town()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://first-playable.png")
	main.queue_free()
	await get_tree().process_frame
	print("[PlayableTests] %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
