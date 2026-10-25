extends Node

const MAX_LEVEL := 50
var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
var XP_THRESHOLDS: Dictionary = {0: 1}
signal advanced(levels: Array)

func _ready() -> void:
	for row in registry.levels:
		XP_THRESHOLDS[int(row.level)] = INF if row.level == MAX_LEVEL else int(row.xp_to_next)
	EventBus.building_placed.connect(_on_building_placed)
	SaveManager.save_activated.connect(sync_unlocks)

func sync_unlocks() -> void:
	if not SaveManager.current_save: return
	var state = SaveManager.current_save.player_state
	for id in registry.buildings:
		if int(registry.buildings[id]) <= state.mayor_level and not state.unlocked_buildings.has(int(id)):
			state.unlocked_buildings.append(int(id))

func unlocked(definition: BuildingDefinition) -> bool:
	if not SaveManager.current_save: return false
	var state = SaveManager.current_save.player_state
	return state.unlocked_buildings.has(definition.id) or state.mayor_level >= definition.playable_level

func entries_at(level: int) -> Array:
	var result := []
	for id in registry.buildings:
		if int(registry.buildings[id]) == level:
			result.append(DataManager.get_building_definition(int(id)))
	return result

func add_xp(amount: float) -> void:
	if not SaveManager.current_save or amount <= 0 or not is_finite(amount): return
	var state = SaveManager.current_save.player_state
	state.xp_total += amount
	var gained := []
	while state.mayor_level < MAX_LEVEL and state.xp_total >= XP_THRESHOLDS.get(state.mayor_level, INF):
		state.xp_total -= XP_THRESHOLDS[state.mayor_level]
		state.mayor_level += 1
		sync_unlocks()
		gained.append(state.mayor_level)
		EventBus.level_up.emit(state.mayor_level)
	EventBus.xp_changed.emit(state.xp_total)
	if not gained.is_empty(): advanced.emit(gained)

func _on_building_placed(instance: BuildingInstance) -> void:
	if not instance.construction_complete or instance.construction_xp_awarded: return
	instance.construction_xp_awarded = true
	var definition = DataManager.get_building_definition(instance.def_id)
	if definition and definition.xp_value > 0:
		add_xp(definition.xp_value)
