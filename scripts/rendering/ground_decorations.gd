class_name GroundDecorations
extends Node2D

static var _definitions: Dictionary = {}
var preview: Dictionary = {}
var erase_preview := false
var preview_valid := true

static func definitions() -> Dictionary:
	if _definitions.is_empty():
		_definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/layout_decorations.json"))
	return _definitions

static func effective_cells(kind: String, requested: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size: int = SaveManager.current_save.player_state.active_land_size
	var bounds := Rect2i(0, 0, size, size)
	var blocked := TownPaths.blocked_cells()
	var saved: Dictionary = SaveManager.current_save.ground_decorations
	for cell in requested:
		if not bounds.has_point(cell) or result.has(cell): continue
		if kind == "erase":
			if saved.has(cell): result.append(cell)
		elif not saved.has(cell) and not blocked.has(cell):
			result.append(cell)
	return result

static func stroke_cost(kind: String, cells: Array) -> Dictionary:
	var cost: Dictionary = {}
	if kind == "erase": return cost
	for resource in definitions()[kind].cost:
		cost[int(resource)] = definitions()[kind].cost[resource] * effective_cells(kind, cells).size()
	return cost

static func can_afford(cost: Dictionary) -> bool:
	for resource in cost:
		if InventoryManager.amount(resource) < cost[resource]: return false
	return true

static func apply_stroke(kind: String, requested: Array) -> bool:
	if kind != "erase" and not definitions().has(kind): return false
	var cells := effective_cells(kind, requested)
	var cost := stroke_cost(kind, cells)
	if not can_afford(cost): return false
	for resource in cost: InventoryManager.remove(resource, cost[resource])
	for cell in cells:
		if kind == "erase": SaveManager.current_save.ground_decorations.erase(cell)
		else: SaveManager.current_save.ground_decorations[cell] = kind
	EventBus.ground_decorations_changed.emit()
	return true

func _ready() -> void:
	z_index = -60
	SaveManager.save_activated.connect(rebuild)
	EventBus.ground_decorations_changed.connect(rebuild)
	rebuild()

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not SaveManager.current_save: return
	for cell in SaveManager.current_save.ground_decorations:
		var kind: String = SaveManager.current_save.ground_decorations[cell]
		var asset: String = definitions()[kind].asset
		if asset.is_empty(): continue
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/art/converted/" + asset)
		var bounds := BuildingVisuals.visible_bounds(sprite.texture)
		var scale := 24.0 / bounds.size.y
		sprite.scale = Vector2.ONE * scale
		sprite.position = TownGridGeometry.cell_to_world(Vector2(cell) + Vector2(0.5, 0.5)) - Vector2(0, 6)
		LegacyArt.apply(sprite)
		add_child(sprite)
	queue_redraw()

func _draw() -> void:
	if not SaveManager.current_save: return
	var tile := TownGridGeometry.footprint_polygon(Vector2i.ONE)
	var saved: Dictionary = SaveManager.current_save.ground_decorations
	var neighbours := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for cell in saved:
		if saved[cell] != "dirt": continue
		var points := PackedVector2Array()
		var origin := TownGridGeometry.cell_to_world(Vector2(cell))
		for point in tile: points.append(point + origin)
		draw_colored_polygon(points, Color(0.52, 0.39, 0.23))
		for edge in range(4):
			if saved.get(cell + neighbours[edge]) != "dirt":
				draw_line(points[edge], points[(edge + 1) % 4], Color(0.38, 0.31, 0.18), 2)
	for cell in preview:
		var points := PackedVector2Array()
		for point in tile: points.append(point + TownGridGeometry.cell_to_world(Vector2(cell)))
		draw_colored_polygon(points, Color(0.4, 0.8, 1, 0.55) if erase_preview else (Color(0.5, 1, 0.5, 0.5) if preview_valid else Color(1, 0.3, 0.3, 0.6)))
