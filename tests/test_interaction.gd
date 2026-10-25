extends Node

var failures := 0

func check(condition: bool, description: String) -> void:
	print("[InteractionTests] %s: %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures += 1

func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	call_deferred("run")

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	for down in [true, false]:
		var button := InputEventMouseButton.new()
		button.position = point
		button.global_position = point
		button.button_index = MOUSE_BUTTON_LEFT
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		button.pressed = down
		get_viewport().push_input(button, true)
		await get_tree().process_frame

func drag_mouse(start: Vector2, finish: Vector2, mouse_button: int = MOUSE_BUTTON_LEFT) -> void:
	var down := InputEventMouseButton.new()
	down.position = start
	down.global_position = start
	down.button_index = mouse_button
	down.button_mask = MOUSE_BUTTON_MASK_LEFT if mouse_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE
	down.pressed = true
	get_viewport().push_input(down, true)
	await get_tree().process_frame
	var move := InputEventMouseMotion.new()
	move.position = finish
	move.global_position = finish
	move.relative = finish - start
	move.button_mask = down.button_mask
	get_viewport().push_input(move, true)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.position = finish
	up.global_position = finish
	up.button_index = mouse_button
	up.pressed = false
	get_viewport().push_input(up, true)
	await get_tree().process_frame

func run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await click(main.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(1.5, 1.5))))
	check(main.building_popup.visible and main.building_popup.name_label.text == "Town Hall", "Mouse click opens Town Hall")
	await click(main.building_popup.close_button.get_global_rect().get_center())
	check(not main.building_popup.visible, "Close button consumes its click without reopening a building")
	await click(main.tutorial_popup.continue_button.get_global_rect().get_center())
	check(not main.tutorial_popup.visible, "Got it button dismisses tutorial")
	var camera_before: Vector2 = main.world_container.position
	await drag_mouse(Vector2(170, 450), Vector2(250, 490))
	check(main.world_container.position.distance_to(camera_before + Vector2(80, 40)) < 0.05, "Left-drag on empty ground pans the map")
	check(not main._panning and main._pan_button == 0 and not main.building_popup.visible, "Ground drag release stops panning without selecting a building")
	camera_before = main.world_container.position
	await drag_mouse(Vector2(170, 450), Vector2(130, 430), MOUSE_BUTTON_MIDDLE)
	check(main.world_container.position.distance_to(camera_before + Vector2(-40, -20)) < 0.05, "Middle-drag remains supported")
	await drag_mouse(Vector2(170, 470), Vector2(270, 80))
	camera_before = main.world_container.position
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(310, 110)
	motion.relative = Vector2(40, 30)
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	check(not main._panning and main.world_container.position.distance_to(camera_before) < 0.05, "Releasing over toolbar cannot leave the camera dragging")
	await click(main.get_node("UILayer/TownActions/CenterTown").get_global_rect().get_center())
	var town_point: Vector2 = main.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(1.5, 1.5)))
	check(main.world_container.scale == Vector2.ONE and get_viewport().get_visible_rect().has_point(town_point), "Center town button recovers the buildings and resets zoom")
	camera_before = main.world_container.position
	var right := InputEventKey.new()
	right.keycode = KEY_D
	right.pressed = true
	get_viewport().push_input(right, true)
	await get_tree().process_frame
	main._process(0.1)
	right = InputEventKey.new()
	right.keycode = KEY_D
	right.pressed = false
	get_viewport().push_input(right, true)
	check(main.world_container.position.x < camera_before.x and main._camera_keys.is_empty(), "Keyboard panning moves and releases correctly")
	await click(main.get_node("UILayer/TownActions/CenterTown").get_global_rect().get_center())
	camera_before = main.world_container.position
	await drag_mouse(main.get_node("UILayer/TownActions/ToggleGrid").get_global_rect().get_center(), Vector2(900, 250))
	check(main.world_container.position.distance_to(camera_before) < 0.05, "Starting a drag on UI does not pan behind it")
	var scenery = main.get_node("WorldContainer/Landscape")
	var scenery_count: int = scenery.get_child_count()
	var first_cell: Vector2i = scenery.get_child(0).get_meta("cell")
	scenery.rebuild()
	check(scenery_count > 20 and scenery.get_child_count() == scenery_count and scenery.get_child(0).get_meta("cell") == first_cell, "Scenery is present and deterministic across rebuilds")
	check(main._occupied_coords.size() == 13 and SaveManager.current_save.town_layouts["Vanilla"].starting_objects.size() == 2, "Scenery does not occupy building cells or create saved structures")
	check(not main.get_node("WorldContainer/Grid").grid_visible, "Grid starts hidden during normal play")
	await click(main.get_node("UILayer/ToggleBuildMenuButton").get_global_rect().get_center())
	check(main.build_menu.visible, "Build button opens catalogue with actual mouse events")
	var tabs = main.build_menu.tab_container
	var house_tab := -1
	for index in range(tabs.get_tab_count()):
		if tabs.get_tab_title(index) == "HOUSE":
			house_tab = index
	check(house_tab >= 0, "Housing tab exists")
	if house_tab < 0:
		get_tree().quit(1)
		return
	var bar = tabs.get_tab_bar()
	await click(bar.global_position + bar.get_tab_rect(house_tab).get_center())
	var buy = tabs.get_child(house_tab).get_child(0).get_child(0)
	await click(buy.get_global_rect().get_center())
	check(main._placement_mode_active and not main.build_menu.visible, "Catalogue click starts preview and releases GUI input")
	check(main.get_node("WorldContainer/Grid").placement_grid, "Placement automatically reveals the diamond grid")
	var count_before: int = SaveManager.current_save.town_layouts["Vanilla"].starting_objects.size()
	await click(main.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(8.2, 4.2))))
	var objects = SaveManager.current_save.town_layouts["Vanilla"].starting_objects
	check(objects.size() == count_before + 1 and not main._placement_mode_active, "Mouse confirms building on the displayed diamond grid")
	check(objects.back().x == 8 and objects.back().y == 4, "Screen click persists the correct saved tile coordinates")
	var clear_footprint := true
	for marker in scenery.get_children():
		if Rect2i(8, 4, 2, 2).has_point(marker.get_meta("cell")):
			clear_footprint = false
	check(clear_footprint and not main.get_node("WorldContainer/Grid").placement_grid, "Building placement clears scenery and restores the normal landscape view")
	await click(main.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(9, 5))))
	check(main.building_popup.visible and main.building_popup.name_label.text == "Small Cottage", "Placed cottage is selectable on its footprint")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape, true)
	await get_tree().process_frame
	check(not main.building_popup.visible, "Escape closes a popup as an input recovery path")
	await click(main.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(5, 1))))
	check(main.building_popup.visible and main.building_popup.name_label.text == "Logging Camp", "Mouse picks camp after cottage placement")
	await click(main.building_popup.assign_worker_button.get_global_rect().get_center())
	await click(main.building_popup.assign_hauler_button.get_global_rect().get_center())
	check(objects[1].assigned_worker_ids.size() == 1 and objects[1].assigned_hauler_ids.size() == 1, "Actual worker and hauler buttons assign citizens")
	await click(main.building_popup.close_button.get_global_rect().get_center())
	check(not main.building_popup.visible, "Producer popup also closes after assigning staff")
	var projection_ok := true
	for x in range(12):
		for y in range(12):
			projection_ok = projection_ok and TownGridGeometry.world_to_cell(TownGridGeometry.cell_to_world(Vector2(x + 0.5, y + 0.5))) == Vector2i(x, y)
	check(projection_ok, "144 tile centers round-trip through the shared isometric projection")
	var save = SocialManager._get_save()
	save.daily_special["expires"] = 1000
	for iteration in range(41):
		SocialManager._process(15.0)
	check(save.daily_special["expires"] == 959, "41 periodic social ticks finish past typed-array trade filtering")
	check(is_same_typed(save.active_trades), "Trade list retains its declared Dictionary element type")
	var mail_count: int = save.inbox_messages.size()
	seed(2400)
	for iteration in range(30):
		SocialManager._spawn_random_gift(save)
	check(save.inbox_messages.size() == mail_count + 30, "All randomized gift templates format and append successfully")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://interaction-town.png")
	main.queue_free()
	await get_tree().process_frame
	print("[InteractionTests] %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func is_same_typed(trades: Array) -> bool:
	return trades.is_typed() and trades.get_typed_builtin() == TYPE_DICTIONARY
