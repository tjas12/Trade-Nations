extends Node

var game: Node
var roadmap: Panel
var notice: Panel
var notice_levels: Array = []

func _ready() -> void:
	ProgressionManager.advanced.connect(_celebrate)
	SaveManager.save_activated.connect(func():
		if is_instance_valid(notice): notice.hide()
		if is_instance_valid(roadmap): roadmap.hide()
		notice_levels.clear()
	)
	get_viewport().size_changed.connect(_layout)
	var button := Button.new()
	button.text = "Levels"
	button.pressed.connect(open_roadmap)
	game.get_node("UILayer/TownActions").add_child(button)

func _bounds() -> Rect2:
	if game.touch_mode and game.mobile_ui.safe_rect.has_area(): return game.mobile_ui.safe_rect
	return get_viewport().get_visible_rect().grow(-12)

func _style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("463b25")
	style.border_color = Color("ba9b58")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	game.get_node("UILayer").add_child(panel)

func _label(text: String, parent: Node, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _item(definition: BuildingDefinition, parent: Node, caption: String = "") -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(76, 64)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	if ResourceLoader.exists(definition.icon_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(definition.icon_path)
		var ground := BuildingVisuals.configure(sprite, definition)
		var factor := minf(1, 70.0 / (BuildingVisuals.visible_bounds(sprite.texture).size.x * sprite.scale.x))
		sprite.scale *= factor
		sprite.position = (sprite.position - ground) * factor + Vector2(38, 60)
		icon.add_child(sprite)
	var unlocked := ProgressionManager.unlocked(definition)
	var text := "%s %s · %s" % ["✓" if unlocked else "🔒", definition.display_name, definition.category]
	if not caption.is_empty(): text = caption
	elif unlocked:
		var reason := HistoricalGameplay.build_reason(definition)
		if not reason.is_empty(): text += "\n" + reason
	var label := _label(text, row)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _contents(panel: Panel) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_top = 10
	scroll.offset_right = -12
	scroll.offset_bottom = -56
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 8)
	scroll.add_child(contents)
	var close := Button.new()
	close.text = "Continue building"
	close.custom_minimum_size = Vector2(180, 44)
	close.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	close.position = Vector2(-192, -50)
	close.size = Vector2(180, 44)
	close.pressed.connect(panel.hide)
	panel.add_child(close)
	return contents

func open_roadmap() -> void:
	if is_instance_valid(roadmap): roadmap.free()
	roadmap = Panel.new()
	_style(roadmap)
	var contents := _contents(roadmap)
	var state = SaveManager.current_save.player_state
	_label("Your nation · Level %d / 50" % state.mayor_level, contents, 20)
	var next: float = ProgressionManager.XP_THRESHOLDS.get(state.mayor_level, INF)
	_label("XP %d / %s" % [state.xp_total, "MAX" if is_inf(next) else str(int(next))], contents)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 20
	bar.max_value = next if not is_inf(next) else 1
	bar.value = state.xp_total if not is_inf(next) else 1
	contents.add_child(bar)
	for level in range(1, 51):
		var data: Dictionary = ProgressionManager.registry.levels[level - 1]
		_label("%s Level %d · %s" % ["✓" if level <= state.mayor_level else "🔒", level, "Reached" if level <= state.mayor_level else "Earn XP through building and production"], contents, 18)
		_label(data.benefit, contents)
		for definition in ProgressionManager.entries_at(level): _item(definition, contents)
		for entry in ProgressionManager.recipes_at(level):
			var definition = DataManager.get_building_definition(int(entry.building))
			_item(definition, contents, "%s Recipe: %s · %s" % ["✓" if level <= state.mayor_level else "🔒", entry.name, definition.display_name])
	_layout()

func _celebrate(levels: Array) -> void:
	if is_instance_valid(notice): notice.free()
	notice_levels.append_array(levels)
	notice = Panel.new()
	_style(notice)
	var contents := _contents(notice)
	_label("Level %d reached!" % levels.back(), contents, 20)
	_label("Town allowances and new jobs. Tap Levels for the roadmap.", contents)
	for level in notice_levels:
		for definition in ProgressionManager.entries_at(level): _item(definition, contents)
		for entry in ProgressionManager.recipes_at(level): _item(DataManager.get_building_definition(int(entry.building)), contents, "New recipe: " + entry.name)
	notice.visibility_changed.connect(func():
		if not notice.visible: notice_levels.clear()
	)
	_layout()

func _layout() -> void:
	var bounds := _bounds()
	if is_instance_valid(roadmap):
		var top: float = game.mobile_ui._header_height + 4 if game.touch_mode else 78
		roadmap.position = bounds.position + Vector2(maxf(0, bounds.size.x - 560), top)
		roadmap.size = Vector2(minf(bounds.size.x, 560), bounds.size.y - top)
	if is_instance_valid(notice):
		notice.position = bounds.position + Vector2(0, maxf(125, bounds.size.y - 244))
		notice.size = Vector2(minf(310, bounds.size.x * 0.44), minf(190, bounds.size.y - 132))
