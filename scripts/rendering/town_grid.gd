extends Node2D

var _cells: int = 48

func _process(_delta: float) -> void:
	if SaveManager.current_save:
		var active_size: int = SaveManager.current_save.player_state.active_land_size
		if _cells != active_size:
			_cells = active_size
			queue_redraw()

func _draw() -> void:
	draw_colored_polygon(TownGridGeometry.footprint_polygon(Vector2i(_cells, _cells)), Color(0.23, 0.40, 0.22))
	for cell in range(_cells + 1):
		draw_line(TownGridGeometry.cell_to_world(Vector2(cell, 0)), TownGridGeometry.cell_to_world(Vector2(cell, _cells)), Color(0.7, 0.8, 0.5, 0.16))
		draw_line(TownGridGeometry.cell_to_world(Vector2(0, cell)), TownGridGeometry.cell_to_world(Vector2(_cells, cell)), Color(0.7, 0.8, 0.5, 0.16))
