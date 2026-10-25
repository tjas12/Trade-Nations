## SaveManager (autoload)
## Serializes/deserializes SaveGame to disk and handles new game creation.
## See docs/ARCHITECTURE.md §2.3.
extends Node

const SAVE_DIR := "user://saves/"
const SLOT_FILENAME_FORMAT := "slot_%d.tres"

const SaveGame = preload("res://resources/runtime/save_game.gd")
const PlayerState = preload("res://resources/runtime/player_state.gd")
const InventoryState = preload("res://resources/runtime/inventory_state.gd")
const Villager = preload("res://resources/runtime/villager.gd")
const TownLayout = preload("res://resources/runtime/town_layout.gd")
const TutorialProgress = preload("res://resources/runtime/tutorial_progress.gd")

var current_save: SaveGame = null
signal save_activated


## Builds a fresh, fully-populated SaveGame and makes it the current save.
## Does not write to disk — call save_to_slot() after.
func create_new_save() -> SaveGame:
	var save = SaveGame.new()
	save.save_version = 3
	save.created_at_unix = TimeManager.now()
	save.last_saved_at_unix = save.created_at_unix
	
	# Create and populate sub-resources
	save.player_state = PlayerState.new()
	save.player_state.active_land_size = int(DataManager.rules.starting_land_size)
	save.inventory = _create_starting_inventory()
	save.villagers = _create_starting_villagers()
	save.tutorial_progress = TutorialProgress.new()
	
	# Set starting layout
	var default_layout = DataManager.get_starting_layout("default_layout")
	if default_layout:
		save.town_layouts["Vanilla"] = default_layout.duplicate(true)
	else:
		push_error("[SaveManager] Could not load 'default_layout' to create new save.")
		save.town_layouts["Vanilla"] = TownLayout.new()

	current_save = save
	save_activated.emit()
	print("[SaveManager] New game state created with starting resources and villagers.")
	return save


func _create_starting_inventory() -> InventoryState:
	var inventory = InventoryState.new()
	inventory.resource_amounts.clear()
	var all_resources = DataManager.get_all_resource_definitions()
	for res_def in all_resources:
		if res_def.start_value > 0:
			inventory.resource_amounts[res_def.id] = res_def.start_value
	return inventory


func _create_starting_villagers() -> Array[Villager]:
	var villagers: Array[Villager] = []
	
	var v1 = Villager.new()
	v1.villager_id = "villager_1"
	v1.villager_name = "Destiny Shaw" # Name from video analysis
	v1.gender = Villager.Gender.FEMALE
	villagers.append(v1)
	
	var v2 = Villager.new()
	v2.villager_id = "villager_2"
	v2.villager_name = "Adam"
	v2.gender = Villager.Gender.MALE
	villagers.append(v2)
	
	return villagers


func save_to_slot(slot: int) -> bool:
	if browser_storage_blocked():
		push_warning("[BrowserStorage] Persistent browser storage is unavailable; existing saves will not be replaced.")
		return false
	if current_save == null:
		push_error("[SaveManager] save_to_slot called with no current_save.")
		return false

	_ensure_save_dir()
	var path := SAVE_DIR.path_join(SLOT_FILENAME_FORMAT % slot)
	if FileAccess.file_exists(path) and _read_save(path) == null and _read_save(_backup_path(path)) == null:
		push_warning("[SaveManager] Refusing to overwrite an unreadable slot without a recoverable backup.")
		return false
	current_save.last_saved_at_unix = TimeManager.now()
	var pending := path.trim_suffix(".tres") + ".pending.tres"
	var result := ResourceSaver.save(current_save, pending)
	if result != OK:
		push_error("[SaveManager] Failed to save slot %d: error %d" % [slot, result])
		return false
	if _read_save(pending) == null:
		return false
	# Preserve only a valid previous generation; never back up a corrupt primary.
	if _read_save(path) != null:
		if DirAccess.copy_absolute(path, _backup_path(path)) != OK:
			return false
	if DirAccess.rename_absolute(pending, path) != OK:
		return false

	print("[SaveManager] Saved slot %d to %s" % [slot, path])
	return true

func browser_storage_blocked() -> bool:
	return OS.has_feature("web") and not OS.is_userfs_persistent()


func load_from_slot(slot: int) -> SaveGame:
	var path := SAVE_DIR.path_join(SLOT_FILENAME_FORMAT % slot)
	var loaded := _read_save(path)
	if loaded == null:
		loaded = _read_save(_backup_path(path))
		if loaded != null:
			push_warning("[SaveManager] Recovered slot %d from backup." % slot)
	if loaded == null:
		return null

	current_save = loaded
	save_activated.emit()
	print("[SaveManager] Loaded slot %d from %s" % [slot, path])
	return current_save


func _backup_path(path: String) -> String:
	return path.trim_suffix(".tres") + ".backup.tres"


func _read_save(path: String) -> SaveGame:
	if not FileAccess.file_exists(path):
		return null
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if loaded is SaveGame and loaded.player_state != null and loaded.inventory != null and loaded.town_layouts.get("Vanilla") is TownLayout and _migrate(loaded):
		return loaded
	return null


