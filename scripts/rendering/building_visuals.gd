class_name BuildingVisuals
extends RefCounted

static var _rules: Dictionary = {}
static var _bounds: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_visuals.json"))
	return _rules

static func visible_bounds(texture: Texture2D) -> Rect2:
	var key := texture.get_instance_id()
	if not _bounds.has(key):
		var image := texture.get_image()
		var raw := image.get_used_rect()
		# RAW conversion has inverted Y; measure the actual visible ground in corrected space.
		_bounds[key] = Rect2(raw.position.x, image.get_height() - raw.end.y, maxi(1, raw.size.x), maxi(1, raw.size.y))
	return _bounds[key]

static func configure(sprite: Sprite2D, definition: BuildingDefinition, degrees: float = 0) -> Vector2:
	var bounds := visible_bounds(sprite.texture)
	sprite.flip_h = supports_mirror(definition) and TownGridGeometry.quarter(degrees) % 2 == 1
	if sprite.flip_h:
		bounds.position.x = sprite.texture.get_width() - bounds.end.x
	var size := TownGridGeometry.footprint_size(definition.width, definition.height, degrees)
	var width: float = (size.x + size.y) * TownGridGeometry.HALF_WIDTH
	var data := rules()
	var override: Dictionary = data.overrides.get(str(definition.id), {})
	var target: float = override.get("visible_width", bounds.size.x * data.native_scale)
	target = minf(target, width * data.footprint_width_limit)
	var scale := target / bounds.size.x
	var ground := TownGridGeometry.cell_to_world(Vector2(size) * 0.5)
	ground.y = (size.x + size.y) * TownGridGeometry.HALF_HEIGHT * data.ground_fraction
	sprite.scale = Vector2.ONE * scale
	# Compensate transparent padding instead of stretching the source canvas.
	sprite.position = ground - Vector2(bounds.get_center().x - sprite.texture.get_width() * 0.5, bounds.end.y - sprite.texture.get_height() * 0.5) * scale
	LegacyArt.apply(sprite)
	return ground

static func supports_mirror(definition: BuildingDefinition) -> bool:
	# Text-bearing shops/market/store signs and civic clock remain readable.
	return definition.type not in [BuildingDefinition.BuildingType.TOWNHALL, BuildingDefinition.BuildingType.SHOP, BuildingDefinition.BuildingType.STORE, BuildingDefinition.BuildingType.MARKET]

static func orientations(definition: BuildingDefinition) -> Array:
	if definition.icon_path.is_empty():
		return [0, 90, 180, 270]
	return [0, 90] if supports_mirror(definition) else [0]

static func facing_label(definition: BuildingDefinition, degrees: float) -> String:
	var normalized := TownGridGeometry.quarter(degrees) * 90
	if not orientations(definition).has(normalized):
		return "Legacy %d° · default art" % normalized
	if definition.icon_path.is_empty():
		return "%d° · placeholder" % normalized
	return "Front-left · mirrored" if normalized == 90 else "Front-right · original"
