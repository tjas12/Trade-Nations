extends Node2D

# Deterministic, decorative scenery. It neither produces resources nor blocks land.
const BORDER := 10
const ART := ["OAK", "BIRCH", "MAPLE", "SPRUCE", "DAISIES", "STUMP"]
var _land_size: int = 0

func _ready() -> void:
	y_sort_enabled = true
	SaveManager.save_activated.connect(rebuild)
	EventBus.town_changed.connect(_refresh)
	call_deferred("_refresh")

func _refresh() -> void:
	if SaveManager.current_save and _land_size != SaveManager.current_save.player_state.active_land_size:
		rebuild()

func rebuild() -> void:
	if not SaveManager.current_save:
		return
	_land_size = SaveManager.current_save.player_state.active_land_size
	for child in get_children():
		remove_child(child)
		child.queue_free()
	# Leave a margin so tree canopies stay beyond the playable plot.
	var clear_plot := Rect2i(-2, -2, _land_size + 4, _land_size + 4)
	for x in range(-BORDER, _land_size + BORDER):
		for y in range(-BORDER, _land_size + BORDER):
			var cell := Vector2i(x, y)
			if clear_plot.has_point(cell):
				continue
			var noise: int = posmod((x * 73856093) ^ (y * 19349663) ^ 20261024, 1000)
			if noise > 230:
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
