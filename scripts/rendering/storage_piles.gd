extends Node2D

# Cosmetic contents for recovered stockpile floors; no new simulation or picking.
# One node, redrawn on inventory signals, rather than per-frame item sprites.
func _ready() -> void:
	EventBus.resource_changed.connect(func(_id, _amount): queue_redraw())
	queue_redraw()

func _draw() -> void:
	var materials := [10, 20, 40, 11, 21, 51]
	var tints := [Color("ad793b"), Color("a5a18b"), Color("d9b748"), Color("c39755"), Color("b7b5a2"), Color("918cc1")]
	for index in range(materials.size()):
		if InventoryManager.amount(materials[index]) <= 0: continue
		var origin := Vector2((index % 3 - 1) * 18, (index / 3) * 9 - 10)
		var top := PackedVector2Array([origin + Vector2(0, -8), origin + Vector2(8, -4), origin, origin + Vector2(-8, -4)])
		var left := PackedVector2Array([origin + Vector2(-8, -4), origin, origin + Vector2(0, 6), origin + Vector2(-8, 2)])
		var right := PackedVector2Array([origin, origin + Vector2(8, -4), origin + Vector2(8, 2), origin + Vector2(0, 6)])
		draw_colored_polygon(left, tints[index].darkened(0.25))
		draw_colored_polygon(right, tints[index].darkened(0.1))
		draw_colored_polygon(top, tints[index])
		draw_line(origin + Vector2(-6, -4), origin + Vector2(2, 0), Color("d8bb82"), 1)
