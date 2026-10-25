## DataManager (autoload)
## Loads and indexes static game-content definitions (ResourceDefinition,
## BuildingDefinition, ProductionRecipe, WorkerDefinition) from res://data/.
## See docs/ARCHITECTURE.md Â§2.2.
##
## Phase 1: the loading pipeline and lookup API exist and are exercised by
## tests/test_foundation.gd; res://data/ subfolders are empty (no gameplay
## content yet) â€” load_all() is expected to succeed against zero files,
## proving the mechanism, not the content. Real content is converted from
## original/TradeNations.app/bundle/ in a later phase (see
## docs/IMPLEMENTATION_ROADMAP.md Phase 1.3, still pending â€” see
## docs/IMPLEMENTATION_STATUS.md).
extends Node

const RESOURCE_DEFINITIONS_PATH := "res://data/resources/"
const BUILDING_DEFINITIONS_PATH := "res://data/buildings/"
const PRODUCTION_RECIPES_PATH := "res://data/recipes/"
const WORKER_DEFINITIONS_PATH := "res://data/workers/"
const LAYOUTS_PATH := "res://data/layouts/"

var resource_definitions: Dictionary = {}   # { id: ResourceDefinition }
var building_definitions: Dictionary = {}   # { id: BuildingDefinition }
var production_recipes: Dictionary = {}     # { id: ProductionRecipe }
var worker_definitions: Dictionary = {}     # { id: WorkerDefinition }
var starting_layouts: Dictionary = {}       # { name: TownLayout }

var rules: Dictionary = {}

var _is_loaded: bool = false


## Loads every static content table. Safe to call more than once (e.g. from
## a test or a future "reload content" debug action) â€” it simply re-scans
## and rebuilds each index.
func load_all() -> void:
	resource_definitions = _load_definitions(RESOURCE_DEFINITIONS_PATH, "id")
	building_definitions = _load_definitions(BUILDING_DEFINITIONS_PATH, "id")
	production_recipes = _load_definitions(PRODUCTION_RECIPES_PATH, "id")
	worker_definitions = _load_definitions(WORKER_DEFINITIONS_PATH, "id")
	starting_layouts = _load_definitions(LAYOUTS_PATH, "filename") # Indexed by filename
	
	_apply_playable_rules()
	for definition in building_definitions.values():
		if definition.icon_path.is_empty():
			var asset: String = BuildingVisuals.rules().asset_overrides.get(str(definition.id), "")
			if not asset.is_empty():
				definition.icon_path = "res://assets/art/converted/" + asset
	_is_loaded = true
	print("[DataManager] Loaded %d resource defs, %d building defs, %d recipes, %d worker defs, %d layouts." % [
		resource_definitions.size(),
		building_definitions.size(),
		production_recipes.size(),
		worker_definitions.size(),
		starting_layouts.size(),
	])


func is_loaded() -> bool:
	return _is_loaded


func get_resource_definition(id: int) -> ResourceDefinition:
	return resource_definitions.get(id, null)


func get_all_resource_definitions() -> Array:
	return resource_definitions.values()


func get_building_definition(id: int) -> BuildingDefinition:
	return building_definitions.get(id, null)


func get_production_recipe(id: int) -> ProductionRecipe:
	return production_recipes.get(id, null)


func get_all_production_recipes() -> Array:
	return production_recipes.values()


func get_worker_definition(id: String) -> WorkerDefinition:
	return worker_definitions.get(id, null)


func get_all_building_definitions() -> Array:
	return building_definitions.values()


func get_starting_layout(layout_name: String) -> TownLayout:
	var key = layout_name.to_lower()
	if starting_layouts.has(key):
		return starting_layouts[key]
	
	if starting_layouts.has(key + ".tres"): # try with extension
		return starting_layouts[key + ".tres"]

	push_warning("[DataManager] Could not find starting layout: " + layout_name)
	return null


## Generic loader: scans [param folder_path] for .tres Resource files and
## indexes them by their [param id_field] property. A missing folder or an
## empty folder is not an error â€” Phase 1 ships with no content yet.
func _load_definitions(folder_path: String, id_field: String) -> Dictionary:
	var index: Dictionary = {}
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return index

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres.remap"):
			file_name = file_name.trim_suffix(".remap")
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := folder_path.path_join(file_name)
			var res: Resource = ResourceLoader.load(full_path)
			if res != null:
				if id_field == "filename":
					var key = file_name.get_basename().to_lower()
					index[key] = res
				elif id_field in res:
					index[res.get(id_field)] = res
				else:
					push_warning("[DataManager] Skipped '%s' â€” missing '%s' field." % [full_path, id_field])
			else:
				push_warning("[DataManager] Skipped '%s' â€” failed to load." % full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	return index

# Explicit offline balance overrides over the recovered content, not duplicate managers.
func _apply_playable_rules() -> void:
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/first_playable.json"))
	for key in rules.buildings:
		var definition = building_definitions[int(key)]
		var values = rules.buildings[key]
		definition.cost = CostBundle.new()
		for resource in values.cost:
			var entry := CostEntry.new()
			entry.resource_id = int(resource)
			entry.amount = values.cost[resource]
			definition.cost.entries.append(entry)
		definition.playable_level = int(values.level)
		definition.build_time_seconds = values.build_seconds
	for key in rules.recipes:
		var recipe = production_recipes[int(key)]
		var values = rules.recipes[key]
		recipe.cycle_seconds = values.seconds
		recipe.cycle_amount = values.amount
		recipe.input_cost.clear()
		for resource in values.inputs:
			recipe.input_cost[int(resource)] = values.inputs[resource]
		recipe.worker_max = int(values.workers)
		recipe.hauler_max = int(values.haulers)
		recipe.reward_xp = values.xp
	# Only implemented entries join the playable catalog. Recovered definitions retain IDs.
	var progression = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	for definition in building_definitions.values():
		definition.playable_level = int(progression.buildings.get(str(definition.id), 50))
	for key in progression.buildings:
		var definition = building_definitions[int(key)]
		if definition.category.is_empty(): definition.category = "DECORATION"
	building_definitions[9].category = "WORK CAMPS"
	building_definitions[9].width = 3
	building_definitions[9].height = 3
	building_definitions[9].upgrade_only = false
	building_definitions[9].description_text = "Offline quarry: workers gather Rock on any clear site; a hauler delivers it."
	building_definitions[9].info_text = building_definitions[9].description_text
	building_definitions[10001].storage_capacities[20] = 200
	var cookies = production_recipes[40]
	cookies.output_resource_id = 90040
	cookies.max_output_stack_size = 100
	# Connect the existing Baker Shop and existing Cookies recipe.
	building_definitions[10008].gather_recipe_id = 50008
	building_definitions[35].icon_path = "res://assets/art/converted/BAKERSSHOP.png"
	building_definitions[35].gather_recipe_id = 40
	building_definitions[35].width = 2
	building_definitions[35].height = 2
	building_definitions[10001].storage_capacities[90040] = 200
	HistoricalGameplay.apply_definitions()

