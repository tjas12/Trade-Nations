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

func _initialize_save() -> void:
	if SaveManager.current_save == null:
		if GameManager.continue_game(1) == null:
			_save_blocked = FileAccess.file_exists("user://saves/slot_1.tres") or FileAccess.file_exists("user://saves/slot_1.backup.tres")
			GameManager.start_new_game()

func _ready() -> void:
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
	var save_button := Button.new()
	save_button.text = "Save (F5)"
	if _save_blocked:
		save_button.text = "Save blocked: recover slot 1 first"
	save_button.position = Vector2(20, 65)
	save_button.pressed.connect(_save_town)
	$UILayer.add_child(save_button)
	var load_button := Button.new()
	load_button.text = "Load (F9)"
	load_button.position = Vector2(130, 65)
	load_button.pressed.connect(_load_town)
	$UILayer.add_child(load_button)
	_restore_walkers()
	_add_town_controls()

func _add_town_controls() -> void:
	var toolbar := HBoxContainer.new()
	toolbar.name = "TownActions"
	toolbar.position = Vector2(245, 65)
	$UILayer.add_child(toolbar)
	var collect := Button.new()
	collect.text = "Collect resources"
	collect.pressed.connect(_collect_resources)
	toolbar.add_child(collect)
	var sell := Button.new()
	sell.text = "Sell 1 Wood"
	sell.pressed.connect(func():
		var sold := SocialManager.sell_to_market(10, 1)
		_feedback.text = "Sold 1 Wood at the local market price." if sold else "Collect at least 1 Wood first."
	)
	toolbar.add_child(sell)
	var food := Button.new()
	food.text = "Buy 1 Wheat"
	food.pressed.connect(func():
		var bought := SocialManager.buy_from_market(40, 1)
		_feedback.text = "Bought 1 Wheat for villagers at the local market price." if bought else "Need more Gold or Wheat storage. Sell Wood to earn Gold."
	)
	toolbar.add_child(food)
	var speed := Button.new()
	speed.text = "Time: 1x"
	speed.pressed.connect(func():
		EconomyManager.simulation_speed = 60.0 if EconomyManager.simulation_speed == 1.0 else (360.0 if EconomyManager.simulation_speed == 60.0 else 1.0)
		speed.text = "Time: %dx" % EconomyManager.simulation_speed
		_feedback.text = "Prototype production speed. Hunger still uses real time; buy Wheat to feed staff."
	)
	toolbar.add_child(speed)
	var center := Button.new()
	center.name = "CenterTown"
	center.text = "Center town"
	center.tooltip_text = "Return to your buildings and reset zoom (Home)."
	center.pressed.connect(_center_town)
	toolbar.add_child(center)
	var grid := Button.new()
	grid.name = "ToggleGrid"
	grid.text = "Grid: Off"
	grid.pressed.connect(func():
		grid.text = "Grid: On" if $WorldContainer/Grid.toggle_grid() else "Grid: Off"
	)
	toolbar.add_child(grid)
	_feedback = Label.new()
	_feedback.position = Vector2(20, 110)
	_feedback.text = "Drag empty ground or use WASD/arrows to pan | Wheel: zoom | Home: center town | Grid appears when building."
	$UILayer.add_child(_feedback)
	var close_menu := Button.new()
	close_menu.text = "Close build menu"
	close_menu.position = Vector2(get_viewport().get_visible_rect().size.x - 180, 40)
	close_menu.pressed.connect(build_menu.hide)
	build_menu.add_child(close_menu)

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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_stop_pan()
		_camera_keys.clear()

func _input(event: InputEvent) -> void:
	# Once a ground drag starts, track it across UI and always see its release.
	if event is InputEventMouseButton and event.button_index == _pan_button and not event.pressed:
		var dragged := _panning
		_stop_pan()
		if dragged:
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
			if _placement_mode_active:
				_update_ghost_position(event.position)
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
	if build_menu.visible or building_popup.visible:
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
	if _save_blocked:
		msg.text = "Existing saves could not load. Copy them aside before recovery; saving is blocked."
	else:
		msg.text = "Town saved." if SaveManager.save_to_slot(1) else "Save failed. Previous save retained."
	$UILayer.add_child(msg)

