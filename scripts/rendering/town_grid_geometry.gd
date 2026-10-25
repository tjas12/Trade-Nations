class_name TownGridGeometry
extends RefCounted

const HALF_WIDTH := 32.0
const HALF_HEIGHT := 16.0

static func cell_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF_WIDTH, (cell.x + cell.y) * HALF_HEIGHT)

static func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(Vector2((point.x / HALF_WIDTH + point.y / HALF_HEIGHT) * 0.5, (point.y / HALF_HEIGHT - point.x / HALF_WIDTH) * 0.5).floor())

static func footprint_size(width: int, height: int, degrees: float) -> Vector2i:
	return Vector2i(height, width) if quarter(degrees) % 2 == 1 else Vector2i(width, height)

static func footprint_polygon(size: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, cell_to_world(Vector2(size.x, 0)), cell_to_world(Vector2(size)), cell_to_world(Vector2(0, size.y))])

static func quarter(degrees: float) -> int:
	return posmod(roundi(degrees / 90.0), 4)

static func rotate_cell(cell: Vector2i, size: Vector2i, degrees: float) -> Vector2i:
	match quarter(degrees):
		1: return Vector2i(cell.y, size.x - 1 - cell.x)
		2: return Vector2i(size.x - 1 - cell.x, size.y - 1 - cell.y)
		3: return Vector2i(size.y - 1 - cell.y, cell.x)
	return cell

static func cells(instance: BuildingInstance, definition: BuildingDefinition) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size := footprint_size(definition.width, definition.height, instance.rotation_degrees)
	for x in range(size.x):
		for y in range(size.y):
			result.append(Vector2i(instance.x + x, instance.y + y))
	return result

static func entrance_cell(instance: BuildingInstance, definition: BuildingDefinition, ignore_legacy: bool = false) -> Vector2i:
	if not ignore_legacy and instance.legacy_entrance.x >= 0: return instance.legacy_entrance
	var base := Vector2i(definition.width / 2, definition.height)
	return Vector2i(instance.x, instance.y) + rotate_cell(base, Vector2i(definition.width, definition.height), instance.rotation_degrees)

static func perimeter_cells(instance: BuildingInstance, definition: BuildingDefinition) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size := footprint_size(definition.width, definition.height, instance.rotation_degrees)
	for x in range(instance.x - 1, instance.x + size.x + 1):
		for y in range(instance.y - 1, instance.y + size.y + 1):
			if x < instance.x or y < instance.y or x >= instance.x + size.x or y >= instance.y + size.y:
				result.append(Vector2i(x, y))
	return result
