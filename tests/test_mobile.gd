extends Node

var failures := 0
var game: Node

func check(value: bool, message: String) -> void:
	print("[MobileTests] %s: %s" % ["PASS" if value else "FAIL", message])
	if not value: failures += 1

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	get_viewport().push_input(event)

func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	get_viewport().push_input(event)

func tap(point: Vector2) -> void:
	touch(0, point, true)
	touch(0, point, false)

func press(button: BaseButton) -> void:
	var parent := button.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout
	check(button.is_visible_in_tree() and not button.disabled, "Touch target available: " + button.text)
	await ui_tap(button.get_global_rect().get_center())

func ui_tap(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 8
	event.position = point
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().create_timer(0.05).timeout
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().create_timer(0.05).timeout

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Autosave.set_process(false)
	# Deterministic scenario: UI frames do not advance production between assertions.
	# Explicit production/travel ticks below exercise the real managers.
	EconomyManager.set_process(false)
	WorkerManager.set_process(false)
	GameManager.start_new_game()
	get_window().size = Vector2i(1152, 648)
	game = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.mobile_ui.force_mobile = true
	game.mobile_ui.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not game.mobile_ui.goals_open and game.mobile_ui._goal_summary.visible, "Mobile goals start collapsed with a visible objective summary")
	check(not game._feedback.visible, "Help does not reserve a permanent strip")
	await press(game.mobile_ui._goal_summary)
	check(game.mobile_ui.goals_open and game.tutorial_popup.visible, "Touch expands goal details and rewards")
	await press(game.mobile_ui._goal_summary)
	check(not game.mobile_ui.goals_open and not game.tutorial_popup.visible, "Touch collapses goal details")
	var help_button: Button
	for button in game.mobile_ui._toolbar_scroll.get_child(0).get_children():
		if button.text == "?": help_button = button
	await press(help_button)
	check(game.mobile_ui._help.visible and game.is_ui_point(Vector2(500, 400)), "Help opens on touch and blocks world actions behind its dialog")
	game.mobile_ui._help.hide()
	# Input.parse_input_event exercises Godot's touch-to-GUI mouse emulation.
	game.build_menu.hide()
	var build_button: Button = game.get_node("UILayer/ToggleBuildMenuButton")
	var ui_event := InputEventScreenTouch.new()
	ui_event.index = 8
	ui_event.position = build_button.get_global_rect().get_center()
	ui_event.pressed = true
	Input.parse_input_event(ui_event)
	await get_tree().process_frame
	ui_event = ui_event.duplicate()
	ui_event.pressed = false
	Input.parse_input_event(ui_event)
	await get_tree().process_frame
	check(game.build_menu.visible, "Native touch-to-mouse emulation activates the GUI Build button once")
	game.building_popup.hide()
	game.tutorial_popup.hide()
	var original_count: int = SaveManager.current_save.town_layouts.Vanilla.starting_objects.size()
	var catalog: TabContainer = game.build_menu.tab_container
	await get_tree().create_timer(0.1).timeout
	for index in range(catalog.get_tab_count()):
		if catalog.get_tab_title(index).to_lower() == "house":
			var bar := catalog.get_tab_bar()
			await ui_tap(bar.global_position + bar.get_tab_rect(index).get_center())
			check(catalog.current_tab == index, "Touch selects the HOUSE catalog tab")
	for card in game.build_menu.find_children("*", "Button", true, false):
		if card.get_meta("definition_id", -1) == 10012:
			await press(card)
			break
	check(game._placement_mode_active, "Touch catalog selects a Small Cottage without a keyboard")
	var old: Vector2 = game.world_container.position
	touch(0, Vector2(380, 300), true)
	drag(0, Vector2(450, 350))
	touch(0, Vector2(450, 350), false)
	check(game.world_container.position != old and SaveManager.current_save.town_layouts.Vanilla.starting_objects.size() == original_count, "One finger pans during placement without building")
	var before := Vector2(360, 330)
	var after := Vector2(385, 330)
	var beneath: Vector2 = game.world_container.to_local(before)
	touch(0, Vector2(310, 330), true)
	touch(1, Vector2(410, 330), true)
	drag(1, Vector2(460, 330))
	check(game.world_container.to_global(beneath).distance_to(after) < 0.01, "Pinch keeps its world point beneath the moving midpoint")
	touch(1, Vector2(460, 330), false)
	touch(0, Vector2(310, 330), false)
	check(SaveManager.current_save.town_layouts.Vanilla.starting_objects.size() == original_count, "Pinch releases cannot place a structure")
	var preview_before: Vector2 = game._ghost_building.position
	tap(Vector2(10, 20))
	check(game._ghost_building.position == preview_before and game.touch_camera.points.is_empty(), "HUD touches never enter a world gesture")
	# Emulated mouse events may operate GUI, but never gameplay a second time.
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.position = Vector2(500, 350)
	game._unhandled_input(emulated)
	check(SaveManager.current_save.town_layouts.Vanilla.starting_objects.size() == original_count, "Emulated mouse cannot duplicate touch actions")
	# A tap only positions the ghost. The same public Confirm button commits it.
	game.world_container.scale = Vector2.ONE
	game.world_container.position = Vector2(300, 180)
	var site: Vector2 = game.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(8.2, 4.2)))
	tap(site)
	check(game._ghost_building.building_instance.x == 8 and game._ghost_building.building_instance.y == 4 and SaveManager.current_save.town_layouts.Vanilla.starting_objects.size() == original_count, "Tap positions a cottage preview without committing it")
	await press(game._layout_bar.get_child(3))
	EconomyManager._update_construction(4)
	check(WorkerManager.total_population() == 4, "Confirm cottage and construction grant its two residents")
	var camp: BuildingInstance = SaveManager.current_save.town_layouts.Vanilla.starting_objects[1]
	tap(game.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(camp.x + 1, camp.y + 1))))
	check(game.building_popup.visible and game.building_popup.building_instance == camp, "Map tap selects the Logging Camp")
	await press(game.building_popup.assign_worker_button)
	await press(game.building_popup.assign_hauler_button)
	WorkerManager._update_travel(60)
	EconomyManager._process_producers(12)
	check(camp.assigned_worker_ids.size() == 1 and camp.assigned_hauler_ids.size() == 1 and camp.stored_resources.get(10, 0) > 0, "Visible worker controls assign staff and produce Wood")
	game._collect_resources()
	game._town_panels.open_market()
	game.building_popup.hide()
	var gold: float = InventoryManager.amount(1)
	await press(game._town_panels.market_box.get_child(1).get_child(2))
	check(InventoryManager.amount(1) > gold, "Visible market Sell control sells harvested goods")
	game._town_panels.hide()
	var snapshot := [camp.x, camp.y, camp.rotation_degrees, camp.assigned_worker_ids.duplicate(), camp.cycle_elapsed]
	tap(game.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(camp.x + 1, camp.y + 1))))
	var layout_tabs: TabBar = game.building_popup.tabs
	await ui_tap(layout_tabs.global_position + layout_tabs.get_tab_rect(2).get_center())
	await press(game.building_popup.move_button)
	await press(game._layout_bar.get_child(2))
	await press(game._layout_bar.get_child(4))
	check(snapshot == [camp.x, camp.y, camp.rotation_degrees, camp.assigned_worker_ids, camp.cycle_elapsed], "Cancel move/rotation preserves the original structure and jobs")
	tap(game.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(camp.x + 1, camp.y + 1))))
	await ui_tap(layout_tabs.global_position + layout_tabs.get_tab_rect(2).get_center())
	await press(game.building_popup.move_button)
	tap(game.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(10.2, 6.2))))
	await press(game._layout_bar.get_child(2))
	await press(game._layout_bar.get_child(3))
	check(camp.x == 10 and camp.y == 6 and camp.rotation_degrees == 90, "Visible confirm applies move and rotation")
	game._cancel_placement()
	game._brush_bar.show()
	game._select_brush("dirt")
	game.world_container.position = Vector2(400, 160)
	var path_point: Vector2 = game.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(5.2, 6.2)))
	tap(path_point)
	check(not SaveManager.current_save.ground_decorations.has(Vector2i(5, 6)), "Touch paths remain a preview before confirmation")
	await press(game._brush_bar.get_child(game._brush_bar.get_child_count() - 1))
	check(SaveManager.current_save.ground_decorations.get(Vector2i(5, 6)) == "dirt", "Visible Confirm places a path without keyboard input")
	game._cancel_brush()
	var canceled_gold: float = InventoryManager.amount(1)
	game._brush_bar.show()
	game._select_brush("dirt")
	game._append_brush(Vector2i(6, 6))
	game._cancel_brush()
	check(not SaveManager.current_save.ground_decorations.has(Vector2i(6, 6)) and InventoryManager.amount(1) == canceled_gold, "Cancel path preview preserves decorations and resources")
	await press(game.get_node("UILayer/MobileToolbar/TownActions/Save"))
	TutorialManager.refresh()
	var reward_gold: float = InventoryManager.amount(1)
	var claims: Array = SaveManager.current_save.objective_claims.duplicate()
	# Repeated focus events are idempotent and do not grant offline catch-up.
	Autosave.suspended = false
	Autosave._focus_lost = false
	Autosave._paused = false
	var writes: int = Autosave.writes
	Autosave._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	Autosave._notification(NOTIFICATION_APPLICATION_PAUSED)
	Autosave._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(Autosave.writes == writes + 1, "Focus loss and pause flush exactly once per interruption")
	var progress: float = camp.cycle_elapsed
	var people: int = WorkerManager.total_population()
	EconomyManager._process(3600)
	WorkerManager._process(3600)
	Autosave._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(Autosave.suspended and camp.cycle_elapsed == progress, "Focus-in cannot resume while the application is still paused")
	Autosave._notification(NOTIFICATION_APPLICATION_RESUMED)
	Autosave._notification(NOTIFICATION_APPLICATION_RESUMED)
	EconomyManager._process(3600)
	check(camp.cycle_elapsed == progress and WorkerManager.total_population() == people, "Repeated resume does not duplicate production or villagers")
	TutorialManager.refresh()
	check(SaveManager.current_save.objective_claims == claims and InventoryManager.amount(1) == reward_gold, "Repeated resume does not duplicate claimed goal rewards")
	check(SaveManager.load_from_slot(1) != null and SaveManager.current_save.ground_decorations.get(Vector2i(5, 6)) == "dirt", "Autosaved town reloads with paths and existing save format")
	# A partial pending write must not replace the last complete generation.
	var pending := "user://saves/slot_1.pending.tres"
	var interrupted := FileAccess.open(pending, FileAccess.WRITE)
	interrupted.store_string("interrupted partial write")
	interrupted.close()
	check(SaveManager.load_from_slot(1) != null and SaveManager.current_save.inventory.resource_amounts[1] == reward_gold, "Interrupted pending write leaves the committed save recoverable")
	DirAccess.remove_absolute(pending)
	Autosave._elapsed = 0.0
	Autosave.mark_dirty()
	writes = Autosave.writes
	Autosave._process(1.0)
	check(Autosave.writes == writes, "Meaningful changes debounce rather than save every signal")
	Autosave._process(1.5)
	check(Autosave.writes == writes + 1 and FileAccess.file_exists("user://saves/slot_1.backup.tres"), "Debounced autosave retains a recoverable previous generation")
	game._refresh_world()
	for dimensions in [Vector2i(740, 360), Vector2i(852, 393), Vector2i(1152, 648), Vector2i(1440, 660)]:
		get_window().size = dimensions
		await get_tree().process_frame
		game.mobile_ui.refresh()
		await get_tree().process_frame
		var bounds: Rect2 = get_viewport().get_visible_rect()
		var hud: Control = game.get_node("UILayer/ResourceHud")
		check(hud.size.y <= 50 and game.mobile_ui._toolbar_scroll.size.y == 44, "Compact header fits %s" % dimensions)
		for label in game.mobile_ui._hud_flow.get_children():
			check(hud.get_global_rect().encloses(label.get_global_rect()), "Resource remains visible: " + label.text)
		var build: Control = game.get_node("UILayer/ToggleBuildMenuButton")
		check(bounds.encloses(build.get_global_rect()) and build.size.y >= 44, "Build stays reachable at %s landscape" % dimensions)
		game._on_building_instance_selected(WorkerManager.instance_by_id(camp.instance_id))
		check(bounds.encloses(game.building_popup.get_global_rect()) and game.building_popup.close_button.size.y >= 48, "Details drawer and close target fit %s" % dimensions)
		game.building_popup.hide()
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(852, 393)
		await get_tree().process_frame
		game._on_building_instance_selected(WorkerManager.instance_by_id(camp.instance_id))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://mobile-landscape.png")
	game.queue_free()
	await get_tree().process_frame
	print("[MobileTests] %d failure(s). Desktop event injection; no iPhone device test." % failures)
	get_tree().quit(1 if failures else 0)