func _load_town() -> void:
	if GameManager.continue_game(1) != null:
		get_tree().reload_current_scene()

func _restore_walkers() -> void:
	for villager in SaveManager.current_save.villagers:
		for instance in SaveManager.current_save.town_layouts["Vanilla"].starting_objects:
			if villager.assigned_building_instance_id == instance.instance_id:
				_on_worker_or_hauler_assigned(villager, instance, int(villager.role))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			_begin_pan(event)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var mouse: Vector2 = event.position
			var local: Vector2 = world_container.to_local(mouse)
			var factor := 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			world_container.scale = Vector2.ONE * clampf(world_container.scale.x * factor, 0.4, 2.0)
			world_container.position += mouse - world_container.to_global(local)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not _placement_mode_active:
			building_popup.hide()
			build_menu.hide()
			tutorial_popup.hide()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F5:
			_save_town()
		elif event.keycode == KEY_F9:
			_load_town()
	if not _placement_mode_active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var picked = _pick_building(event.position)
			if picked:
				_on_building_instance_selected(picked)
				get_viewport().set_input_as_handled()
			else:
				_begin_pan(event)
		return

	if event is InputEventMouseMotion:
		_update_ghost_position(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_place_building()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_placement()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancel_placement()
		elif event.keycode == KEY_R:
			if _ghost_building:
				var preview = _ghost_building.building_instance
				preview.rotation_degrees = fmod(preview.rotation_degrees + 90, 360)
				_ghost_building.set_building(preview)
				_check_placement_validity()

func _pick_building(point: Vector2) -> BuildingInstance:
	var candidates: Array[Node] = []
	for child in world_container.get_children():
		if child != _ghost_building and child.has_method("contains_screen_point") and not child.is_queued_for_deletion():
			candidates.append(child)
	candidates.sort_custom(func(a, b): return a.position.y > b.position.y)
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
		_update_ghost_position()

func _update_ghost_position(mouse_pos: Vector2 = Vector2.INF) -> void:
	if mouse_pos == Vector2.INF:
		mouse_pos = get_viewport().get_mouse_position()
	var world_pos = world_container.get_global_transform().affine_inverse() * mouse_pos

	var cell := TownGridGeometry.world_to_cell(world_pos)
	_ghost_building.position = TownGridGeometry.cell_to_world(Vector2(cell))
	_check_placement_validity()

func _check_placement_validity() -> bool:
	if not _ghost_building: return false

	var grid_pos := TownGridGeometry.world_to_cell(_ghost_building.position)
	var building_def = _building_to_place_def
	
	var width = building_def.width
	var height = building_def.height
	if fmod(_ghost_building.building_instance.rotation_degrees, 180) != 0:
		width = building_def.height
		height = building_def.width

	var land_size = 48
	if SaveManager.current_save and SaveManager.current_save.player_state:
		land_size = SaveManager.current_save.player_state.active_land_size

	for x in range(width):
		for y in range(height):
			var cell_to_check = grid_pos + Vector2i(x, y)
			# Boundary limits check
			if cell_to_check.x < 0 or cell_to_check.y < 0 or cell_to_check.x >= land_size or cell_to_check.y >= land_size:
				_ghost_building.modulate = Color(1.0, 0.5, 0.5, 0.7)
				return false
			# Overlapping checks
			if _occupied_coords.has(cell_to_check):
				_ghost_building.modulate = Color(1.0, 0.5, 0.5, 0.7)
				return false
	
	_ghost_building.modulate = Color(0.5, 1.0, 0.5, 0.7)
	return true

func _place_building() -> void:
	if _placement_mode_active and _check_placement_validity():
		if _building_to_place_def:
			var grid_pos := TownGridGeometry.world_to_cell(_ghost_building.position)
			# Affordability can change while the preview is open.
			if not EconomyManager.can_afford(_building_to_place_def.cost):
				return
			
			var new_instance = BuildingInstance.new()
			new_instance.instance_id = str(_next_instance_id)
			_next_instance_id += 1
			new_instance.def_id = _building_to_place_def.id
			new_instance.x = grid_pos.x
			new_instance.y = grid_pos.y
			new_instance.rotation_degrees = _ghost_building.building_instance.rotation_degrees
			
			SaveManager.current_save.town_layouts["Vanilla"].starting_objects.append(new_instance)
			
			_create_building_node(new_instance)
			
			_add_building_to_occupied_grid(grid_pos, _building_to_place_def, new_instance.rotation_degrees)
			
			EconomyManager.apply_cost(_building_to_place_def.cost)
			
			print("[Main] Placed building: %s (ID: %s)" % [_building_to_place_def.display_name, new_instance.instance_id])
			
			EventBus.building_placed.emit(new_instance)
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
	_placement_mode_active = false
	$WorldContainer/Grid.set_placement_grid(false)
	_building_to_place_def = null

func _add_building_to_occupied_grid(grid_pos: Vector2i, building_def: BuildingDefinition, rotation_degrees: float = 0.0) -> void:
	var width = building_def.width
	var height = building_def.height
	if fmod(rotation_degrees, 180) != 0:
		width = building_def.height
		height = building_def.width
		
	for x in range(width):
		for y in range(height):
			_occupied_coords[grid_pos + Vector2i(x, y)] = true

# --- Signal Handlers ---

func _on_toggle_build_menu_pressed() -> void:
	build_menu.visible = not build_menu.visible
	if build_menu.visible:
		building_popup.hide()
		tutorial_popup.hide()
		build_menu.populate_build_menu()

func _on_building_instance_selected(instance: BuildingInstance) -> void:
	building_popup.show_for_building(instance)

func _on_spawn_floating_text(text: String, global_pos: Vector2, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.position = global_pos
	
	# Add beautiful contrast outlining so the numbers are highly visible over grass/terrain
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 20)
	
	world_container.add_child(label)
	
	# Animate float & fade cleanly using Godot 4.7 tweens
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", global_pos.y - 65.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(label.queue_free)

func _on_worker_or_hauler_assigned(villager: Villager, instance: BuildingInstance, role_type: int) -> void:
	for child in world_container.get_children():
		if child is VillagerWalker and child.villager_id == villager.villager_id:
			child.queue_free()
	# Use the assigned residence, with Town Hall as a fallback.
	var home_pos = TownGridGeometry.cell_to_world(Vector2(2.5, 2.5))
	var work_def = DataManager.get_building_definition(instance.def_id)
	var work_size := TownGridGeometry.footprint_size(work_def.width, work_def.height, instance.rotation_degrees)
	var work_pos = TownGridGeometry.cell_to_world(Vector2(instance.x, instance.y) + Vector2(work_size) * 0.5)
	
	if SaveManager.current_save:
		var layout = SaveManager.current_save.town_layouts.get("Vanilla")
		if layout:
			for obj in layout.starting_objects:
				var def = DataManager.get_building_definition(obj.def_id)
				if def and obj.instance_id == villager.home_instance_id:
					home_pos = TownGridGeometry.cell_to_world(Vector2(obj.x + def.width * 0.5, obj.y + def.height * 0.5))
					break
					
	# Instantiate villager walker
	var walker = VillagerWalker.new()
	walker.home_pos = home_pos
	walker.work_pos = work_pos
	walker.configure(villager.villager_id, villager.villager_name, role_type, home_pos, work_pos)
	
	# Add to world container so it's drawn on map
	world_container.add_child(walker)

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

