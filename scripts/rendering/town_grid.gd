extends Node2D

func _draw() -> void:
	var cells := 48
	var extent := float(cells * 64)
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE * extent), Color(0.23, 0.40, 0.22))
	for cell in range(cells + 1):
		var offset := float(cell * 64)
		draw_line(Vector2(offset, 0), Vector2(offset, extent), Color(0.7, 0.8, 0.5, 0.12))
		draw_line(Vector2(0, offset), Vector2(extent, offset), Color(0.7, 0.8, 0.5, 0.12))
