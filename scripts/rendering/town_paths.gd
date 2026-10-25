class_name TownPaths
extends RefCounted

static func blocked_cells(ignore_id: String = "") -> Dictionary:
	var blocked: Dictionary = {}
	if not SaveManager.current_save:
		return blocked
	for instance in SaveManager.current_save.town_layouts["Vanilla"].starting_objects:
		if instance.instance_id == ignore_id:
			continue
		var definition = DataManager.get_building_definition(instance.def_id)
		if not definition:
			continue
		for cell in TownGridGeometry.cells(instance, definition):
			blocked[cell] = true
	return blocked

static func entrance(instance: BuildingInstance, _from: Vector2 = Vector2.ZERO) -> Vector2i:
	return TownGridGeometry.entrance_cell(instance, DataManager.get_building_definition(instance.def_id))

static func route(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	return grid_for(blocked_cells()).get_id_path(start, finish) if _valid_endpoints(start, finish, blocked_cells()) else []

static func _valid_endpoints(start: Vector2i, finish: Vector2i, blocked: Dictionary) -> bool:
	var size: int = SaveManager.current_save.player_state.active_land_size
	var bounds := Rect2i(0, 0, size, size)
	return bounds.has_point(start) and bounds.has_point(finish) and not blocked.has(start) and not blocked.has(finish)

static func grid_for(blocked: Dictionary, land_size: int = -1) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	var size: int = land_size if land_size > 0 else SaveManager.current_save.player_state.active_land_size
	grid.region = Rect2i(0, 0, size, size)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for cell in blocked:
		if grid.region.has_point(cell): grid.set_point_solid(cell)
	return grid

static func layout_reason(candidate: BuildingInstance, ignore_id: String = "") -> String:
	var definition = DataManager.get_building_definition(candidate.def_id)
	var blocked := blocked_cells(ignore_id)
	var size: int = SaveManager.current_save.player_state.active_land_size
	var bounds := Rect2i(0, 0, size, size)
	for cell in TownGridGeometry.cells(candidate, definition):
		if not bounds.has_point(cell): return "Outside town boundary"
		if blocked.has(cell): return "Overlaps a building"
		blocked[cell] = true
	var door := entrance(candidate)
	if not bounds.has_point(door): return "Entrance faces outside the town"
	if blocked.has(door): return "Entrance is blocked"
	var hall: BuildingInstance
	for instance in SaveManager.current_save.town_layouts["Vanilla"].starting_objects:
		var other = DataManager.get_building_definition(instance.def_id)
		if other.type == BuildingDefinition.BuildingType.TOWNHALL:
			hall = instance
			break
	if not hall: return ""
	var start := entrance(hall)
	if not _valid_endpoints(start, door, blocked): return "No access from Town Hall"
	var grid := grid_for(blocked)
	if grid.get_id_path(start, door).is_empty(): return "Entrance cannot be reached"
	# Protect existing working access, without altering old conflicts or structures.
	for instance in SaveManager.current_save.town_layouts["Vanilla"].starting_objects:
		if instance.instance_id == ignore_id: continue
		var other_door := entrance(instance)
		if route(start, other_door).is_empty(): continue
		if not _valid_endpoints(start, other_door, blocked) or grid.get_id_path(start, other_door).is_empty():
			return "Blocks access to " + DataManager.get_building_definition(instance.def_id).display_name
	return ""
