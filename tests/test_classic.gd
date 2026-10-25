extends Node

var failures := 0
var celebrations := 0

func check(value: bool, text: String) -> void:
	print("[ClassicTests] %s: %s" % ["PASS" if value else "FAIL", text])
	if not value: failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Autosave.set_process(false)
	EconomyManager.set_process(false)
	WorkerManager.set_process(false)
	GameManager.start_new_game()
	ProgressionManager.advanced.connect(func(_levels): celebrations += 1)
	var save = SaveManager.current_save
	check(ProgressionManager.registry.levels.size() == 50, "All fifty levels have data")
	for level in range(1, 51):
		save.player_state.mayor_level = level
		ProgressionManager.sync_unlocks()
		InventoryManager.recalculate_capacity()
		check(InventoryManager.capacity(10) == 500, "Level %d preserves base storage and defines historical allowances" % level)
		for definition in ProgressionManager.entries_at(level):
			check(ProgressionManager.unlocked(definition) and ResourceLoader.exists(definition.icon_path) and DataManager.rules.buildings.has(str(definition.id)), "Functional unlock and asset: " + definition.display_name)
	save.player_state.mayor_level = 0
	save.player_state.xp_total = 0
	save.player_state.unlocked_buildings.clear()
	ProgressionManager.sync_unlocks()
	ProgressionManager.add_xp(-10)
	check(save.player_state.xp_total == 0, "Invalid XP cannot change progress")
	ProgressionManager.add_xp(1301)
	check(save.player_state.mayor_level == 3 and save.player_state.xp_total == 0 and celebrations == 1, "Multi-level gain emits one aggregated celebration")
	ProgressionManager.add_xp(1000000000)
	check(save.player_state.mayor_level == 50 and save.player_state.xp_total > 0, "Cap stops at fifty without discarding excess earned XP")
	var camp: BuildingInstance = save.town_layouts.Vanilla.starting_objects[1]
	var before: float = save.player_state.xp_total
	EventBus.building_placed.emit(camp)
	var after: float = save.player_state.xp_total
	EventBus.building_placed.emit(camp)
	check(after == before + DataManager.get_building_definition(camp.def_id).xp_value and save.player_state.xp_total == after, "Duplicate construction signal cannot repeat XP")
	var gold: float = InventoryManager.amount(1)
	var world = load("res://scenes/Main.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	save.player_state.mayor_level = 0
	save.player_state.unlocked_buildings.clear()
	world.build_menu._on_building_button_pressed(DataManager.get_building_definition(151))
	check(not world._placement_mode_active and InventoryManager.amount(1) == gold, "Locked purchase neither places nor charges")
	# Serialize an old-schema fixture: no UI or progression catch-up occurs on load.
	save.save_version = 3
	save.player_state.mayor_level = 1
	save.player_state.xp_total = 123.5
	camp.cycle_elapsed = 3.5
	camp.rotation_degrees = 90
	save.ground_decorations[Vector2i(10, 10)] = "dirt"
	var bench := BuildingInstance.new()
	bench.def_id = 151
	bench.instance_id = "legacy_bench"
	bench.x = 12
	bench.y = 12
	save.town_layouts.Vanilla.starting_objects.append(bench)
	var notices_before := celebrations
	DirAccess.make_dir_recursive_absolute("user://saves")
	ResourceSaver.save(save, "user://saves/slot_972.tres")
	var loaded = SaveManager.load_from_slot(972)
	check(loaded != null and loaded.save_version == 5 and loaded.player_state.mayor_level == 1 and loaded.player_state.xp_total == 123.5, "Version-three fixture preserves level and XP")
	check(celebrations == notices_before and ProgressionManager.unlocked(DataManager.get_building_definition(151)), "Legacy owned content remains unlocked without backlog notices")
	camp = WorkerManager.instance_by_id(camp.instance_id)
	check(camp.cycle_elapsed == 3.5 and camp.rotation_degrees == 90 and loaded.ground_decorations[Vector2i(10, 10)] == "dirt", "Migration preserves cycles, rotation and old paths")
	var xp: float = loaded.player_state.xp_total
	EventBus.building_placed.emit(camp)
	check(loaded.player_state.xp_total == xp, "Legacy completed construction cannot reclaim XP")
	loaded.inventory.resource_amounts[1] = 1000
	loaded.inventory.resource_amounts[20] = 1000
	for connections in range(16):
		var cells := {Vector2i(6, 6): "dirt"}
		for edge in range(4):
			if (connections & (1 << edge)) != 0: cells[Vector2i(6, 6) + ClassicPaths.DIRECTIONS[edge]] = "cobblestone"
		check(ClassicPaths.mask(Vector2i(6, 6), cells) == connections and ClassicPaths.mesh(cells).get_surface_count() == 1, "Connected mesh mask %d including mixed materials" % connections)
	check(GroundDecorations.apply_stroke("cobblestone", [Vector2i(10, 10)]), "Cobblestone replaces existing dirt")
	var balance: float = InventoryManager.amount(1)
	GroundDecorations.apply_stroke("cobblestone", [Vector2i(10, 10)])
	check(InventoryManager.amount(1) == balance, "Same-material repaint is free")
	check(GroundDecorations.apply_stroke("stone", [Vector2i(10, 10)]) and InventoryManager.amount(1) == balance - 3, "Slabs replace cobbles and charge their configured cost")
	SaveManager.save_to_slot(972)
	SaveManager.load_from_slot(972)
	check(SaveManager.current_save.ground_decorations[Vector2i(10, 10)] == "stone", "New material survives save and reload")
	GroundDecorations.apply_stroke("erase", [Vector2i(10, 10)])
	check(not SaveManager.current_save.ground_decorations.has(Vector2i(10, 10)), "Erase removes new material")
	var quarry := BuildingInstance.new()
	quarry.instance_id = "test_quarry"
	quarry.def_id = 9
	quarry.x = 8
	quarry.y = 6
	SaveManager.current_save.town_layouts.Vanilla.starting_objects.append(quarry)
	var worker = SaveManager.current_save.villagers[0]
	var hauler = SaveManager.current_save.villagers[1]
	quarry.assigned_worker_ids = [worker.villager_id]
	quarry.assigned_hauler_ids = [hauler.villager_id]
	for person in [worker, hauler]: person.activity = "working"
	EconomyManager._restore_assignments()
	EconomyManager._process_producers(0.1)
	EconomyManager._process_producers(15)
	check(SaveManager.current_save.economy_stats.produced.get(20, 0) >= 4, "Quarry workers really produce Rock")
	check(SocialManager.sell_to_market(20, 1), "Rock can be sold through the existing market")
	SaveManager.delete_slot(972)
	world.queue_free()
	await get_tree().process_frame
	print("[ClassicTests] %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
