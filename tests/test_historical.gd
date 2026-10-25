extends Node
var failures := 0

func check(value: bool, text: String) -> void:
	print("[HistoricalTests] %s: %s" % ["PASS" if value else "FAIL", text])
	if not value: failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Autosave.set_process(false)
	EconomyManager.set_process(false)
	WorkerManager.set_process(false)
	GameManager.start_new_game()
	var save = SaveManager.current_save
	for resource in [1, 10, 20, 40, 11, 21, 50, 51]: save.inventory.resource_amounts[resource] = 100000
	save.player_state.mayor_level = 4
	ProgressionManager.sync_unlocks()
	var hall: BuildingInstance = save.town_layouts.Vanilla.starting_objects[0]
	var home := BuildingInstance.new()
	home.instance_id = "classic_home"
	home.def_id = 12
	home.x = 8
	home.y = 2
	save.town_layouts.Vanilla.starting_objects.append(home)
	WorkerManager.reconcile_housing()
	check(WorkerManager.total_population() == 3 and WorkerManager.capacity_for(home) == 1, "Classic Small Cottage adds one resident")
	var person = save.villagers.back()
	var person_id: String = person.villager_id
	var camp: BuildingInstance = save.town_layouts.Vanilla.starting_objects[1]
	check(WorkerManager.assign_worker(camp), "Existing producer can receive housing-supported staff")
	var staff: Array = camp.assigned_worker_ids.duplicate()
	var gold: float = InventoryManager.amount(1)
	check(HistoricalGameplay.begin_upgrade(home, 37).begins_with("Requires") and InventoryManager.amount(1) == gold, "Missing civic prerequisite rejects upgrade without charging")
	check(HistoricalGameplay.begin_upgrade(hall, 2).begins_with("Upgrade started"), "Town Hall upgrades in place to verified level-four Tower")
	EconomyManager._update_construction(31)
	check(hall.def_id == 2 and hall.instance_id == "town_hall_01" and WorkerManager.housing_capacity() >= 3, "Civic upgrade retains identity and bootstrap housing")
	check(HistoricalGameplay.begin_upgrade(home, 37).begins_with("Upgrade started"), "Small Cottage starts paid Large Cottage upgrade")
	check(home.def_id == 12 and home.pending_upgrade_id == 37 and WorkerManager.total_population() == 3, "Original housing remains active while upgrade is pending")
	var paid: float = InventoryManager.amount(1)
	HistoricalGameplay.begin_upgrade(home, 37)
	check(InventoryManager.amount(1) == paid, "Repeated upgrade taps cannot double charge")
	EconomyManager._update_construction(31)
	check(home.def_id == 37 and home.x == 8 and home.y == 2 and home.instance_id == "classic_home", "Upgrade preserves placement and stable identity")
	check(WorkerManager.capacity_for(home) == 2 and WorkerManager.total_population() == 4 and camp.assigned_worker_ids == staff, "Large Cottage adds one resident without disturbing jobs")
	check(WorkerManager.instance_by_id("classic_home") == home and save.villagers.any(func(v): return v.villager_id == person_id and v.home_instance_id == "classic_home"), "Original resident and home association are preserved")
	HistoricalGameplay.update_taxes(21600)
	check(home.tax_gold == 8, "Large Cottage historical tax matures at six hours")
	gold = InventoryManager.amount(1)
	var collected := HistoricalGameplay.collect_tax(home)
	check(collected == 8 and InventoryManager.amount(1) == gold + 8 and HistoricalGameplay.collect_tax(home) == 0, "Tax collection is exact and cannot repeat")
	# A legacy starter home retains its extra resident when upgraded.
	var legacy := BuildingInstance.new()
	legacy.instance_id = "legacy_cottage"
	legacy.def_id = 10012
	legacy.x = 10
	legacy.y = 4
	save.town_layouts.Vanilla.starting_objects.append(legacy)
	WorkerManager.reconcile_housing()
	var population := WorkerManager.total_population()
	HistoricalGameplay.begin_upgrade(legacy, 37)
	EconomyManager._update_construction(31)
	check(legacy.def_id == 37 and legacy.housing_bonus == 1 and WorkerManager.total_population() == population + 1, "Legacy starter keeps its extra capacity through a real upgrade")
	# Allowances count houses, not residents, and include existing construction.
	save.player_state.mayor_level = 1
	for index in range(2):
		var extra := BuildingInstance.new()
		extra.instance_id = "limit_%d" % index
		extra.def_id = 12
		save.town_layouts.Vanilla.starting_objects.append(extra)
	check(HistoricalGameplay.build_reason(DataManager.get_building_definition(12)).begins_with("Housing allowance"), "Recovered level-one allowance blocks a fifth home without deleting old ones")
	# Active reservations, elapsed upgrade/tax progress and staff survive serialization.
	save.save_version = 4
	save.player_state.mayor_level = 4
	save.player_state.xp_total = 123.5
	home.tax_gold = 8
	home.tax_xp = 4
	DirAccess.make_dir_recursive_absolute("user://saves")
	ResourceSaver.save(save, "user://saves/slot_974.tres")
	var loaded = SaveManager.load_from_slot(974)
	check(loaded != null and loaded.save_version == 5 and loaded.player_state.mayor_level == 4 and loaded.player_state.xp_total == 123.5, "Version-four migration preserves level and XP")
	home = WorkerManager.instance_by_id("classic_home")
	check(home.tax_gold == 8 and WorkerManager.instance_by_id(camp.instance_id).assigned_worker_ids == staff and WorkerManager.instance_by_id("legacy_cottage").housing_bonus == 1, "Tax claims, jobs and legacy housing survive reload")
	SaveManager.delete_slot(974)
	print("[HistoricalTests] %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
