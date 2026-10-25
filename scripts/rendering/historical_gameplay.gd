class_name HistoricalGameplay
extends RefCounted

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string("res://data/historical_gameplay.json"))
	return _data

static func profile(id: int) -> Dictionary:
	var original: int = int(data().aliases.get(str(id), id))
	return data().profiles.get(str(original), {})

static func apply_definitions() -> void:
	for key in data().profiles:
		var values: Dictionary = data().profiles[key]
		var definition = DataManager.get_building_definition(int(key))
		definition.cost = CostBundle.new()
		for resource in values.cost:
			var entry := CostEntry.new()
			entry.resource_id = int(resource)
			entry.amount = values.cost[resource]
			definition.cost.entries.append(entry)
		if values.type in ["house", "townhall"]: DataManager.rules.buildings[key] = {"level": values.level, "cost": values.cost, "build_seconds": minf(values.build_seconds, 30)}
		definition.build_time_seconds = minf(values.build_seconds, 30)
		definition.playable_level = int(values.level)
		definition.house_capacity = int(values.residents)
		definition.width = 2 if values.type == "house" else 3
		definition.height = definition.width
		definition.category = "HOUSE" if values.type == "house" else ("TOWN UPGRADES" if values.type == "townhall" else ("WORKSHOPS" if values.type == "shop" else "WORK CAMPS"))
		if values.type == "townhall":
			definition.house_capacity = 2
			definition.storage_capacities = DataManager.get_building_definition(10001).storage_capacities.duplicate()
			definition.sellable = false
	DataManager.get_building_definition(10012).owned_limit = 1
	DataManager.get_building_definition(10012).description_text = "Compatibility starter: two residents. Further Small Cottages use the historical one-resident definition."
	# Supported raw/processed resources are kept distinct under original IDs.
	for resource in [11, 21, 50, 51]: DataManager.get_building_definition(10001).storage_capacities[resource] = 500
	for id in [2, 3, 4]: DataManager.get_building_definition(id).storage_capacities = DataManager.get_building_definition(10001).storage_capacities.duplicate()

static func count_type(type: int) -> int:
	var count := 0
	for item in SaveManager.current_save.town_layouts.Vanilla.starting_objects:
		if DataManager.get_building_definition(item.def_id).type == type: count += 1
	return count

static func limit(category: String) -> int:
	var level: int = clampi(SaveManager.current_save.player_state.mayor_level, 0, 50)
	return int(data().levels[str(level)].limits.get(category, 9999))

static func owns(required: int) -> bool:
	for item in SaveManager.current_save.town_layouts.Vanilla.starting_objects:
		if not item.construction_complete: continue
		var id: int = int(data().aliases.get(str(item.def_id), item.def_id))
		var pending := [id]
		var visited := {}
		while not pending.is_empty():
			var next: int = pending.pop_back()
			if next == required: return true
			if visited.has(next): continue
			visited[next] = true
			for parent in profile(next).get("upgrades_from", []): pending.append(int(parent))
	return false

static func build_reason(definition: BuildingDefinition, upgrading: bool = false) -> String:
	if not ProgressionManager.unlocked(definition): return "Reach level %d first." % definition.playable_level
	var values := profile(definition.id)
	# Starter/legacy aliases keep their previous eligibility.
	if not data().aliases.has(str(definition.id)):
		for requirement in values.get("prerequisites", []):
			if requirement.type == "building" and not owns(int(requirement.value)):
				return "Requires %s (or a later upgrade)." % DataManager.get_building_definition(int(requirement.value)).display_name
	if definition.type == BuildingDefinition.BuildingType.TOWNHALL and not upgrading: return "Upgrade your existing Town Hall from its Overview."
	if not upgrading:
		var same := 0
		for item in SaveManager.current_save.town_layouts.Vanilla.starting_objects:
			if item.def_id == definition.id: same += 1
		if definition.owned_limit >= 0 and same >= definition.owned_limit: return "Owned limit reached; upgrade an existing building."
		if definition.type == BuildingDefinition.BuildingType.HOUSE and count_type(definition.type) >= limit("house"): return "Housing allowance reached (%d). Upgrade a home or gain a level." % limit("house")
		if definition.type == BuildingDefinition.BuildingType.SHOP and count_type(definition.type) >= limit("shop"): return "Shop allowance reached (%d)." % limit("shop")
	return ""

static func upgrade_targets(instance: BuildingInstance) -> Array:
	var result := []
	var source: int = int(data().aliases.get(str(instance.def_id), instance.def_id))
	for key in data().profiles:
		if profile(int(key)).get("upgrades_from", []).has(float(source)): result.append(int(key))
	return result

static func begin_upgrade(instance: BuildingInstance, target_id: int) -> String:
	if not instance or not SaveManager.current_save.town_layouts.Vanilla.starting_objects.has(instance): return "Building no longer exists."
	if not instance.construction_complete or instance.pending_upgrade_id >= 0: return "Finish the current construction first."
	if not upgrade_targets(instance).has(target_id): return "That upgrade is not available for this building."
	var target = DataManager.get_building_definition(target_id)
	var reason := build_reason(target, true)
	if not reason.is_empty(): return reason
	if not EconomyManager.can_afford(target.cost): return "Not enough resources for this upgrade."
	EconomyManager.apply_cost(target.cost)
	instance.pending_upgrade_id = target_id
	instance.upgrade_elapsed = 0
	Autosave.mark_dirty()
	if target.build_time_seconds <= 0: _complete_upgrade(instance)
	return "Upgrade started. Residents and jobs remain in place."

static func _complete_upgrade(instance: BuildingInstance) -> void:
	# Starter houses retain their extra compatibility resident through every tier.
	if instance.def_id == 10012: instance.housing_bonus += 1
	instance.def_id = instance.pending_upgrade_id
	instance.pending_upgrade_id = -1
	instance.upgrade_elapsed = 0
	instance.construction_xp_awarded = false
	WorkerManager.reconcile_housing()
	InventoryManager.recalculate_capacity()
	WorkerManager.invalidate_routes()
	EventBus.building_placed.emit(instance)
	EventBus.town_changed.emit()
	Autosave.mark_dirty()

static func update_upgrades(delta: float) -> void:
	for instance in SaveManager.current_save.town_layouts.Vanilla.starting_objects:
		if instance.pending_upgrade_id < 0: continue
		instance.upgrade_elapsed += maxf(0, delta)
		if instance.upgrade_elapsed >= DataManager.get_building_definition(instance.pending_upgrade_id).build_time_seconds: _complete_upgrade(instance)

static func update_taxes(delta: float) -> void:
	for instance in SaveManager.current_save.town_layouts.Vanilla.starting_objects:
		if not instance.construction_complete or instance.tax_gold > 0: continue
		var tax: Dictionary = profile(instance.def_id).get("tax", {})
		if tax.is_empty(): continue
		instance.tax_elapsed += maxf(0, delta)
		if instance.tax_elapsed >= float(tax.seconds):
			instance.tax_elapsed = float(tax.seconds)
			instance.tax_gold = float(tax.reward.get("1", 0))
			instance.tax_xp = float(tax.xp)
			Autosave.mark_dirty()

static func collect_tax(instance: BuildingInstance) -> float:
	if not SaveManager.current_save.town_layouts.Vanilla.starting_objects.has(instance) or instance.tax_gold <= 0: return 0
	var gold := instance.tax_gold
	var xp := instance.tax_xp
	instance.tax_gold = 0
	instance.tax_xp = 0
	instance.tax_elapsed = 0
	InventoryManager.add(1, gold)
	ProgressionManager.add_xp(xp)
	Autosave.mark_dirty()
	return gold
