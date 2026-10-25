extends Node

func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	call_deferred("run")

func run() -> void:
	GameManager.start_new_game()
	var count := 0
	var missing := 0
	var report: Array[String] = ["id,name,footprint,source,visible_width,visible_height,supported_views"]
	for definition in DataManager.get_all_building_definitions():
		var building = load("res://scenes/building.tscn").instantiate()
		add_child(building)
		var instance := BuildingInstance.new()
		instance.instance_id = "scale_audit"
		instance.def_id = definition.id
		building.set_building(instance)
		if building.sprite_2d.texture:
			var bounds := BuildingVisuals.visible_bounds(building.sprite_2d.texture)
			var visible: Vector2 = bounds.size * building.sprite_2d.scale
			if visible.x > (definition.width + definition.height) * 32 * 0.961 or not is_finite(visible.y):
				push_error("Scale audit failed: " + str(definition.id))
				get_tree().quit(1)
				return
			report.append("%d,%s,%dx%d,%s,%.1f,%.1f,%s" % [definition.id, definition.display_name, definition.width, definition.height, definition.icon_path, visible.x, visible.y, str(BuildingVisuals.orientations(definition)).replace(",", ";")])
		else:
			missing += 1
			report.append("%d,%s,%dx%d,UNMAPPED,0,0,placeholder" % [definition.id, definition.display_name, definition.width, definition.height])
		count += 1
		remove_child(building)
		building.free()
	var padded := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	padded.fill_rect(Rect2i(20, 20, 60, 100), Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(padded)
	var sample = DataManager.get_building_definition(10012)
	var ground := BuildingVisuals.configure(sprite, sample)
	var bounds := BuildingVisuals.visible_bounds(sprite.texture)
	var bottom := sprite.position.y + (bounds.end.y - 80) * sprite.scale.y
	if absf(bottom - ground.y) > 0.01 or absf(bounds.size.x * sprite.scale.x - 74) > 0.01:
		push_error("Transparent padding scale/ground anchor regression")
		get_tree().quit(1)
		return
	sprite.free()
	var file := FileAccess.open("user://building-scale-audit.csv", FileAccess.WRITE)
	file.store_string("\n".join(report))
	file.close()
	print("[ScaleTests] PASS: audited %d definitions; %d missing art retain explicit footprint placeholders" % [count, missing])
	get_tree().quit()
