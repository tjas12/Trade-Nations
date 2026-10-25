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
		var size := TownGridGeometry.footprint_size(definition.width, definition.height, instance.rotation_degrees)
		for x in range(size.x):
			for y in range(size.y):
				blocked[Vector2i(instance.x + x, instance.y + y)] = true
	return blocked

static func entrance(instance: BuildingInstance, from: Vector2 = Vector2.ZERO) -> Vector2i:
	var definition = DataManager.get_building_definition(instance.def_id)
	var size := TownGridGeometry.footprint_size(definition.width, definition.height, instance.rotation_degrees)
	var blocked := blocked_cells()
	var bounds := Rect2i(0, 0, SaveManager.current_save.player_state.active_land_size, SaveManager.current_save.player_state.active_land_size)
	var best := Vector2i(-1, -1)
	var distance := INF
	for x in range(instance.x - 1, instance.x + size.x + 1):
		for y in range(instance.y - 1, instance.y + size.y + 1):
			var cell := Vector2i(x, y)
			if bounds.has_point(cell) and not blocked.has(cell) and Vector2(cell).distance_squared_to(from) < distance:
				best = cell
				distance = Vector2(cell).distance_squared_to(from)
	return best

static func route(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var grid := AStarGrid2D.new()
	var size: int = SaveManager.current_save.player_state.active_land_size
	grid.region = Rect2i(0, 0, size, size)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for cell in blocked_cells():
		if grid.region.has_point(cell):
			grid.set_point_solid(cell)
	if not grid.region.has_point(start) or not grid.region.has_point(finish) or grid.is_point_solid(start) or grid.is_point_solid(finish):
		return []
	return grid.get_id_path(start, finish)