func delete_slot(slot: int) -> bool:
	var path := SAVE_DIR.path_join(SLOT_FILENAME_FORMAT % slot)
	if not FileAccess.file_exists(path):
		return false
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	var result := dir.remove(SLOT_FILENAME_FORMAT % slot) == OK
	if FileAccess.file_exists(_backup_path(path)):
		DirAccess.remove_absolute(_backup_path(path))
	return result


func list_slots() -> Array[int]:
	var slots: Array[int] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return slots

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("slot_") and file_name.ends_with(".tres"):
			var num_str := file_name.trim_prefix("slot_").trim_suffix(".tres")
			if num_str.is_valid_int():
				slots.append(num_str.to_int())
		file_name = dir.get_next()
	dir.list_dir_end()
	return slots


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _migrate(save: SaveGame) -> bool:
	if save.save_version > 3 or save.player_state.active_land_size < 1 or save.player_state.active_land_size > 256:
		return false
	# Version 1 has no cycle reservations/objective claims. Export defaults are safe.
	if not save.economy_stats.has("produced"):
		save.economy_stats["produced"] = {}
	if not save.economy_stats.has("sold"):
		save.economy_stats["sold"] = {}
	for amount in save.inventory.resource_amounts.values():
		if not (amount is float or amount is int) or not is_finite(amount) or amount < 0:
			return false
	if not save.economy_stats.produced is Dictionary or not save.economy_stats.sold is Dictionary:
		return false
	for cell in save.ground_decorations:
		if not cell is Vector2i or not GroundDecorations.definitions().has(save.ground_decorations[cell]):
			return false
	var citizens: Dictionary = {}
	for citizen in save.villagers:
		if not citizen or citizen.villager_id.is_empty() or citizens.has(citizen.villager_id):
			return false
		citizens[citizen.villager_id] = citizen
		citizen.role = Villager.Role.UNASSIGNED
		citizen.assigned_building_instance_id = ""
	var assigned: Dictionary = {}
	var buildings: Dictionary = {}
	for layout in save.town_layouts.values():
		if not layout is TownLayout:
			return false
		for instance in layout.starting_objects:
			if not instance or not is_finite(instance.cycle_elapsed) or instance.cycle_elapsed < 0:
				return false
			if buildings.has(instance.instance_id):
				return false
			buildings[instance.instance_id] = true
			instance.rotation_degrees = TownGridGeometry.quarter(instance.rotation_degrees) * 90
			var definition = DataManager.get_building_definition(instance.def_id)
			if not definition:
				return false
			var recipe = DataManager.get_production_recipe(definition.gather_recipe_id)
			for role in [Villager.Role.WORKER, Villager.Role.HAULER]:
				var ids: Array = instance.assigned_worker_ids if role == Villager.Role.WORKER else instance.assigned_hauler_ids
				var valid: Array = []
				var limit: int = (recipe.worker_max if role == Villager.Role.WORKER else recipe.hauler_max) if recipe else 0
				for id in ids:
					if citizens.has(id) and not assigned.has(id) and valid.size() < limit:
						valid.append(id)
						assigned[id] = true
						citizens[id].role = role
						citizens[id].assigned_building_instance_id = instance.instance_id
				ids.assign(valid)
	if save.save_version < 3:
		_preserve_legacy_access(save)
	# Never move or delete structures: smaller Farm footprint only frees tiles.
	save.save_version = 3
	return true

func archive_current_town() -> int:
	var slot := 2
	while FileAccess.file_exists(SAVE_DIR.path_join(SLOT_FILENAME_FORMAT % slot)) or FileAccess.file_exists(_backup_path(SAVE_DIR.path_join(SLOT_FILENAME_FORMAT % slot))):
		slot += 1
	return slot if save_to_slot(slot) else -1

func _preserve_legacy_access(save: SaveGame) -> void:
	# Earlier versions accepted any free perimeter cell. Retain working access without moving structures.
	var bounds := Rect2i(0, 0, save.player_state.active_land_size, save.player_state.active_land_size)
	for layout in save.town_layouts.values():
		var blocked: Dictionary = {}
		for instance in layout.starting_objects:
			for cell in TownGridGeometry.cells(instance, DataManager.get_building_definition(instance.def_id)):
				blocked[cell] = true
		var grid := TownPaths.grid_for(blocked, save.player_state.active_land_size)
		var root := Vector2i(-1, -1)
		for instance in layout.starting_objects:
			var definition = DataManager.get_building_definition(instance.def_id)
			if definition.type == BuildingDefinition.BuildingType.TOWNHALL:
				var door := TownGridGeometry.entrance_cell(instance, definition, true)
				if bounds.has_point(door) and not blocked.has(door): root = door
				else:
					for cell in TownGridGeometry.perimeter_cells(instance, definition):
						if bounds.has_point(cell) and not blocked.has(cell):
							root = cell
							break
				break
		for instance in layout.starting_objects:
			var definition = DataManager.get_building_definition(instance.def_id)
			var door := TownGridGeometry.entrance_cell(instance, definition, true)
			if bounds.has_point(door) and not blocked.has(door):
				if root.x < 0 or not grid.get_id_path(root, door).is_empty(): continue
			for cell in TownGridGeometry.perimeter_cells(instance, definition):
				if bounds.has_point(cell) and not blocked.has(cell):
					if root.x < 0 or not grid.get_id_path(root, cell).is_empty():
						instance.legacy_entrance = cell
						break
