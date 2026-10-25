extends Node2D

var _cells: int = 48
var grid_visible: bool = false
var placement_grid: bool = false
var _grass_mesh: ArrayMesh

func _ready() -> void:
	SaveManager.save_activated.connect(_refresh)
	EventBus.town_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	if SaveManager.current_save:
		_cells = SaveManager.current_save.player_state.active_land_size
	_grass_mesh = null
	queue_redraw()

func set_placement_grid(enabled: bool) -> void:
	placement_grid = enabled
	queue_redraw()

func toggle_grid() -> bool:
	grid_visible = not grid_visible
	queue_redraw()
	return grid_visible

func _draw() -> void:
	var surround := TownGridGeometry.footprint_polygon(Vector2i(_cells + 20, _cells + 20))
	var offset := TownGridGeometry.cell_to_world(Vector2(-10, -10))
	for index in range(surround.size()):
		surround[index] += offset
	draw_colored_polygon(surround, Color(0.34, 0.50, 0.16))
	var outline := TownGridGeometry.footprint_polygon(Vector2i(_cells, _cells))
	var depth := Vector2(0, 8)
	draw_colored_polygon(PackedVector2Array([outline[1], outline[2], outline[2] + depth, outline[1] + depth]), Color(0.29, 0.34, 0.17))
	draw_colored_polygon(PackedVector2Array([outline[2], outline[3], outline[3] + depth, outline[2] + depth]), Color(0.22, 0.29, 0.14))
	if _grass_mesh == null: _build_grass()
	draw_mesh(_grass_mesh, null)
	if grid_visible or placement_grid:
		for cell in range(_cells + 1):
			draw_line(TownGridGeometry.cell_to_world(Vector2(cell, 0)), TownGridGeometry.cell_to_world(Vector2(cell, _cells)), Color(0.75, 0.86, 0.62, 0.22))
			draw_line(TownGridGeometry.cell_to_world(Vector2(0, cell)), TownGridGeometry.cell_to_world(Vector2(_cells, cell)), Color(0.75, 0.86, 0.62, 0.22))

func _build_grass() -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var tile := TownGridGeometry.footprint_polygon(Vector2i.ONE)
	for x in range(_cells):
		for y in range(_cells):
			var origin := TownGridGeometry.cell_to_world(Vector2(x, y))
			var noise: float = posmod((x * 73856093) ^ (y * 19349663), 101) / 100.0
			var meadow: float = 0.5 + (sin(x * 0.37) + cos(y * 0.29) + sin((x + y) * 0.19)) / 6.0
			var shade := Color(0.34 + meadow * 0.028 + noise * 0.008, 0.51 + meadow * 0.045 + noise * 0.012, 0.16 + meadow * 0.018 + noise * 0.004)
			var polygon := PackedVector2Array()
			for corner in tile:
				polygon.append(corner + origin)
			_add_quad(vertices, colors, indices, polygon, shade)
			# Tiny meadow flecks share the existing cached surface; no extra draw calls.
			for fleck in range(3):
				var dx: float = posmod(x * 31 + y * 17 + fleck * 19, 21) - 10
				var dy: float = posmod(x * 7 + y * 29 + fleck * 11, 9) - 4
				var center := origin + Vector2(dx, 16 + dy)
				var tint := shade.lightened(0.09) if fleck % 2 == 0 else shade.darkened(0.035)
				_add_quad(vertices, colors, indices, PackedVector2Array([center + Vector2(-1.2, 0), center + Vector2(0, -0.6), center + Vector2(1.2, 0), center + Vector2(0, 0.6)]), tint)
			if posmod(x * 53 + y * 97, 7) == 0:
				var center := origin + Vector2(0, 16)
				_add_blade(vertices, colors, indices, center + Vector2(-3, 1), center + Vector2(-4, -2))
				_add_blade(vertices, colors, indices, center + Vector2(1, 1), center + Vector2(2, -3))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_grass_mesh = ArrayMesh.new()
	_grass_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _add_quad(vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, polygon: PackedVector2Array, color: Color) -> void:
	var base := vertices.size()
	for point in polygon:
		vertices.append(Vector3(point.x, point.y, 0))
		colors.append(color)
	for index in [0, 1, 2, 0, 2, 3]: indices.append(base + index)

func _add_blade(vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, a: Vector2, b: Vector2) -> void:
	var normal := (b - a).orthogonal().normalized() * 0.5
	_add_quad(vertices, colors, indices, PackedVector2Array([a - normal, b - normal, b + normal, a + normal]), Color(0.47, 0.62, 0.24))
