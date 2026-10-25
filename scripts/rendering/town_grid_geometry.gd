class_name TownGridGeometry
extends RefCounted

const HALF_WIDTH := 32.0
const HALF_HEIGHT := 16.0

static func cell_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF_WIDTH, (cell.x + cell.y) * HALF_HEIGHT)

static func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(Vector2((point.x / HALF_WIDTH + point.y / HALF_HEIGHT) * 0.5, (point.y / HALF_HEIGHT - point.x / HALF_WIDTH) * 0.5).floor())

static func footprint_size(width: int, height: int, degrees: float) -> Vector2i:
	return Vector2i(height, width) if not is_zero_approx(fmod(degrees, 180.0)) else Vector2i(width, height)

static func footprint_polygon(size: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, cell_to_world(Vector2(size.x, 0)), cell_to_world(Vector2(size)), cell_to_world(Vector2(0, size.y))])
