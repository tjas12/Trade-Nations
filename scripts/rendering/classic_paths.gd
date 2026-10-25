class_name ClassicPaths
extends RefCounted

# Original mesh artwork. Geometry uses the same 2:1 projection as building feet.
# All path materials connect, including across material boundaries.
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const MATERIALS := ["dirt", "cobblestone", "stone"]

static func mask(cell: Vector2i, cells: Dictionary) -> int:
	var result := 0
	for edge in range(4):
		if cells.get(cell + DIRECTIONS[edge], "") in MATERIALS: result |= 1 << edge
	return result

static func inside(point: Vector2, connections: int) -> bool:
	if point.x >= 0.18 and point.x <= 0.82 and point.y >= 0.18 and point.y <= 0.82: return true
	if point.x >= 0.18 and point.x <= 0.82:
		if point.y < 0.18: return (connections & 1) != 0
		if point.y > 0.82: return (connections & 4) != 0
	if point.y >= 0.18 and point.y <= 0.82:
		if point.x > 0.82: return (connections & 2) != 0
		if point.x < 0.18: return (connections & 8) != 0
	return false

static func mesh(cells: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for cell in cells:
		var kind: String = cells[cell]
		if kind not in MATERIALS: continue
		var connections := mask(cell, cells)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(cell)
		var soil := Color("ac8247") if kind == "dirt" else Color("6d6953")
		var cuts := [0.0, 0.18, 0.82, 1.0]
		for x in range(3):
			for y in range(3):
				var a := Vector2(cuts[x], cuts[y])
				var b := Vector2(cuts[x + 1], cuts[y + 1])
				if inside((a + b) * 0.5, connections): _quad(vertices, colors, indices, cell, a, b, soil)
		if kind == "dirt":
			for patch in range(7):
				var center := Vector2(rng.randf(), rng.randf())
				var radius := rng.randf_range(0.035, 0.085)
				if not inside(center - Vector2.ONE * radius, connections) or not inside(center + Vector2.ONE * radius, connections): continue
				var points := PackedVector2Array()
				for step in range(7):
					var angle := TAU * step / 7
					points.append(center + Vector2(cos(angle), sin(angle)) * radius * rng.randf_range(0.7, 1))
				_polygon(vertices, colors, indices, cell, points, soil.darkened(0.07))
			for speck in range(38):
				var a := Vector2(rng.randf(), rng.randf())
				var size := Vector2(0.015, 0.025) * rng.randf_range(0.6, 2.2)
				if not inside(a - size, connections) or not inside(a + size, connections): continue
				var tint := Color("bfa16a") if speck % 4 == 0 else soil.darkened(rng.randf_range(0.06, 0.17))
				_quad(vertices, colors, indices, cell, a - size, a + size, tint)
		else:
			var count := 6 if kind == "cobblestone" else 3
			for x in range(count):
				for y in range(count):
					var a := Vector2(x, y) / count + Vector2.ONE * 0.014
					var b := Vector2(x + 1, y + 1) / count - Vector2.ONE * 0.014
					# Clip the paving stones to the road silhouette, keeping grass corners.
					if not inside((a + b) * 0.5, connections): continue
					if x == 0 and (connections & 8) == 0: a.x = maxf(a.x, 0.18)
					if y == 0 and (connections & 1) == 0: a.y = maxf(a.y, 0.18)
					if x == count - 1 and (connections & 2) == 0: b.x = minf(b.x, 0.82)
					if y == count - 1 and (connections & 4) == 0: b.y = minf(b.y, 0.82)
					var tint := Color("a69e83") if kind == "cobblestone" else Color("b9b5a1")
					_quad(vertices, colors, indices, cell, a, b, tint.darkened(rng.randf_range(0, 0.18)))
		# Thin grassy fringes are generated only on exposed edges, never at junctions.
		for edge in range(4):
			if (connections & (1 << edge)) != 0: continue
			for blade in range(6):
				var t := 0.2 + blade * 0.1 + rng.randf() * 0.03
				var p := Vector2(t, 0.18) if edge == 0 else Vector2(0.82, t)
				if edge == 2: p = Vector2(t, 0.82)
				if edge == 3: p = Vector2(0.18, t)
				_quad(vertices, colors, indices, cell, p - Vector2(0.012, 0.02), p + Vector2(0.012, 0.02), Color("6f9436"))
				var tip := p + Vector2(0.026, 0.04)
				_polygon(vertices, colors, indices, cell, PackedVector2Array([p - Vector2(0.025, 0), p + Vector2(0.025, 0), tip]), Color("779b3a"))
	var result := ArrayMesh.new()
	if vertices.is_empty(): return result
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func _polygon(vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, cell: Vector2i, points: PackedVector2Array, color: Color) -> void:
	var start := vertices.size()
	for local in points:
		var point := TownGridGeometry.cell_to_world(Vector2(cell) + local)
		vertices.append(Vector3(point.x, point.y, 0))
		colors.append(color)
	for i in range(1, points.size() - 1):
		indices.append_array(PackedInt32Array([start, start + i, start + i + 1]))

static func _quad(vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, cell: Vector2i, a: Vector2, b: Vector2, color: Color) -> void:
	if a.x >= b.x or a.y >= b.y: return
	var start := vertices.size()
	for local in [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]:
		var point := TownGridGeometry.cell_to_world(Vector2(cell) + local)
		vertices.append(Vector3(point.x, point.y, 0))
		colors.append(color)
	for i in [0, 1, 2, 0, 2, 3]: indices.append(start + i)
