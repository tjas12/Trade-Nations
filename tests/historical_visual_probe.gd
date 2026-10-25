extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	get_window().size = Vector2i(960, 440)
	get_window().content_scale_size = Vector2i(960, 440)
	Autosave.set_process(false)
	GameManager.start_new_game()
	var save = SaveManager.current_save
	save.player_state.mayor_level = 16
	ProgressionManager.sync_unlocks()
	for data in [[12, 6, 0], [37, 0, 5], [142, 4, 5], [14, 8, 5], [36, 9, 0], [15, 11, 6], [17, 1, 9], [23, 11, 10], [32, 6, 10], [38, 9, 13], [25, 3, 13]]:
		var building := BuildingInstance.new()
		building.def_id = data[0]
		building.x = data[1]
		building.y = data[2]
		building.instance_id = "showcase_%d" % save.town_layouts.Vanilla.starting_objects.size()
		building.construction_xp_awarded = true
		save.town_layouts.Vanilla.starting_objects.append(building)
	WorkerManager.reconcile_housing()
	for resource in [1, 10, 20, 40, 11, 21, 50, 51]: save.inventory.resource_amounts[resource] = 150
	for x in range(11): save.ground_decorations[Vector2i(x, 3)] = "dirt"
	for y in range(1, 10): save.ground_decorations[Vector2i(7, y)] = "cobblestone"
	for x in range(1, 11): save.ground_decorations[Vector2i(x, 8)] = "stone"
	for y in range(4, 8): save.ground_decorations[Vector2i(3, y)] = "dirt"
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.mobile_ui.force_mobile = true
	main.mobile_ui.refresh()
	main.world_container.scale = Vector2.ONE * 0.82
	main.world_container.position = Vector2(430, 95)
	for frame in range(5): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.validation/historical-town.png")
	var panel = main.get_node("ProgressionPanel")
	main._on_building_instance_selected(save.town_layouts.Vanilla.starting_objects[3])
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.validation/historical-housing.png")
	main.building_popup.hide()
	panel.open_roadmap()
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.validation/historical-roadmap.png")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
