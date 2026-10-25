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
	var original_resident = save.villagers.back()
	var person_id: String = original_resident.villager_id
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
	for level in range(1, 50):
		check(ProgressionManager.XP_THRESHOLDS[level] == int(HistoricalGameplay.data().levels[str(level)].xp_to_next), "Recovered XP threshold is used at level %d" % level)
	# Real input reservation, worker rates and hauling for each new material chain.
	SaveManager.current_save.player_state.mayor_level = 50
	ProgressionManager.sync_unlocks()
	for id in camp.assigned_worker_ids.duplicate(): WorkerManager.unassign(id)
	for building_id in [36, 15, 17, 23]:
		var producer := BuildingInstance.new()
		producer.instance_id = "producer_%d" % building_id
		producer.def_id = building_id
		producer.x = 1
		producer.y = 8
		SaveManager.current_save.town_layouts.Vanilla.starting_objects.append(producer)
		check(DataManager.get_building_definition(building_id).shop_recipe_ids.is_empty(), "Unsupported producer batch alternatives are not advertised")
		var recipe = EconomyManager.recipe_for(producer)
		SaveManager.current_save.inventory.resource_amounts[recipe.output_resource_id] = 0
		for input in recipe.input_cost: SaveManager.current_save.inventory.resource_amounts[input] = 10000
		check(WorkerManager.assign_worker(producer) and WorkerManager.assign_hauler(producer), "Staff can be assigned to original producer %d" % building_id)
		for person in SaveManager.current_save.villagers:
			if person.assigned_building_instance_id == producer.instance_id: person.activity = "working"
		var stock := {}
		for input in recipe.input_cost: stock[input] = InventoryManager.amount(input)
		EconomyManager._process_producers(0.01)
		var reserved := true
		for input in stock:
			if InventoryManager.amount(input) != stock[input] - recipe.input_cost[input]: reserved = false
		check(reserved and producer.cycle_reserved, "Input transaction is reserved exactly once for %d" % building_id)
		EconomyManager._process_producers(recipe.cycle_seconds)
		check(producer.stored_resources.get(recipe.output_resource_id, 0) == 1, "Original per-worker cycle produces material for %d" % building_id)
		EconomyManager._process_haulers(1)
		check(InventoryManager.amount(recipe.output_resource_id) == 1, "Hauler delivers material for %d" % building_id)
		for person in SaveManager.current_save.villagers:
			if person.assigned_building_instance_id == producer.instance_id: WorkerManager.unassign(person.villager_id)
		SaveManager.current_save.town_layouts.Vanilla.starting_objects.erase(producer)
	EconomyManager._restore_assignments()
	# Original shop recipes are real paid jobs, not decorative buildings.
	for building_id in [32, 38]:
		var shop := BuildingInstance.new()
		shop.instance_id = "shop_%d" % building_id
		shop.def_id = building_id
		shop.x = 1
		shop.y = 8
		SaveManager.current_save.town_layouts.Vanilla.starting_objects.append(shop)
		var recipe = EconomyManager.recipe_for(shop)
		for input in recipe.input_cost: SaveManager.current_save.inventory.resource_amounts[input] = 10000
		check(WorkerManager.assign_worker(shop), "Shop %d has a functioning worker slot" % building_id)
		for person in SaveManager.current_save.villagers:
			if person.assigned_building_instance_id == shop.instance_id: person.activity = "working"
		EconomyManager._process_producers(0.01)
		var before_gold: float = InventoryManager.amount(1)
		var before_xp: float = SaveManager.current_save.player_state.xp_total
		if building_id == 32:
			check(HistoricalGameplay.choose_recipe(shop, 12).begins_with("Recipe queued"), "Recipe selection queues rather than discarding a paid job")
			check(shop.cycle_reserved and shop.queued_recipe_id == 12 and EconomyManager.recipe_for(shop).id == 10, "Queued selection preserves original reservation and active recipe")
		EconomyManager._process_producers(recipe.cycle_seconds)
		check(InventoryManager.amount(1) == before_gold + recipe.reward.get(1, 0) and SaveManager.current_save.player_state.xp_total == before_xp + recipe.reward_xp, "Shop %d pays its exact original Gold and XP" % building_id)
		if building_id == 32: check(shop.active_recipe_id == 12 and shop.queued_recipe_id == -1, "Queued recipe activates only after original completion")
		for person in SaveManager.current_save.villagers:
			if person.assigned_building_instance_id == shop.instance_id: WorkerManager.unassign(person.villager_id)
		SaveManager.current_save.town_layouts.Vanilla.starting_objects.erase(shop)
	EconomyManager._restore_assignments()
	var warehouse := BuildingInstance.new()
	warehouse.instance_id = "stockpile"
	warehouse.def_id = 25
	SaveManager.current_save.town_layouts.Vanilla.starting_objects.append(warehouse)
	InventoryManager.recalculate_capacity()
	check(InventoryManager.capacity(11) >= 1500, "Original Stockpile raises material storage")
	SaveManager.current_save.inventory.resource_amounts[1] = 10000
	SaveManager.current_save.inventory.resource_amounts[11] = 1000
	# Fixtures include Tower, so a Large Stockpile's historic prerequisite is present.
	check(HistoricalGameplay.begin_upgrade(warehouse, 26).begins_with("Upgrade started"), "Stockpile can upgrade to recovered Large Stockpile")
	EconomyManager._update_construction(31)
	check(warehouse.def_id == 26 and InventoryManager.capacity(11) >= 4000, "Large Stockpile makes later original construction costs attainable")
	# Later verified housing tiers and civic prerequisites are functional too.
	for resource in [1, 10, 20, 40, 11, 21, 50, 51]: SaveManager.current_save.inventory.resource_amounts[resource] = 100000
	hall = WorkerManager.instance_by_id("town_hall_01")
	SaveManager.current_save.player_state.mayor_level = 14
	var population_before := WorkerManager.total_population()
	check(HistoricalGameplay.begin_upgrade(hall, 3).begins_with("Upgrade started"), "Tower can upgrade to the level-six Keep")
	EconomyManager._update_construction(31)
	check(HistoricalGameplay.begin_upgrade(home, 142).begins_with("Upgrade started"), "Large Cottage can upgrade to verified three-resident Brown House")
	EconomyManager._update_construction(31)
	check(home.def_id == 142 and WorkerManager.capacity_for(home) == 3 and WorkerManager.total_population() == population_before + 1, "Brown House adds capacity while preserving residents")
	check(HistoricalGameplay.begin_upgrade(hall, 4).begins_with("Upgrade started"), "Keep upgrades to the level-ten Fort")
	EconomyManager._update_construction(31)
	check(HistoricalGameplay.begin_upgrade(home, 14).begins_with("Upgrade started"), "Brown House upgrades to verified four-resident Stone House")
	EconomyManager._update_construction(31)
	check(home.def_id == 14 and WorkerManager.capacity_for(home) == 4 and WorkerManager.total_population() == population_before + 2, "Stone House completes the implemented residential chain")
	check(home.tax_gold == 8, "Uncollected taxes retain their original reward across housing upgrades")
	# Save a real paid job and an in-progress housing upgrade together.
	legacy = WorkerManager.instance_by_id("legacy_cottage")
	for resource in [1, 10, 20, 40, 11, 21, 50, 51]: SaveManager.current_save.inventory.resource_amounts[resource] = 100000
	HistoricalGameplay.begin_upgrade(legacy, 142)
	EconomyManager._update_construction(5)
	var saved_job := BuildingInstance.new()
	saved_job.instance_id = "saved_carpenter"
	saved_job.def_id = 32
	saved_job.x = 1
	saved_job.y = 8
	SaveManager.current_save.town_layouts.Vanilla.starting_objects.append(saved_job)
	WorkerManager.assign_worker(saved_job)
	for person in SaveManager.current_save.villagers:
		if person.assigned_building_instance_id == saved_job.instance_id: person.activity = "working"
	EconomyManager._process_producers(5)
	HistoricalGameplay.choose_recipe(saved_job, 12)
	var paid_wood: float = InventoryManager.amount(10)
	var paid_gold: float = InventoryManager.amount(1)
	var staff_ids: Array = saved_job.assigned_worker_ids.duplicate()
	check(SaveManager.save_to_slot(974) and SaveManager.load_from_slot(974) != null, "Pending upgrade and paid queued job can be saved and loaded")
	legacy = WorkerManager.instance_by_id("legacy_cottage")
	saved_job = WorkerManager.instance_by_id("saved_carpenter")
	check(legacy.pending_upgrade_id == 142 and legacy.upgrade_elapsed == 5 and legacy.def_id == 37, "Pending upgrade retains original housing, target and elapsed time")
	check(saved_job.cycle_reserved and saved_job.cycle_elapsed == 5 and saved_job.queued_recipe_id == 12 and saved_job.assigned_worker_ids == staff_ids and InventoryManager.amount(10) == paid_wood, "Recipe reservation, queue, timer, staff and paid inventory survive reload")
	Autosave._notification(NOTIFICATION_APPLICATION_PAUSED)
	EconomyManager._process(3600)
	Autosave._notification(NOTIFICATION_APPLICATION_RESUMED)
	EconomyManager._process(3600)
	check(saved_job.cycle_elapsed == 5 and legacy.upgrade_elapsed == 5 and InventoryManager.amount(1) == paid_gold, "Pause/resume cannot advance upgrades/jobs or duplicate rewards")
	home = WorkerManager.instance_by_id("classic_home")
	check(HistoricalGameplay.collect_tax(home) == 8 and HistoricalGameplay.collect_tax(home) == 0, "Persisted tax reward is claimed once after resume")
	# Every newly advertised paid recipe is executable with its recovered values.
	for citizen in SaveManager.current_save.villagers.duplicate(): WorkerManager.unassign(citizen.villager_id)
	SaveManager.current_save.player_state.mayor_level = 50
	for shop_id in [32, 35, 38]:
		for recipe_id in DataManager.get_building_definition(shop_id).shop_recipe_ids:
			if recipe_id == 40: continue # Existing compatibility Cookies covered by Playable/Mobile suites.
			var job := BuildingInstance.new()
			job.instance_id = "recipe_%d" % recipe_id
			job.def_id = shop_id
			job.x = 4
			job.y = 12
			SaveManager.current_save.town_layouts.Vanilla.starting_objects.append(job)
			for resource in [1, 10, 20, 40, 11, 21, 50, 51]: SaveManager.current_save.inventory.resource_amounts[resource] = 100000
			HistoricalGameplay.choose_recipe(job, recipe_id)
			WorkerManager.assign_worker(job)
			for citizen in SaveManager.current_save.villagers:
				if citizen.assigned_building_instance_id == job.instance_id: citizen.activity = "working"
			var recipe = EconomyManager.recipe_for(job)
			var starting_gold: float = InventoryManager.amount(1)
			var starting_xp: float = SaveManager.current_save.player_state.xp_total
			EconomyManager._process_producers(0.01)
			EconomyManager._process_producers(recipe.cycle_seconds)
			var evidence: Dictionary = HistoricalGameplay.data().shop_recipes[str(recipe_id)]
			check(InventoryManager.amount(1) == starting_gold - float(evidence.inputs.get("1", 0)) + float(evidence.rewards.get("1", 0)) and SaveManager.current_save.player_state.xp_total == starting_xp + float(evidence.xp) and HistoricalGameplay.recipe_level(recipe_id) == int(evidence.level), "Advertised original recipe %d completes with exact payout and level" % recipe_id)
			for citizen in SaveManager.current_save.villagers.duplicate():
				if citizen.assigned_building_instance_id == job.instance_id: WorkerManager.unassign(citizen.villager_id)
			SaveManager.current_save.town_layouts.Vanilla.starting_objects.erase(job)
	SaveManager.delete_slot(974)
	print("[HistoricalTests] %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
