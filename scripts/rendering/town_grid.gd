extends Node2D

var _cells: int = 48
var grid_visible: bool = false
var placement_grid: bool = false

func set_placement_grid(enabled: bool) -> void:
	placement_grid = enabled
	queue_redraw()

func toggle_grid() -> bool:
	grid_visible = not grid_visible
	queue_redraw()
	return grid_visible

func _process(_delta: float) -> void:
	if SaveManager.current_save:
		var active_size: int = SaveManager.current_save.player_state.active_land_size
		if _cells != active_size:
			_cells = active_size
			queue_redraw()

func _draw() -> void:
	var surround := TownGridGeometry.footprint_polygon(Vector2i(_cells + 20, _cells + 20))
	var offset := TownGridGeometry.cell_to_world(Vector2(-10, -10))
	for index in range(surround.size()):
		surround[index] += offset
	draw_colored_polygon(surround, Color(0.27, 0.43, 0.22))
	var outline := TownGridGeometry.footprint_polygon(Vector2i(_cells, _cells))
	var depth := Vector2(0, 8)
	draw_colored_polygon(PackedVector2Array([outline[1], outline[2], outline[2] + depth, outline[1] + depth]), Color(0.29, 0.34, 0.17))
	draw_colored_polygon(PackedVector2Array([outline[2], outline[3], outline[3] + depth, outline[2] + depth]), Color(0.22, 0.29, 0.14))
	var tile := TownGridGeometry.footprint_polygon(Vector2i.ONE)
	for x in range(_cells):
		for y in range(_cells):
			var origin := TownGridGeometry.cell_to_world(Vector2(x, y))
			var noise: float = posmod((x * 73856093) ^ (y * 19349663), 101) / 100.0
			var meadow: float = 0.5 + (sin(x * 0.37) + cos(y * 0.29) + sin((x + y) * 0.19)) / 6.0
			var shade := Color(0.29 + meadow * 0.025 + noise * 0.004, 0.46 + meadow * 0.045 + noise * 0.008, 0.24 + meadow * 0.025 + noise * 0.004)
			var polygon := PackedVector2Array()
			for corner in tile:
				polygon.append(corner + origin)
			draw_colored_polygon(polygon, shade)
			if posmod(x * 53 + y * 97, 7) == 0:
				var center := origin + Vector2(0, 16)
				draw_line(center + Vector2(-3, 1), center + Vector2(-4, -2), Color(0.38, 0.55, 0.28), 1.0)
				draw_line(center + Vector2(1, 1), center + Vector2(2, -3), Color(0.38, 0.55, 0.28), 1.0)
	if grid_visible or placement_grid:
		for cell in range(_cells + 1):
			draw_line(TownGridGeometry.cell_to_world(Vector2(cell, 0)), TownGridGeometry.cell_to_world(Vector2(cell, _cells)), Color(0.75, 0.86, 0.62, 0.22))
			draw_line(TownGridGeometry.cell_to_world(Vector2(0, cell)), TownGridGeometry.cell_to_world(Vector2(_cells, cell)), Color(0.75, 0.86, 0.62, 0.22))
