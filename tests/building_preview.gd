extends Node

var _index := 0
var _definitions: Array
var _page: Node2D
var _title: Label
var _degrees := 0

func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	GameManager.start_new_game()
	_definitions = DataManager.get_all_building_definitions()
	_definitions.sort_custom(func(a, b): return a.id < b.id)
	_title = Label.new()
	_title.position = Vector2(20, 12)
	add_child(_title)
	for item in [["Previous", -1], ["Next", 1]]:
		var button := Button.new()
		button.text = item[0]
		button.position = Vector2(880 if item[1] == -1 else 1000, 12)
		button.pressed.connect(func():
			_index = posmod(_index + item[1], _definitions.size())
			_degrees = 0
			show_page()
		)
		add_child(button)
	var turn := Button.new()
	turn.text = "Change facing"
	turn.position = Vector2(20, 50)
	turn.pressed.connect(func():
		var views := BuildingVisuals.orientations(_definitions[_index])
		_degrees = views[posmod(views.find(_degrees) + 1, views.size())]
		show_page()
	)
	add_child(turn)
	show_page()

func show_page() -> void:
	if _page:
		remove_child(_page)
		_page.queue_free()
	_page = Node2D.new()
	add_child(_page)
	_title.text = "Developer scale audit · %d definitions · page %d · common 64×32 grid / 23px villager" % [_definitions.size(), _index + 1]
	for slot in range(1):
		if _index + slot >= _definitions.size(): break
		var definition: BuildingDefinition = _definitions[_index + slot]
		var footprint_size := TownGridGeometry.footprint_size(definition.width, definition.height, _degrees)
		var origin := Vector2(576, 150)
		var reference := Node2D.new()
		reference.position = origin
		reference.scale = Vector2.ONE * 0.7
		_page.add_child(reference)
		var footprint := Polygon2D.new()
		footprint.polygon = TownGridGeometry.footprint_polygon(footprint_size)
		footprint.color = Color(0.4, 0.6, 0.3, 0.5)
		reference.add_child(footprint)
		for x in range(footprint_size.x + 1):
			var line := Line2D.new()
			line.width = 1
			line.default_color = Color(0.7, 0.85, 0.5, 0.3)
			line.points = PackedVector2Array([TownGridGeometry.cell_to_world(Vector2(x, 0)), TownGridGeometry.cell_to_world(Vector2(x, footprint_size.y))])
			reference.add_child(line)
		for y in range(footprint_size.y + 1):
			var line := Line2D.new()
			line.width = 1
			line.default_color = Color(0.7, 0.85, 0.5, 0.3)
			line.points = PackedVector2Array([TownGridGeometry.cell_to_world(Vector2(0, y)), TownGridGeometry.cell_to_world(Vector2(footprint_size.x, y))])
			reference.add_child(line)
		var building = load("res://scenes/building.tscn").instantiate()
		var instance := BuildingInstance.new()
		instance.instance_id = "preview"
		instance.def_id = definition.id
		instance.rotation_degrees = _degrees
		reference.add_child(building)
		building.set_building(instance)
		var villager := Sprite2D.new()
		villager.texture = load("res://assets/art/converted/VILLAGERPORTRAITSMALL.png")
		villager.scale = Vector2.ONE * (23.0 / villager.texture.get_height())
		villager.position = Vector2(-100, 30)
		LegacyArt.apply(villager)
		reference.add_child(villager)
		var label := Label.new()
		label.position = Vector2(20, 580)
		label.text = "%d · %s\n%d×%d · %s" % [definition.id, definition.display_name, definition.width, definition.height, "ART UNMAPPED" if definition.icon_path.is_empty() else definition.icon_path.get_file()]
		label.text += "\n" + BuildingVisuals.facing_label(definition, _degrees)
		label.add_theme_font_size_override("font_size", 12)
		_page.add_child(label)
