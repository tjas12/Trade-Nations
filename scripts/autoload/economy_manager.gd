# scripts/autoload/economy_manager.gd
# Executes production recipes, handles hauling, and resource consumption/granting.
extends Node

# Explicit prototype clock acceleration, never a changed original production rate.
var simulation_speed: float = 1.0

var _active_producers: Dictionary = {} # { instance_id: BuildingInstance }
var _haul_tasks: Dictionary = {} # { instance_id: BuildingInstance }
var _haul_notices: Dictionary = {}

func _ready() -> void:
	SaveManager.save_activated.connect(_restore_assignments)
	EventBus.worker_assigned.connect(_on_worker_assigned)
	EventBus.hauler_assigned.connect(_on_hauler_assigned)

func _restore_assignments() -> void:
	_active_producers.clear()
	_haul_tasks.clear()
	_haul_notices.clear()
	for layout in SaveManager.current_save.town_layouts.values():
		for instance in layout.starting_objects:
			if not instance.assigned_worker_ids.is_empty():
				_start_production(instance)
			if not instance.assigned_hauler_ids.is_empty():
				_haul_tasks[instance.instance_id] = instance

func _process(delta: float) -> void:
	if Autosave.simulation_suspended(): return
	_update_construction(delta * simulation_speed)
	HistoricalGameplay.update_taxes(delta * simulation_speed)
	_process_producers(delta * simulation_speed)
	_process_haulers(delta * simulation_speed)

func _process_producers(delta: float) -> void:
	if _active_producers.is_empty():
		return

	for instance_id in _active_producers.keys():
		var instance = _active_producers[instance_id]
		var building_def = DataManager.get_building_definition(instance.def_id)
		var recipe = recipe_for(instance)
		if recipe == null or not instance.construction_complete:
			continue
		
		if recipe.cycle_seconds > 0:
			_process_cycle(instance, recipe, delta)
			continue
		var output_res_id = recipe.output_resource_id
		var current_stored = instance.stored_resources.get(output_res_id, 0.0)
		
		if current_stored >= recipe.max_output_stack_size:
			_active_producers.erase(instance_id)
			print("[EconomyManager] %s internal storage is full. Pausing production." % building_def.display_name)
			continue
			
		var total_worker_efficiency = 0.0
		for worker_id in instance.assigned_worker_ids:
			var villager = _find_villager_by_id(worker_id)
			if villager:
				if villager.is_hungry:
					total_worker_efficiency += 0.0 # Hungry workers do not produce
				elif villager.is_homeless:
					total_worker_efficiency += 0.5 # Homelessness halves efficiency
				else:
					total_worker_efficiency += 1.0 # Standard efficiency
			else:
				total_worker_efficiency += 1.0

		var total_rate_per_hour = recipe.villager_resources_per_hour * total_worker_efficiency
		var production_this_frame = delta * (total_rate_per_hour / 3600.0)
		var new_stored_amount = min(current_stored + production_this_frame, recipe.max_output_stack_size)
		
		instance.stored_resources[output_res_id] = new_stored_amount
		EventBus.building_storage_changed.emit(instance_id, output_res_id, new_stored_amount)

func _process_haulers(delta: float) -> void:
	if _haul_tasks.is_empty():
		return
	
	for instance_id in _haul_tasks.keys():
		var instance = _haul_tasks[instance_id]
		if not _staff_ready(instance.assigned_hauler_ids):
			continue
		if instance.stored_resources.is_empty():
			continue

		# Instant transfer for Phase 3
		for res_id in instance.stored_resources.keys():
			var amount_to_haul = instance.stored_resources[res_id]
			if amount_to_haul > 0:
				var amount_hauled = InventoryManager.add(res_id, amount_to_haul)
				instance.stored_resources[res_id] -= amount_hauled
				EventBus.building_storage_changed.emit(instance_id, res_id, instance.stored_resources[res_id])
				
				if amount_hauled > 0:
					var notice_key := "%s:%s" % [instance_id, res_id]
					var accumulated: float = _haul_notices.get(notice_key, 0.0) + amount_hauled
					var whole_units := floori(accumulated)
					_haul_notices[notice_key] = accumulated - whole_units
					# Fractional hauling used to create a '+0' Label every frame.
					if whole_units > 0:
						var res_def = DataManager.get_resource_definition(res_id)
						var res_name = res_def.display_name if res_def else "Resource"
						var color = Color.GOLD if res_id == 1 else (Color.YELLOW if res_id == 40 else Color.SPRING_GREEN)
						var world_pos = TownGridGeometry.cell_to_world(Vector2(instance.x, instance.y)) + Vector2(0, -30)
						EventBus.spawn_floating_text.emit("+%d %s" % [whole_units, res_name], world_pos, color)
				
				# If storage was full and is now not, resume production
				var was_paused = not _active_producers.has(instance.instance_id)
				if was_paused and instance.assigned_worker_ids.size() > 0:
					_start_production(instance)


func _on_worker_assigned(villager: Villager, building_instance: BuildingInstance) -> void:
	_start_production(building_instance)

func _on_hauler_assigned(villager: Villager, building_instance: BuildingInstance) -> void:
	if not _haul_tasks.has(building_instance.instance_id):
		_haul_tasks[building_instance.instance_id] = building_instance
		print("[EconomyManager] Hauler assigned to %s. Ready to haul." % building_instance.instance_id)

func _start_production(building_instance: BuildingInstance) -> void:
	var building_def = DataManager.get_building_definition(building_instance.def_id)
	if building_def and building_def.gather_recipe_id != -1:
		if not _active_producers.has(building_instance.instance_id):
			_active_producers[building_instance.instance_id] = building_instance
			if building_instance.recipe_started_at < 0:
				building_instance.recipe_started_at = TimeManager.now()
			print("[EconomyManager] Production started for %s." % building_def.display_name)


