## Main
## Root scene script. Orchestrates the main game view, including UI and building placement.
extends Node

const BuildingScene = preload("res://scenes/building.tscn")
const BuildingInstance = preload("res://resources/runtime/building_instance.gd")
const BuildingDefinition = preload("res://resources/definitions/building_definition.gd")
const TransientMessageScene = preload("res://scenes/ui/transient_message.tscn")

# --- State ---
var _placement_mode_active: bool = false
var _building_to_place_def: BuildingDefinition = null
var _ghost_building: Node2D = null
var _occupied_coords: Dictionary = {} # Key: Vector2i, Value: bool
var _next_instance_id: int = 1

# --- Scene Refs ---
@onready var world_container = $WorldContainer
@onready var build_menu = $UILayer/BuildMenu
@onready var building_popup = $UILayer/BuildingPopup
@onready var tutorial_popup = $UILayer/TutorialPopup


var _visiting_friend_name: String = ""
var _return_home_btn: Button = null
var _save_blocked: bool = false
var _panning: bool = false
var _pan_button: int = 0
var _pan_start := Vector2.ZERO
var _pan_last := Vector2.ZERO
var _camera_keys: Dictionary = {}
var _feedback: Label
var _town_panels: Panel
var _debug_tools: HBoxContainer
var _moving_instance: BuildingInstance
var _layout_bar: HBoxContainer
var _orientation_label: Label
var _placement_reason := ""
var _rotation_only := false
var _position_button: Button
var _decor_layer: GroundDecorations
var _brush_kind := ""
var _brush_down := false
var _brush_cells: Dictionary = {}
var _brush_last := Vector2i.ZERO
var _brush_bar: HBoxContainer
var _brush_label: Label
var _floating_lanes: Dictionary = {}
var touch_camera := TouchCamera.new()
var mobile_ui: Node
var touch_mode := false

func _initialize_save() -> void:
	if SaveManager.current_save == null:
		if GameManager.continue_game(1) == null:
			_save_blocked = FileAccess.file_exists("user://saves/slot_1.tres") or FileAccess.file_exists("user://saves/slot_1.backup.tres")
			GameManager.start_new_game()

func _ready() -> void:
	get_window().min_size = Vector2i(640, 360)
	touch_mode = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if touch_mode:
		get_window().content_scale_size = Vector2i(960, 440)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_initialize_save()
	print("[Main] Scene ready. GameManager state = %s" % GameManager.State.keys()[GameManager.current_state])
	TutorialManager.set_tutorial_popup(tutorial_popup)
	
	EventBus.building_selected_for_placement.connect(_on_building_selected_for_placement)
	EventBus.building_instance_selected.connect(_on_building_instance_selected)
	EventBus.spawn_floating_text.connect(_on_spawn_floating_text)
	EventBus.worker_assigned.connect(_on_worker_or_hauler_assigned.bind(1))
	EventBus.hauler_assigned.connect(_on_worker_or_hauler_assigned.bind(2))
	EventBus.visit_friend_requested.connect(_on_visit_friend_requested)
	EventBus.return_home_requested.connect(_on_return_home_requested)

	_initialize_world_layout()
	_decor_layer = GroundDecorations.new()
	_decor_layer.name = "GroundDecorations"
	world_container.add_child(_decor_layer)
	_restore_walkers()
	_add_town_controls()
	mobile_ui = load("res://scripts/ui/mobile_layout.gd").new()
	mobile_ui.game = self
	add_child(mobile_ui)
	if OS.has_feature("web"):
		print("[BrowserStorage] Persistent user filesystem initialized: %s" % not SaveManager.browser_storage_blocked())
		if SaveManager.browser_storage_blocked():
			_save_blocked = true
			call_deferred("_show_browser_storage_failure")

func _show_browser_storage_failure() -> void:
	var warning := AcceptDialog.new()
	warning.title = "Browser storage is unavailable"
	warning.dialog_text = "This temporary session cannot load or save your existing town.\nNo existing save has been replaced. Enable website storage, leave private browsing, and reopen the same game address."
	warning.get_ok_button().custom_minimum_size = Vector2(100, 52)
	$UILayer.add_child(warning)
	warning.popup_centered(Vector2i(580, 200))

