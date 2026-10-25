extends Node2D

# Deterministic, decorative scenery. It neither produces resources nor blocks land.
const ART := ["OAK", "BIRCH", "MAPLE", "SPRUCE", "DAISIES", "STUMP"]
var _land_size: int = 0

func _ready() -> void:
	y_sort_enabled = true
	SaveManager.save_activated.connect(rebuild)
	EventBus.building_placed.connect(func(_instance): rebuild())
	call_deferred("_refresh")

func _refresh() -> void:
	if SaveManager.current_save and _land_size != SaveManager.current_save.player_state.active_land_size:
		rebuild()

func _process(_delta: float) -> void:
	_refresh()

func rebuild() -> void:
	if not SaveManager.current_save:
		return
	_land_size = SaveManager.current_save.player_state.active_land_size
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var exclusion: Array[Rect2i] = []
	for instance in SaveManager.current_save.town_layouts["Vanilla"].starting_objects:
		var definition = DataManager.get_building_definition(instance.def_id)
		if definition:
			var size := TownGridGeometry.footprint_size(definition.width, definition.height, instance.rotation_degrees)
			exclusion.append(Rect2i(Vector2i(instance.x - 1, instance.y - 1), size + Vector2i(2, 2)))
	for x in range(1, _land_size - 1):
		for y in range(1, _land_size - 1):
			var noise: int = posmod((x * 73856093) ^ (y * 19349663) ^ 20261024, 1000)
			var edge := x < 5 or y < 5 or x > _land_size - 6 or y > _land_size - 6
			if noise > (150 if edge else 55):
				continue
			var cell := Vector2i(x, y)
			var covered := false
			for rect in exclusion:
				if rect.has_point(cell):
					covered = true
					break
			if covered:
				continue
			var marker := Node2D.new()
			marker.name = "Scenery_%d_%d" % [x, y]
			marker.set_meta("cell", cell)
			marker.position = TownGridGeometry.cell_to_world(Vector2(cell) + Vector2(0.5, 0.5))
			add_child(marker)
			var shadow := Polygon2D.new()
			var shadow_points := PackedVector2Array()
			for step in range(12):
				var angle: float = TAU * step / 12.0
				shadow_points.append(Vector2(cos(angle) * 13, sin(angle) * 5))
			shadow.polygon = shadow_points
			shadow.color = Color(0.12, 0.23, 0.10, 0.25)
			marker.add_child(shadow)
			var sprite := Sprite2D.new()
			sprite.texture = load("res://assets/art/converted/%s.png" % ART[posmod(x * 3 + y * 11, ART.size())])
			var target_height: float = 22.0 if posmod(x * 3 + y * 11, ART.size()) >= 4 else 52.0 + noise * 0.16
			sprite.scale = Vector2.ONE * (target_height / sprite.texture.get_height())
			sprite.position.y = -target_height * 0.5
			LegacyArt.apply(sprite)
			marker.add_child(sprite)