func can_afford(cost_bundle: CostBundle) -> bool:
	if not cost_bundle: return true
	for entry in cost_bundle.entries:
		if InventoryManager.amount(entry.resource_id) < entry.amount:
			return false
	return true


func apply_cost(cost_bundle: CostBundle) -> void:
	if not cost_bundle: return
	if not can_afford(cost_bundle):
		push_warning("[EconomyManager] apply_cost called for a cost that cannot be afforded.")
		return
		
	for entry in cost_bundle.entries:
		InventoryManager.remove(entry.resource_id, entry.amount)


func grant_reward(reward) -> void: print("[EconomyManager] Granting reward (TODO)")

func _find_villager_by_id(id: String) -> Villager:
	if not SaveManager.current_save: return null
	for v in SaveManager.current_save.villagers:
		if v.villager_id == id:
			return v
	return null

func _staff_ready(ids: Array, allow_hungry: bool = false) -> bool:
	for id in ids:
		var citizen = _find_villager_by_id(id)
		if citizen and citizen.activity == "working" and (allow_hungry or not citizen.is_hungry):
			return true
	return false

func pause_reason(instance: BuildingInstance) -> String:
	if not instance.construction_complete:
		return "Under construction"
	var definition = DataManager.get_building_definition(instance.def_id)
	var recipe = recipe_for(instance)
	if not recipe:
		return ""
	if instance.assigned_worker_ids.is_empty():
		return "Assign a worker"
	if not _staff_ready(instance.assigned_worker_ids, recipe.output_resource_id == 40):
		return "Staff traveling, blocked, or hungry (need Wheat)"
	var stored: float = instance.stored_resources.get(recipe.output_resource_id, 0.0)
	if stored + recipe.cycle_amount > recipe.max_output_stack_size:
		return "Storage full: collect or assign a hauler"
	if recipe.kind == ProductionRecipe.RecipeKind.CRAFT and InventoryManager.free_space(recipe.output_resource_id) < recipe.cycle_amount:
		return "Town storage full: sell goods"
	if not instance.cycle_reserved:
		for resource in recipe.input_cost:
			if InventoryManager.amount(resource) < recipe.input_cost[resource]:
				return "Needs %s" % DataManager.get_resource_definition(resource).display_name
	return ""

func _process_cycle(instance: BuildingInstance, recipe: ProductionRecipe, delta: float) -> void:
	if not pause_reason(instance).is_empty():
		return
	if not instance.cycle_reserved:
		# Validate every input before making the atomic start transaction.
		for resource in recipe.input_cost:
			if InventoryManager.amount(resource) < recipe.input_cost[resource]:
				return
		for resource in recipe.input_cost:
			InventoryManager.remove(resource, recipe.input_cost[resource])
		instance.cycle_reserved = true
	var workers := 1
	if recipe.per_worker_rate:
		workers = 0
		for id in instance.assigned_worker_ids:
			if _staff_ready([id]): workers += 1
	instance.cycle_elapsed += maxf(0, delta) * workers
	# At most one completed cycle per update. Surplus delta is discarded, never offline catch-up.
	if instance.cycle_elapsed < recipe.cycle_seconds:
		return
	instance.cycle_elapsed = 0
	instance.cycle_reserved = false
	if recipe.direct_reward:
		for resource in recipe.reward: InventoryManager.add(resource, recipe.reward[resource])
	elif recipe.kind == ProductionRecipe.RecipeKind.CRAFT:
		InventoryManager.add(recipe.output_resource_id, recipe.cycle_amount)
	else:
		instance.stored_resources[recipe.output_resource_id] = instance.stored_resources.get(recipe.output_resource_id, 0.0) + recipe.cycle_amount
	EventBus.building_storage_changed.emit(instance.instance_id, recipe.output_resource_id, instance.stored_resources.get(recipe.output_resource_id, 0.0))
	var produced: Dictionary = SaveManager.current_save.economy_stats.produced
	produced[recipe.output_resource_id] = produced.get(recipe.output_resource_id, 0.0) + recipe.cycle_amount
	ProgressionManager.add_xp(recipe.reward_xp)
	EventBus.recipe_completed.emit(instance.instance_id, recipe.id, recipe.cycle_amount)
	if instance.queued_recipe_id >= 0:
		instance.active_recipe_id = instance.queued_recipe_id
		instance.queued_recipe_id = -1
		Autosave.mark_dirty()
	if recipe.kind == ProductionRecipe.RecipeKind.CRAFT:
		EventBus.spawn_floating_text.emit("+%d %s" % [recipe.cycle_amount, DataManager.get_resource_definition(recipe.output_resource_id).display_name], TownGridGeometry.cell_to_world(Vector2(instance.x, instance.y)), Color.GOLD)

func _update_construction(delta: float) -> void:
	if SaveManager.current_save: HistoricalGameplay.update_upgrades(delta)
	if not SaveManager.current_save:
		return
	for instance in SaveManager.current_save.town_layouts["Vanilla"].starting_objects:
		if instance.construction_complete:
			continue
		var definition = DataManager.get_building_definition(instance.def_id)
		instance.construction_elapsed += delta
		if instance.construction_elapsed >= definition.build_time_seconds:
			instance.construction_complete = true
			EventBus.building_placed.emit(instance)
			WorkerManager.invalidate_routes()

func recipe_for(instance: BuildingInstance) -> ProductionRecipe:
	var definition = DataManager.get_building_definition(instance.def_id)
	if definition.shop_recipe_ids.has(instance.active_recipe_id):
		return DataManager.get_production_recipe(instance.active_recipe_id)
	return DataManager.get_production_recipe(definition.gather_recipe_id)