func _add_town_controls() -> void:
	var toolbar := HBoxContainer.new()
	toolbar.name = "TownActions"
	toolbar.position = Vector2(16, 49)
	$UILayer.add_child(toolbar)
	for item in [["Save", _save_town], ["Load", _choose_save], ["Collect", _collect_resources], ["Center town", _center_town]]:
		var button := Button.new()
		button.text = item[0]
		button.name = "CenterTown" if item[0] == "Center town" else item[0]
		button.pressed.connect(item[1])
		toolbar.add_child(button)
	var grid := Button.new()
	grid.name = "ToggleGrid"
	grid.text = "Grid: Off"
	grid.pressed.connect(func(): grid.text = "Grid: On" if $WorldContainer/Grid.toggle_grid() else "Grid: Off")
	toolbar.add_child(grid)
	_town_panels = load("res://scripts/ui/town_panels.gd").new()
	$UILayer.add_child(_town_panels)
	for item in [["Market", _town_panels.open_market], ["Expand", _town_panels.open_expansion]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(func():
			building_popup.hide()
			build_menu.hide()
			item[1].call()
		)
		toolbar.add_child(button)
	var new_town := Button.new()
	new_town.text = "New town…"
	var confirm_new := ConfirmationDialog.new()
	confirm_new.title = "Start a new town?"
	confirm_new.dialog_text = "Your current town will be archived in a free local save slot first.\nUse Load to return to it. The new town begins with the introductory goals."
	confirm_new.confirmed.connect(_new_town)
	$UILayer.add_child(confirm_new)
	new_town.pressed.connect(func(): confirm_new.popup_centered())
	toolbar.add_child(new_town)
	_feedback = Label.new()
	_feedback.position = Vector2(16, 89)
	_feedback.text = "Drag ground / WASD: pan · Wheel: zoom · Home: center · F5: save · F9: load"
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UILayer.add_child(_feedback)
	EventBus.town_notice.connect(func(message): _feedback.text = message)
	EventBus.population_changed.connect(func(_total, _idle): call_deferred("_sync_walkers"))
	EventBus.building_move_requested.connect(_start_move)
	EventBus.building_rotate_requested.connect(_start_rotate)
	_create_layout_bar()
	_create_brush_bar()
	EventBus.building_demolish_requested.connect(_demolish)
	EventBus.town_changed.connect(_refresh_world)
	var close_menu := Button.new()
	close_menu.text = "Close catalog"
	close_menu.position = Vector2(12, 12)
	close_menu.pressed.connect(build_menu.hide)
	build_menu.add_child(close_menu)
	# Developer clock is hidden in normal play. F3 toggles it.
	_debug_tools = HBoxContainer.new()
	_debug_tools.position = Vector2(16, 120)
	_debug_tools.hide()
	$UILayer.add_child(_debug_tools)
	var speed := Button.new()
	speed.text = "Developer: Time 1×"
	speed.pressed.connect(func():
		EconomyManager.simulation_speed = 60 if EconomyManager.simulation_speed == 1 else 1
		speed.text = "Developer: Time %d×" % EconomyManager.simulation_speed
	)
	_debug_tools.add_child(speed)

func _center_town() -> void:
	world_container.scale = Vector2.ONE
	var center := Vector2.ZERO
	var count := 0
	for instance in SaveManager.current_save.town_layouts["Vanilla"].starting_objects:
		var definition = DataManager.get_building_definition(instance.def_id)
		if definition:
			var size := TownGridGeometry.footprint_size(definition.width, definition.height, instance.rotation_degrees)
			center += TownGridGeometry.cell_to_world(Vector2(instance.x, instance.y) + Vector2(size) * 0.5)
			count += 1
	if count > 0:
		center /= count
	var viewport_size := get_viewport().get_visible_rect().size
	world_container.position = Vector2(viewport_size.x * 0.5, (viewport_size.y + 140.0) * 0.5) - center

func _pan_camera(offset: Vector2) -> void:
	world_container.position += offset
	# Keep the viewing center inside the diamond, rather than allowing a lost map.
	var view_size := get_viewport().get_visible_rect().size
	var screen_center := Vector2(view_size.x * 0.5, (view_size.y + 140.0) * 0.5)
	var local: Vector2 = world_container.to_local(screen_center)
	var cell := Vector2((local.x / 32.0 + local.y / 16.0) * 0.5, (local.y / 16.0 - local.x / 32.0) * 0.5)
	var cells: float = SaveManager.current_save.player_state.active_land_size
	cell = cell.clamp(Vector2.ZERO, Vector2.ONE * cells)
	world_container.position = screen_center - TownGridGeometry.cell_to_world(cell) * world_container.scale.x

func _begin_pan(event: InputEventMouseButton) -> void:
	_pan_button = event.button_index
	_pan_start = event.position
	_pan_last = event.position
	_panning = false

func _stop_pan() -> void:
	_pan_button = 0
	_panning = false

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		touch_camera.reset()
		_stop_pan()
		_cancel_brush()
		_camera_keys.clear()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if touch_camera.handle(event, self): get_viewport().set_input_as_handled()
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if _brush_down and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_brush()
		get_viewport().set_input_as_handled()
		return
	# Once a ground drag starts, track it across UI and always see its release.
	if event is InputEventMouseButton and event.button_index == _pan_button and not event.pressed:
		var dragged := _panning
		var map_click := _pan_button == MOUSE_BUTTON_LEFT and not dragged and not is_ui_point(event.position)
		_stop_pan()
		if map_click: map_tap(event.position, false)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and _pan_button != 0:
		var mask := MOUSE_BUTTON_MASK_LEFT if _pan_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE
		if (event.button_mask & mask) == 0:
			_stop_pan()
			return
		if _pan_start.distance_to(event.position) >= 5.0:
			_panning = true
		if _panning:
			_pan_camera(event.position - _pan_last)
			get_viewport().set_input_as_handled()
		_pan_last = event.position
	if event is InputEventKey and event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
		if not event.pressed:
			_camera_keys.erase(event.keycode)
		elif not build_menu.visible and not building_popup.visible:
			_camera_keys[event.keycode] = true
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		_center_town()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if is_instance_valid(_town_panels):
		tutorial_popup.visible = not build_menu.visible and not _town_panels.visible and (not touch_mode or mobile_ui.goals_open)
	if build_menu.visible or building_popup.visible or (is_instance_valid(_town_panels) and _town_panels.visible):
		_camera_keys.clear()
		return
	var direction := Vector2(
		int(_camera_keys.has(KEY_D) or _camera_keys.has(KEY_RIGHT)) - int(_camera_keys.has(KEY_A) or _camera_keys.has(KEY_LEFT)),
		int(_camera_keys.has(KEY_S) or _camera_keys.has(KEY_DOWN)) - int(_camera_keys.has(KEY_W) or _camera_keys.has(KEY_UP)))
	if direction != Vector2.ZERO:
		_pan_camera(-direction.normalized() * 480.0 * delta)

func _collect_resources() -> void:
	var collected := 0.0
	for instance in SaveManager.current_save.town_layouts["Vanilla"].starting_objects:
		for resource_id in instance.stored_resources.keys():
			var moved := InventoryManager.add(resource_id, instance.stored_resources[resource_id])
			instance.stored_resources[resource_id] -= moved
			collected += moved
			EventBus.building_storage_changed.emit(instance.instance_id, resource_id, instance.stored_resources[resource_id])
	EconomyManager._restore_assignments()
	_feedback.text = "Collected %.1f resources. Haulers also deliver automatically." % collected

func _save_town() -> void:
	var msg = TransientMessageScene.instantiate()
	if SaveManager.browser_storage_blocked():
		msg.text = "Browser storage is unavailable. Enable website storage and reopen the game; existing saves were not replaced."
	elif _save_blocked:
		msg.text = "Existing saves could not load. Copy them aside before recovery; saving is blocked."
	else:
		msg.text = "Town saved." if SaveManager.save_to_slot(1) else "Save failed. Previous save retained."
	$UILayer.add_child(msg)

func _load_town() -> void:
	if GameManager.continue_game(1) != null:
		get_tree().reload_current_scene()
	else:
		EventBus.town_notice.emit("No recoverable main save found. Existing files were left unchanged.")

func _restore_walkers() -> void:
	_sync_walkers()

func _sync_walkers() -> void:
	var shown: Dictionary = {}
	for child in world_container.get_children():
		if child is VillagerWalker and not child.is_queued_for_deletion():
			shown[child.villager_id] = true
	for citizen in SaveManager.current_save.villagers:
		if not shown.has(citizen.villager_id):
			var walker := VillagerWalker.new()
			walker.configure(citizen.villager_id, citizen.villager_name, citizen.role, Vector2.ZERO, Vector2.ZERO)
			world_container.add_child(walker)

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if not _brush_kind.is_empty() and _brush_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			_begin_pan(event)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var mouse: Vector2 = event.position
			var factor := 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			zoom_camera(mouse, mouse, factor)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not _placement_mode_active:
			building_popup.hide()
			build_menu.hide()
			_town_panels.hide()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R and not _placement_mode_active and building_popup.visible:
			_start_rotate(building_popup.building_instance, -1 if event.shift_pressed else 1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F3:
			_debug_tools.visible = not _debug_tools.visible
		if event.keycode == KEY_F5:
			_save_town()
		elif event.keycode == KEY_F9:
			_load_town()
	if not _placement_mode_active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_begin_pan(event)
		return

	if event is InputEventMouseMotion:
		if not _rotation_only: _update_ghost_position(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_begin_pan(event)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_placement()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancel_placement()
		elif event.keycode == KEY_R:
			_rotate_preview(-1 if event.shift_pressed else 1)

func _pick_building(point: Vector2) -> BuildingInstance:
	var candidates: Array[Node] = []
	for child in world_container.get_children():
		if child != _ghost_building and child.has_method("contains_screen_point") and not child.is_queued_for_deletion():
			candidates.append(child)
	candidates.sort_custom(func(a, b): return a.z_index > b.z_index if a.z_index != b.z_index else a.position.y > b.position.y)
	for building in candidates:
		if building.contains_screen_point(point):
			return building.building_instance
	return null


# --- Private Methods ---

func _initialize_world_layout() -> void:
	if not SaveManager.current_save:
		# This can happen if game is run directly from Main.tscn
		# For development, we can create a new save here.
		print("[Main] No current save found. Creating a new one for this session.")
		GameManager.start_new_game()
		if not SaveManager.current_save:
			push_error("[Main] Failed to create a new save. World cannot be initialized.")
			return

	var layout = SaveManager.current_save.town_layouts.get("Vanilla")
	if not layout:
		push_error("[Main] No 'Vanilla' layout found in save file.")
		return

	# Load initial buildings from the save file
	for instance in layout.starting_objects:
		_create_building_node(instance)
		var grid_pos = Vector2i(instance.x, instance.y)
		var building_def = DataManager.get_building_definition(instance.def_id)
		if building_def:
			_add_building_to_occupied_grid(grid_pos, building_def, instance.rotation_degrees)
		
		# Ensure instance IDs are unique
		var id_num = instance.instance_id.to_int()
		if id_num >= _next_instance_id:
			_next_instance_id = id_num + 1


func _on_building_selected_for_placement(building_def: BuildingDefinition) -> void:
	_cancel_brush()
	if SaveManager.current_save.player_state.mayor_level < building_def.playable_level:
		EventBus.town_notice.emit("Reach level %d first." % building_def.playable_level)
		return
	if _placement_mode_active:
		_cancel_placement()

	if not EconomyManager.can_afford(building_def.cost):
		var msg = TransientMessageScene.instantiate()
		msg.text = "Not enough resources!"
		$UILayer.add_child(msg)
		return

	print("[Main] Entering placement mode for: %s" % building_def.display_name)
	_building_to_place_def = building_def
	if _building_to_place_def:
		_ghost_building = BuildingScene.instantiate()
		world_container.add_child(_ghost_building)
		var temp_instance = BuildingInstance.new()
		temp_instance.def_id = building_def.id
		_ghost_building.set_building(temp_instance)
		_ghost_building.modulate = Color(1, 1, 1, 0.5)
		_placement_mode_active = true
		$WorldContainer/Grid.set_placement_grid(true)
		_update_ghost_position(get_viewport().get_visible_rect().size * 0.5 if touch_mode else Vector2.INF)

func _update_ghost_position(mouse_pos: Vector2 = Vector2.INF) -> void:
	if mouse_pos == Vector2.INF:
		mouse_pos = get_viewport().get_mouse_position()
	var world_pos = world_container.get_global_transform().affine_inverse() * mouse_pos

	var cell := TownGridGeometry.world_to_cell(world_pos)
	_ghost_building.position = TownGridGeometry.cell_to_world(Vector2(cell))
	_check_placement_validity()

func _check_placement_validity() -> bool:
	if not _ghost_building: return false

	var cell := TownGridGeometry.world_to_cell(_ghost_building.position)
	var preview: BuildingInstance = _ghost_building.building_instance
	preview.x = cell.x
	preview.y = cell.y
	_placement_reason = TownPaths.layout_reason(preview, _moving_instance.instance_id if _moving_instance else "")
	_ghost_building.z_index = clampi(int(_ghost_building.position.y + _ghost_building.ground_anchor.y), 0, 4000)
	var valid := _placement_reason.is_empty()
	_ghost_building.modulate = Color(0.55, 1, 0.6, 0.7) if valid else Color(1, 0.35, 0.3, 0.7)
	if is_instance_valid(_layout_bar):
		_layout_bar.visible = true
		_position_button.visible = _moving_instance != null
		_position_button.text = "Move position" if _rotation_only else "Pin position"
		_orientation_label.text = BuildingVisuals.facing_label(_building_to_place_def, preview.rotation_degrees)
	EventBus.town_notice.emit(_placement_reason if not valid else ("Tap a site · Rotate, then Confirm · Cancel keeps the original" if touch_mode else "Clear site · Click/Confirm applies · R / Shift+R turns · Escape cancels"))
	return valid

func _place_building() -> void:
	if _placement_mode_active and _check_placement_validity():
		if _building_to_place_def:
			var grid_pos := TownGridGeometry.world_to_cell(_ghost_building.position)
			if _moving_instance:
				_moving_instance.x = grid_pos.x
				_moving_instance.y = grid_pos.y
				_moving_instance.rotation_degrees = _ghost_building.building_instance.rotation_degrees
				_moving_instance.legacy_entrance = Vector2i(-1, -1)
				_cancel_placement()
				_refresh_world()
				Autosave.mark_dirty()
				return
			# Affordability can change while the preview is open.
			if not EconomyManager.can_afford(_building_to_place_def.cost):
				return
			
			var new_instance = BuildingInstance.new()
			new_instance.instance_id = str(_next_instance_id)
			_next_instance_id += 1
			new_instance.def_id = _building_to_place_def.id
			new_instance.construction_complete = _building_to_place_def.build_time_seconds <= 0
			new_instance.x = grid_pos.x
			new_instance.y = grid_pos.y
			new_instance.rotation_degrees = _ghost_building.building_instance.rotation_degrees
			
			SaveManager.current_save.town_layouts["Vanilla"].starting_objects.append(new_instance)
			
			_create_building_node(new_instance)
			
			_add_building_to_occupied_grid(grid_pos, _building_to_place_def, new_instance.rotation_degrees)
			
			EconomyManager.apply_cost(_building_to_place_def.cost)
			
			print("[Main] Placed building: %s (ID: %s)" % [_building_to_place_def.display_name, new_instance.instance_id])
			
			if new_instance.construction_complete:
				EventBus.building_placed.emit(new_instance)
			WorkerManager.invalidate_routes()
			EventBus.town_notice.emit("Building placed. Construction will finish shortly.")
			_cancel_placement()

func _create_building_node(instance: BuildingInstance) -> void:
	var building_node = BuildingScene.instantiate()
	building_node.position = TownGridGeometry.cell_to_world(Vector2(instance.x, instance.y))
	world_container.add_child(building_node)
	building_node.set_building(instance)

func _cancel_placement() -> void:
	if _ghost_building:
		_ghost_building.queue_free()
	_ghost_building = null
	if is_instance_valid(_layout_bar): _layout_bar.hide()
	for child in world_container.get_children():
		if child.get("building_instance") != null: child.editing_original = false
	_placement_mode_active = false
	_rotation_only = false
	if _moving_instance:
		_moving_instance = null
		_rebuild_occupancy()
	$WorldContainer/Grid.set_placement_grid(false)
	_building_to_place_def = null

func _add_building_to_occupied_grid(grid_pos: Vector2i, building_def: BuildingDefinition, rotation_degrees: float = 0.0) -> void:
	var instance := BuildingInstance.new()
	instance.x = grid_pos.x
	instance.y = grid_pos.y
	instance.rotation_degrees = rotation_degrees
	for cell in TownGridGeometry.cells(instance, building_def):
		_occupied_coords[cell] = true

# --- Signal Handlers ---

func _on_toggle_build_menu_pressed() -> void:
	_cancel_brush()
	_cancel_placement()
	build_menu.visible = not build_menu.visible
	if build_menu.visible:
		building_popup.hide()
		_town_panels.hide()
		build_menu.populate_build_menu()

func _on_building_instance_selected(instance: BuildingInstance) -> void:
	build_menu.hide()
	if is_instance_valid(_town_panels): _town_panels.hide()
	building_popup.show_for_building(instance)

func _on_spawn_floating_text(text: String, global_pos: Vector2, color: Color) -> void:
	var key := Vector2i((global_pos / Vector2(100, 70)).floor())
	var lanes: Dictionary = _floating_lanes.get(key, {})
	var lane := 0
	while lanes.has(lane): lane += 1
	if lane >= 3: return
	lanes[lane] = true
	_floating_lanes[key] = lanes
	global_pos.y -= lane * 24
	var label = Label.new()
	label.text = text
	label.position = global_pos
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add beautiful contrast outlining so the numbers are highly visible over grass/terrain
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 16)
	
	world_container.add_child(label)
	
	# Animate float & fade cleanly using Godot 4.7 tweens
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", global_pos.y - 65.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		label.queue_free()
		lanes.erase(lane)
		if lanes.is_empty(): _floating_lanes.erase(key)
	)

func _on_worker_or_hauler_assigned(_villager: Villager, _instance: BuildingInstance, _role_type: int) -> void:
	_sync_walkers()

func _rebuild_occupancy(ignore_id: String = "") -> void:
	_occupied_coords = TownPaths.blocked_cells(ignore_id)

func _refresh_world() -> void:
	for child in world_container.get_children():
		if child.get("building_instance") != null:
			world_container.remove_child(child)
			child.queue_free()
	for instance in SaveManager.current_save.town_layouts["Vanilla"].starting_objects:
		_create_building_node(instance)
	_rebuild_occupancy()
	WorkerManager.invalidate_routes()
	_sync_walkers()

func _start_move(instance: BuildingInstance) -> void:
	_cancel_brush()
	var definition = DataManager.get_building_definition(instance.def_id)
	if definition.type == BuildingDefinition.BuildingType.TOWNHALL:
		EventBus.town_notice.emit("Town Hall stays at the town center.")
		return
	_cancel_placement()
	_moving_instance = instance
	_rotation_only = false
	for child in world_container.get_children():
		if child.get("building_instance") == instance: child.editing_original = true
	_building_to_place_def = definition
	_ghost_building = BuildingScene.instantiate()
	world_container.add_child(_ghost_building)
	var preview = instance.duplicate(true)
	preview.instance_id = ""
	preview.legacy_entrance = Vector2i(-1, -1)
	_ghost_building.set_building(preview)
	_placement_mode_active = true
	_rebuild_occupancy(instance.instance_id)
	$WorldContainer/Grid.set_placement_grid(true)
	building_popup.hide()
	EventBus.town_notice.emit("Move is free. Click a clear site; right-click/Escape cancels.")
	if touch_mode:
		_ghost_building.position = TownGridGeometry.cell_to_world(Vector2(instance.x, instance.y))
		_check_placement_validity()
	else:
		_update_ghost_position()

func _demolish(instance: BuildingInstance) -> void:
	var definition = DataManager.get_building_definition(instance.def_id)
	if not definition.sellable or definition.type == BuildingDefinition.BuildingType.TOWNHALL:
		return
	var objects = SaveManager.current_save.town_layouts["Vanilla"].starting_objects
	if not objects.has(instance):
		return
	for citizen in SaveManager.current_save.villagers:
		if citizen.assigned_building_instance_id == instance.instance_id:
			WorkerManager.unassign(citizen.villager_id)
	# Refund reserved inputs and transfer stored output before removing the structure.
	var recipe = DataManager.get_production_recipe(definition.gather_recipe_id)
	if instance.cycle_reserved and recipe:
		for resource in recipe.input_cost:
			InventoryManager.add(resource, recipe.input_cost[resource])
	for resource in instance.stored_resources:
		InventoryManager.add(resource, instance.stored_resources[resource])
	for entry in definition.cost.entries:
		InventoryManager.add(entry.resource_id, floorf(entry.amount * DataManager.rules.refund_fraction))
	objects.erase(instance)
	WorkerManager.reconcile_housing()
	EconomyManager._restore_assignments()
	InventoryManager.recalculate_capacity()
	building_popup.hide()
	_refresh_world()
	EventBus.town_notice.emit("Demolished: 50% construction materials refunded. Residents remain in town.")

func _on_visit_friend_requested(friend_name: String) -> void:
	_visiting_friend_name = friend_name
	print("[Main] Visiting town of: %s!" % friend_name)
	
	# Clear player's building nodes
	for child in world_container.get_children():
		child.queue_free()
		
	# Spawn mock structures based on which friend we visit
	# We can use our newly materialized IDs: ID 1 is Town Hall, ID 101 is Cottage, ID 201 is Logging Camp
	var mock_instances = []
	
	# Town Hall (ID 1) at (2, 2)
	var th = BuildingInstance.new()
	th.instance_id = "mock_th"
	th.def_id = 1
	th.x = 2
	th.y = 2
	mock_instances.append(th)
	
	if friend_name == "Alice" or friend_name == "Daisy":
		# Add Cottage and Farms/Special decorations
		var cot = BuildingInstance.new()
		cot.instance_id = "mock_cot1"
		cot.def_id = 10012 # Cottage
		cot.x = 5
		cot.y = 2
		mock_instances.append(cot)
		
		var fountain = BuildingInstance.new()
		fountain.instance_id = "mock_fountain"
		fountain.def_id = 150 # Fountain decoration!
		fountain.x = 8
		fountain.y = 2
		mock_instances.append(fountain)
	else:
		# Bob or Charlie: lumber cutters!
		var camp = BuildingInstance.new()
		camp.instance_id = "mock_camp"
		camp.def_id = 10008 # Logging Camp
		camp.x = 6
		camp.y = 2
		mock_instances.append(camp)
		
	# Instantiate mock buildings
	for instance in mock_instances:
		_create_building_node(instance)
		
	# Show "Return Home" button on UILayer
	if _return_home_btn == null:
		_return_home_btn = Button.new()
		_return_home_btn.text = "Return Home"
		_return_home_btn.custom_minimum_size = Vector2(150, 40)
		_return_home_btn.position = Vector2(20, 20) # Top-left
		_return_home_btn.pressed.connect(func(): EventBus.return_home_requested.emit())
		$UILayer.add_child(_return_home_btn)

func _on_return_home_requested() -> void:
	if _visiting_friend_name == "":
		return
		
	print("[Main] Returning home from visiting %s." % _visiting_friend_name)
	_visiting_friend_name = ""
	
	# Clear mock buildings
	for child in world_container.get_children():
		child.queue_free()
		
	# Reload player's own buildings
	var layout = SaveManager.current_save.town_layouts.get("Vanilla")
	if layout:
		for instance in layout.starting_objects:
			_create_building_node(instance)
			
	# Remove Return Home button
	if _return_home_btn:
		_return_home_btn.queue_free()
		_return_home_btn = null
		
	AudioManager.play_sfx(17) # select chime


func _new_town() -> void:
	if _save_blocked:
		EventBus.town_notice.emit("Recover your unreadable slot 1 files before starting a new town.")
		return
	if SaveManager.archive_current_town() < 0:
		EventBus.town_notice.emit("Could not archive current town. New town cancelled.")
		return
	GameManager.start_new_game()
	get_tree().reload_current_scene()

func _choose_save() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Load a local town"
	dialog.dialog_text = "Unsaved changes are discarded. F9 loads the main slot directly."
	var choices := OptionButton.new()
	var slots := SaveManager.list_slots()
	slots.sort()
	for slot in slots:
		choices.add_item("Slot %d%s" % [slot, " · main town" if slot == 1 else " · archived town"], slot)
	dialog.add_child(choices)
	choices.position = Vector2(16, 80)
	choices.custom_minimum_size = Vector2(300, 32)
	if touch_mode:
		choices.custom_minimum_size.y = 48
		choices.add_theme_font_size_override("font_size", 18)
		choices.get_popup().add_theme_constant_override("v_separation", 24)
		dialog.get_ok_button().custom_minimum_size = Vector2(100, 52)
		dialog.get_cancel_button().custom_minimum_size = Vector2(100, 52)
		dialog.dialog_text = "Load a local town as the active town. Autosave writes it to the main slot."
	dialog.confirmed.connect(func():
		if choices.selected >= 0:
			if GameManager.continue_game(choices.get_selected_id()) != null:
				_save_blocked = false
				get_tree().reload_current_scene()
			else:
				EventBus.town_notice.emit("This slot could not load. Its files were left unchanged.")
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	$UILayer.add_child(dialog)
	dialog.popup_centered(Vector2i(440, 180))

func _create_layout_bar() -> void:
	_layout_bar = HBoxContainer.new()
	_layout_bar.name = "LayoutBar"
	_layout_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_layout_bar.offset_left = -340
	_layout_bar.offset_right = 340
	_layout_bar.offset_top = -90
	_layout_bar.offset_bottom = -55
	$UILayer.add_child(_layout_bar)
	_orientation_label = Label.new()
	_orientation_label.custom_minimum_size.x = 220
	_layout_bar.add_child(_orientation_label)
	for item in [["↶ Shift+R", -1], ["R ↷", 1]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(_rotate_preview.bind(item[1]))
		_layout_bar.add_child(button)
	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.pressed.connect(_place_building)
	_layout_bar.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_cancel_placement)
	_layout_bar.add_child(cancel)
	_position_button = Button.new()
	_position_button.pressed.connect(func():
		_rotation_only = not _rotation_only
		_check_placement_validity()
	)
	_layout_bar.add_child(_position_button)
	_layout_bar.hide()

func _rotate_preview(step: int) -> void:
	if not _ghost_building: return
	var supported := BuildingVisuals.orientations(_building_to_place_def)
	if supported.size() < 2:
		EventBus.town_notice.emit("This building has one verified view; additional directional art is needed.")
		return
	var preview: BuildingInstance = _ghost_building.building_instance
	var index := supported.find(TownGridGeometry.quarter(preview.rotation_degrees) * 90)
	preview.rotation_degrees = supported[posmod(index + step, supported.size())]
	_ghost_building.set_building(preview)
	_check_placement_validity()

func _start_rotate(instance: BuildingInstance, step: int) -> void:
	if BuildingVisuals.orientations(DataManager.get_building_definition(instance.def_id)).size() < 2:
		EventBus.town_notice.emit("Additional directional artwork is needed for this building.")
		return
	_start_move(instance)
	if not _ghost_building: return
	_rotation_only = true
	_ghost_building.position = TownGridGeometry.cell_to_world(Vector2(instance.x, instance.y))
	_rotate_preview(step)

func _create_brush_bar() -> void:
	var launch := Button.new()
	launch.text = "Landscape"
	launch.pressed.connect(func():
		_cancel_placement()
		building_popup.hide()
		build_menu.hide()
		_town_panels.hide()
		_brush_bar.show()
		_select_brush("dirt")
	)
	$UILayer/TownActions.add_child(launch)
	_brush_bar = HBoxContainer.new()
	_brush_bar.name = "BrushBar"
	_brush_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_brush_bar.offset_left = 16
	_brush_bar.offset_top = -90
	_brush_bar.offset_bottom = -55
	$UILayer.add_child(_brush_bar)
	for kind in ["dirt", "flowers", "fence", "erase"]:
		var button := Button.new()
		button.text = "Erase · no refund" if kind == "erase" else GroundDecorations.definitions()[kind].name
		button.pressed.connect(_select_brush.bind(kind))
		_brush_bar.add_child(button)
	_brush_label = Label.new()
	_brush_bar.add_child(_brush_label)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(_cancel_brush)
	_brush_bar.add_child(done)
	_brush_bar.hide()

func _select_brush(kind: String) -> void:
	_brush_kind = kind
	_brush_down = false
	_brush_cells.clear()
	_decor_layer.preview.clear()
	_decor_layer.queue_redraw()
	$WorldContainer/Grid.set_placement_grid(true)
	_brush_label.text = "Drag empty tiles; release applies"
	EventBus.town_notice.emit("Tap tiles, then Confirm · Drag to pan · Cancel discards preview" if touch_mode else "Decorations are cosmetic and never block workers. Erase first to replace a tile.")

func _cancel_brush() -> void:
	_brush_kind = ""
	_brush_down = false
	_brush_cells.clear()
	if is_instance_valid(_brush_bar): _brush_bar.hide()
	if is_instance_valid(_decor_layer):
		_decor_layer.preview.clear()
		_decor_layer.queue_redraw()
	if is_instance_valid(world_container): $WorldContainer/Grid.set_placement_grid(false)

func _brush_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_brush()
		return true
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_brush()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_brush_down = true
			_brush_cells.clear()
			_brush_last = TownGridGeometry.world_to_cell(world_container.to_local(event.position))
			_append_brush(_brush_last)
			return true
	if event is InputEventMouseMotion and _brush_down:
		var cell := TownGridGeometry.world_to_cell(world_container.to_local(event.position))
		var steps := maxi(absi(cell.x - _brush_last.x), absi(cell.y - _brush_last.y))
		for index in range(1, steps + 1):
			_append_brush(Vector2i(Vector2(_brush_last).lerp(Vector2(cell), float(index) / steps).round()))
		_brush_last = cell
		return true
	return false

func _append_brush(cell: Vector2i) -> void:
	if not GroundDecorations.effective_cells(_brush_kind, [cell]).is_empty():
		_brush_cells[cell] = true
	var cost := GroundDecorations.stroke_cost(_brush_kind, _brush_cells.keys())
	var text := "%d tiles" % _brush_cells.size()
	for resource in cost:
		text += " · %d %s" % [cost[resource], DataManager.get_resource_definition(resource).display_name]
	_brush_label.text = text
	_decor_layer.preview = _brush_cells.duplicate()
	_decor_layer.erase_preview = _brush_kind == "erase"
	_decor_layer.preview_valid = GroundDecorations.can_afford(cost)
	_decor_layer.queue_redraw()

func _finish_brush() -> void:
	_brush_down = false
	var okay := GroundDecorations.apply_stroke(_brush_kind, _brush_cells.keys())
	EventBus.town_notice.emit("Landscape applied. Erasing never refunds costs." if okay else "Not enough resources: the entire stroke was cancelled.")
	_brush_cells.clear()
	_decor_layer.preview.clear()
	_decor_layer.queue_redraw()
	_brush_label.text = "Drag another stroke · Escape exits"

# Shared camera and gameplay entry points for touch, mouse, and regression tests.
func zoom_camera(previous_center: Vector2, center: Vector2, factor: float) -> void:
	var beneath: Vector2 = world_container.to_local(previous_center)
	world_container.scale = Vector2.ONE * clampf(world_container.scale.x * factor, 0.4, 2.0)
	world_container.position += center - world_container.to_global(beneath)

func map_tap(point: Vector2, from_touch: bool) -> void:
	if not _brush_kind.is_empty() and from_touch:
		_append_brush(TownGridGeometry.world_to_cell(world_container.to_local(point)))
	elif _placement_mode_active:
		if from_touch:
			if not _rotation_only: _update_ghost_position(point)
		else:
			_place_building()
	else:
		var picked := _pick_building(point)
		if picked: _on_building_instance_selected(picked)

func is_ui_point(point: Vector2) -> bool:
	for child in $UILayer.get_children():
		if _control_hits(child, point): return true
	return false

func _control_hits(node: Node, point: Vector2) -> bool:
	if node is CanvasItem and not node.is_visible_in_tree(): return false
	if node is Control:
		if node.clip_contents and not node.get_global_rect().has_point(point): return false
		if node.mouse_filter == Control.MOUSE_FILTER_STOP and node.get_global_rect().has_point(point): return true
	for child in node.get_children():
		if _control_hits(child, point): return true
	return false
