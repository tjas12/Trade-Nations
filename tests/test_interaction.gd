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
	var count_before: int = SaveManager.current_save.town_layouts["Vanilla"].starting_objects.size()
	await click(main.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(8.2, 4.2))))
	var objects = SaveManager.current_save.town_layouts["Vanilla"].starting_objects
	check(objects.size() == count_before + 1 and not main._placement_mode_active, "Mouse confirms building on the displayed diamond grid")
	check(objects.back().x == 8 and objects.back().y == 4, "Screen click persists the correct saved tile coordinates")
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
