# scripts/building.gd
extends Node2D

var building_instance: BuildingInstance
var _harvest_bubble: Panel = null
var _footprint := PackedVector2Array()
var _source_image: Image
var ground_anchor := Vector2.ZERO
var editing_original := false

@onready var color_rect: ColorRect = $ColorRect
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

func _ready() -> void:
	# Picking runs in Main._unhandled_input, after GUI controls consume clicks.
	area_2d.input_pickable = false
	_create_harvest_bubble()

func _create_harvest_bubble() -> void:
	_harvest_bubble = Panel.new()
	_harvest_bubble.name = "HarvestBubble"
	_harvest_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_harvest_bubble.custom_minimum_size = Vector2(40, 40)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.84, 0.0, 0.95) # Gold
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_left = 20
	sb.corner_radius_bottom_right = 20
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	_harvest_bubble.add_theme_stylebox_override("panel", sb)
	
	var label = Label.new()
	label.text = "!"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 22)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	_harvest_bubble.add_child(label)
	add_child(_harvest_bubble)
	_harvest_bubble.visible = false

func _process(delta: float) -> void:
	if not building_instance:
		return
		
	if building_instance.instance_id.is_empty():
		_harvest_bubble.hide()
		return
	if not building_instance.instance_id.is_empty():
		modulate.a = 0.25 if editing_original else (1.0 if building_instance.construction_complete else 0.55)
	# Check if building has any stored resources to display the harvest bubble
	var has_stored = false
	for res_id in building_instance.stored_resources.keys():
		if building_instance.stored_resources[res_id] >= 1.0:
			has_stored = true
			break
			
	if has_stored and building_instance.construction_complete:
		_harvest_bubble.visible = true
		var target_pos = sprite_2d.position - Vector2(20, sprite_2d.texture.get_height() * sprite_2d.scale.y * 0.5 + 44) if sprite_2d.texture else Vector2(-20, -44)
		# Gentle bouncing animation
		target_pos.y += sin(Time.get_ticks_msec() / 150.0) * 6.0
		_harvest_bubble.position = target_pos
	else:
		_harvest_bubble.visible = false

func set_building(instance: BuildingInstance):
	# Resolve child nodes on-demand in case set_building is called before add_child
	if not color_rect: color_rect = $ColorRect
	if not sprite_2d: sprite_2d = $Sprite2D
	if not area_2d: area_2d = $Area2D
	if not collision_shape: collision_shape = $Area2D/CollisionShape2D

	building_instance = instance
	var building_def = DataManager.get_building_definition(instance.def_id)
	if not building_def:
		push_error("Invalid BuildingInstance passed to set_building: def_id %d not found." % instance.def_id)
		return

	name = building_def.display_name
	z_index = clampi(int(TownGridGeometry.cell_to_world(Vector2(instance.x + building_def.width, instance.y + building_def.height)).y), 0, 4000)

	var size := TownGridGeometry.footprint_size(building_def.width, building_def.height, instance.rotation_degrees)
	_footprint = TownGridGeometry.footprint_polygon(size)
	var footprint_width: float = (size.x + size.y) * TownGridGeometry.HALF_WIDTH
	var footprint_height: float = (size.x + size.y) * TownGridGeometry.HALF_HEIGHT
	var center := TownGridGeometry.cell_to_world(Vector2(size) * 0.5)
	var building_size := Vector2(footprint_width, footprint_height)
	rotation = 0.0

	# Configure visuals
	color_rect.hide()
	
	# Configure collision shape for clicks
	var shape = RectangleShape2D.new()
	shape.size = building_size
	collision_shape.shape = shape
	# The collision shape should be centered on the building's visual
	collision_shape.position = center

	# Set color based on building type for visual distinction (default footprint colors)
	match building_def.type:
		BuildingDefinition.BuildingType.TOWNHALL:
			color_rect.color = Color(1.0, 0.84, 0.0, 0.25)
		BuildingDefinition.BuildingType.MINE:
			color_rect.color = Color(0.55, 0.27, 0.07, 0.25)
		BuildingDefinition.BuildingType.HOUSE:
			color_rect.color = Color(0.25, 0.41, 0.88, 0.25)
		_:
			color_rect.color = Color(0.3, 0.3, 0.3, 0.25)

	# Try to load and apply real art asset texture (supporting seasonal skin-swaps)
	if building_def.icon_path != "":
		var texture_path = building_def.icon_path
		
		# Check for active skin overrides (e.g. Winter / Halloween)
		if SaveManager.current_save and SaveManager.current_save.player_state:
			var active_skin = SaveManager.current_save.player_state.active_skin
			if active_skin != "Vanilla":
				var dir_path = building_def.icon_path.get_base_dir() + "/"
				var file_name = building_def.icon_path.get_file()
				var skin_path = dir_path + active_skin.to_upper() + "_" + file_name
				if FileAccess.file_exists(skin_path):
					texture_path = skin_path
					
		var texture = load(texture_path)
		if texture:
			sprite_2d.texture = texture
			_source_image = texture.get_image()
			LegacyArt.apply(sprite_2d)
			ground_anchor = BuildingVisuals.configure(sprite_2d, building_def, instance.rotation_degrees)
			z_index = clampi(int(position.y + ground_anchor.y), 0, 4000)
			sprite_2d.visible = true
		else:
			push_warning("[Building] Failed to load icon texture: %s" % texture_path)
			sprite_2d.visible = false
			color_rect.color.a = 1.0
	else:
		sprite_2d.visible = false
		color_rect.color.a = 1.0
	queue_redraw()

func _draw() -> void:
	if _footprint.is_empty():
		return
	if not building_instance or building_instance.instance_id.is_empty() or not sprite_2d.visible:
		draw_colored_polygon(_footprint, Color(0.7, 0.85, 0.5, 0.35))
	draw_polyline(PackedVector2Array([_footprint[0], _footprint[1], _footprint[2], _footprint[3], _footprint[0]]), Color(0.8, 0.9, 0.65, 0.45), 1.0)

func contains_screen_point(point: Vector2) -> bool:
	if sprite_2d.visible and _source_image != null:
		var rect := sprite_2d.get_rect()
		var local := sprite_2d.to_local(point)
		if rect.has_point(local):
			var uv := (local - rect.position) / rect.size
			if sprite_2d.flip_h:
				uv.x = 1.0 - uv.x
			# The draw shader flips the legacy texture vertically.
			var px := clampi(int(uv.x * _source_image.get_width()), 0, _source_image.get_width() - 1)
			var py := clampi(int((1.0 - uv.y) * _source_image.get_height()), 0, _source_image.get_height() - 1)
			if _source_image.get_pixel(px, py).a > 0.1:
				return true
	return Geometry2D.is_point_in_polygon(to_local(point), _footprint)
