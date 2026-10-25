extends "res://tests/test_mobile.gd"

func run() -> void:
	Autosave.set_process(false)
	EconomyManager.set_process(false)
	WorkerManager.set_process(false)
	GameManager.start_new_game()
	get_window().size = Vector2i(1152, 648)
	var save = SaveManager.current_save
	save.player_state.mayor_level = 50
	ProgressionManager.sync_unlocks()
	for id in [1, 10, 20, 40, 11, 21, 50, 51]: save.inventory.resource_amounts[id] = 100000
	game = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.mobile_ui.force_mobile = true
	game.mobile_ui.refresh()
	await get_tree().process_frame
	var hall: BuildingInstance = save.town_layouts.Vanilla.starting_objects[0]
	game._on_building_instance_selected(hall)
	await press(game.building_popup.upgrade_button)
	check(game.building_popup._upgrade_confirmation.visible, "Touch opens a priced upgrade confirmation")
	var gold: float = InventoryManager.amount(1)
	await press(game.building_popup._upgrade_confirmation.get_cancel_button())
	check(hall.def_id == 10001 and hall.pending_upgrade_id == -1 and InventoryManager.amount(1) == gold, "Touch Cancel preserves the original civic building and coins")
	await press(game.building_popup.upgrade_button)
	await press(game.building_popup._upgrade_confirmation.get_ok_button())
	EconomyManager._update_construction(31)
	check(hall.def_id == 2, "Touch confirmation upgrades the Town Hall in place")
	game.building_popup.hide()
	var home := BuildingInstance.new()
	home.instance_id = "touch_home"
	home.def_id = 12
	home.x = 8
	home.y = 2
	save.town_layouts.Vanilla.starting_objects.append(home)
	WorkerManager.reconcile_housing()
	game._refresh_world()
	game._on_building_instance_selected(home)
	await press(game.building_popup.upgrade_button)
	await press(game.building_popup._upgrade_confirmation.get_ok_button())
	EconomyManager._update_construction(31)
	check(home.def_id == 37 and WorkerManager.capacity_for(home) == 2, "Housing upgrade is playable without a keyboard")
	HistoricalGameplay.update_taxes(21600)
	game.building_popup._update_display()
	gold = InventoryManager.amount(1)
	await press(game.building_popup.tax_button)
	check(InventoryManager.amount(1) == gold + 8 and home.tax_gold == 0, "Touch collects exactly one historical housing tax")
	game.building_popup.hide()
	var shop := BuildingInstance.new()
	shop.instance_id = "touch_carpenter"
	shop.def_id = 32
	shop.x = 1
	shop.y = 8
	save.town_layouts.Vanilla.starting_objects.append(shop)
	game._refresh_world()
	game._on_building_instance_selected(shop)
	await press(game.building_popup.assign_worker_button)
	WorkerManager._update_travel(120)
	EconomyManager._process_producers(0.01)
	check(shop.cycle_reserved, "Touch-assigned Carpenter starts a real paid job")
	await press(game.building_popup.recipe_choice)
	var popup: PopupMenu = game.building_popup.recipe_choice.get_popup()
	check(popup.visible, "Recipe menu opens by touch")
	await ui_tap(Vector2(popup.position) + Vector2(24, popup.size.y / float(popup.item_count) * 1.5))
	check(shop.queued_recipe_id == 32 and shop.cycle_reserved, "Touch queues the next recipe without losing the paid job")
	game.building_popup.hide()
	for dimensions in [Vector2i(740, 360), Vector2i(852, 393), Vector2i(1152, 648)]:
		get_window().size = dimensions
		await get_tree().process_frame
		game.mobile_ui.refresh()
		game._on_building_instance_selected(home)
		await get_tree().process_frame
		check(game.mobile_ui.safe_rect.encloses(game.building_popup.get_global_rect()), "Housing drawer remains reachable with full resource HUD at %s" % dimensions)
		game.building_popup.hide()
	game.queue_free()
	await get_tree().process_frame
	print("[HistoricalTouchTests] %d failure(s). Injected desktop touch; no physical iPhone test." % failures)
	get_tree().quit(1 if failures else 0)
