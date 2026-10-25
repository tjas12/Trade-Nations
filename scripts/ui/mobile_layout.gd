extends Node

var game: Node
var goals_open := false
var _toolbar_scroll: ScrollContainer
var _hud_flow: HFlowContainer
var _market_scroll: ScrollContainer
var _perf: Label
var _perf_time := 0.0
var safe_rect := Rect2()
var force_mobile := false

func _ready() -> void:
	get_viewport().size_changed.connect(refresh)
	game.build_menu.visibility_changed.connect(func(): call_deferred("refresh"))
	game.building_popup.visibility_changed.connect(_details_changed)
	call_deferred("refresh")

func _details_changed() -> void:
	refresh()
	if not game.touch_mode or not game.building_popup.visible: return
	var instance: BuildingInstance = game.building_popup.building_instance
	if not instance: return
	var point: Vector2 = game.world_container.to_global(TownGridGeometry.cell_to_world(Vector2(instance.x + 1, instance.y + 1)))
	var free := Rect2(safe_rect.position + Vector2(12, 140), Vector2(game.building_popup.position.x - safe_rect.position.x - 24, safe_rect.size.y - 210))
	if not free.has_point(point): game._pan_camera(free.get_center() - point)

func refresh() -> void:
	if not game.touch_mode and not force_mobile: return
	game.touch_mode = true
	var viewport := get_viewport().get_visible_rect()
	safe_rect = viewport.grow(-8)
	if OS.has_feature("ios") or OS.has_feature("android"):
		var display_safe := Rect2(DisplayServer.get_display_safe_area())
		var pixels := Vector2(DisplayServer.window_get_size())
		if pixels.x > 0 and display_safe.has_area():
			safe_rect = Rect2(display_safe.position / pixels * viewport.size, display_safe.size / pixels * viewport.size).intersection(viewport).grow(-8)
	elif OS.has_feature("web"):
		# Safari reports CSS safe-area insets; viewport units can be scaled by Godot.
		var insets = JavaScriptBridge.eval("[getComputedStyle(document.documentElement).getPropertyValue('--safe-left'),getComputedStyle(document.documentElement).getPropertyValue('--safe-top'),getComputedStyle(document.documentElement).getPropertyValue('--safe-right'),getComputedStyle(document.documentElement).getPropertyValue('--safe-bottom')].map(parseFloat).join(',')")
		if insets is String:
			var v: PackedStringArray = insets.split(",")
			var css_width = JavaScriptBridge.eval("window.innerWidth")
			if v.size() == 4 and float(css_width) > 0:
				var ratio: float = viewport.size.x / float(css_width)
				safe_rect.position += Vector2(float(v[0]), float(v[1])) * ratio
				safe_rect.size -= Vector2(float(v[0]) + float(v[2]), float(v[1]) + float(v[3])) * ratio
	_setup()
	var x := safe_rect.position.x
	var y := safe_rect.position.y
	var w := safe_rect.size.x
	var h := safe_rect.size.y
	_rect(game.get_node("UILayer/ResourceHud"), Rect2(x, y, w, 64))
	_rect(_toolbar_scroll, Rect2(x, y + 66, w, 54))
	game._feedback.position = Vector2(x + 4, y + 122)
	game._feedback.size = Vector2(w - 8, 26)
	game._feedback.clip_text = true
	game._feedback.add_theme_font_size_override("font_size", 16)
	var bottom := y + h - 54
	_rect(game.get_node("UILayer/ToggleBuildMenuButton"), Rect2(x + w * 0.5 - 70, bottom, 140, 52))
	var panel_w := minf(430, w * 0.46)
	game.building_popup.custom_minimum_size = Vector2(288, 0)
	_rect(game.building_popup, Rect2(x + w - panel_w, y + 66, panel_w, h - 126))
	var header: Control = game.building_popup.name_label.get_parent()
	_rect(header, Rect2(10, 4, panel_w - 20, 48))
	_rect(game.building_popup.tabs, Rect2(8, 55, panel_w - 16, 46))
	game.building_popup.tabs.add_theme_constant_override("h_separation", 4)
	game.building_popup.get_node("ContentScroll").offset_top = 106
	game.building_popup.get_node("ContentScroll/VBoxContainer").add_theme_constant_override("separation", 10)
	var catalog_w := minf(720, w * 0.72)
	_rect(game.build_menu, Rect2(x + w - catalog_w, y + 66, catalog_w, h - 126))
	game.build_menu.tab_container.offset_top = 58
	game.build_menu.tab_container.get_tab_bar().custom_minimum_size.y = 48
	for scroll in game.build_menu.tab_container.get_children():
		var grid: GridContainer = scroll.get_child(0)
		grid.columns = maxi(1, int((catalog_w - 36) / 244))
	game._orientation_label.hide()
	game._layout_bar.get_child(1).text = "Rotate ↶"
	game._layout_bar.get_child(2).text = "Rotate ↷"
	_rect(game._layout_bar, Rect2(x, bottom - 56, w, 52))
	game._layout_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_rect(game._brush_bar, Rect2(x, bottom - 56, w, 52))
	game._brush_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	game._brush_label.hide()
	_rect(game.tutorial_popup, Rect2(x, y + 152, minf(350, w * 0.43), 130))
	var modal_w := minf(w - 24, 650)
	_rect(game._town_panels, Rect2(x + (w - modal_w) * 0.5, y + 124, modal_w, h - 180))
	_rect(_market_scroll, Rect2(12, 8, modal_w - 24, h - 252))
	for box in [game._town_panels.market_box, game._town_panels.expansion_box]:
		box.custom_minimum_size.x = modal_w - 48
		box.add_theme_constant_override("separation", 10)
	var close: Button = game._town_panels.get_child(game._town_panels.get_child_count() - 1)
	_rect(close, Rect2(modal_w * 0.5 - 60, h - 240, 120, 52))
	_size_controls(game.get_node("UILayer"))
	game._feedback.text = "Drag: pan · Pinch: zoom · Tap a site, then Confirm · Toolbar scrolls sideways"

func _setup() -> void:
	if is_instance_valid(_toolbar_scroll): return
	var layer := game.get_node("UILayer")
	_toolbar_scroll = ScrollContainer.new()
	_toolbar_scroll.name = "MobileToolbar"
	_toolbar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(_toolbar_scroll)
	var toolbar: Control = layer.get_node("TownActions")
	toolbar.reparent(_toolbar_scroll)
	toolbar.position = Vector2.ZERO
	toolbar.add_theme_constant_override("separation", 10)
	var goals := Button.new()
	goals.text = "Goals"
	goals.pressed.connect(func(): goals_open = not goals_open)
	toolbar.add_child(goals)
	if OS.is_debug_build():
		var performance_button := Button.new()
		performance_button.text = "Perf"
		performance_button.pressed.connect(func(): game._debug_tools.visible = not game._debug_tools.visible)
		toolbar.add_child(performance_button)
	var hud: Control = layer.get_node("ResourceHud/HBoxContainer")
	_hud_flow = HFlowContainer.new()
	_hud_flow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_flow.add_theme_constant_override("h_separation", 16)
	hud.get_parent().add_child(_hud_flow)
	for child in hud.get_children(): child.reparent(_hud_flow)
	hud.hide()
	# Draw drawers above the right side of the toolbar, leaving more scroll space.
	layer.move_child(game.build_menu, layer.get_child_count() - 1)
	layer.move_child(game.building_popup, layer.get_child_count() - 1)
	# Touch landscape painting is a sequence of tile taps, committed by its button.
	var apply := Button.new()
	apply.text = "Confirm"
	apply.pressed.connect(game._finish_brush)
	game._brush_bar.add_child(apply)
	game._brush_bar.get_child(5).text = "Cancel"
	_market_scroll = ScrollContainer.new()
	_market_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var modal: Control = game._town_panels
	modal.add_child(_market_scroll)
	modal.move_child(_market_scroll, 0) # Close remains the last child for desktop API compatibility.
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_scroll.add_child(contents)
	for box in [modal.market_box, modal.expansion_box]: box.reparent(contents)
	for row in modal.market_box.get_children():
		if not row is HBoxContainer: continue
		row.get_child(0).custom_minimum_size.x = 170
		row.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.get_child(0).add_theme_font_size_override("font_size", 16)
		var quantity: SpinBox = row.get_child(1)
		quantity.editable = false
		quantity.custom_minimum_size.x = 72
		for amount in [-1, 1]:
			var button := Button.new()
			button.text = "−" if amount < 0 else "+"
			button.pressed.connect(func(): quantity.value += amount)
			row.add_child(button)

func _size_controls(node: Node) -> void:
	if node is BaseButton:
		node.custom_minimum_size.y = maxf(48, node.custom_minimum_size.y)
		node.custom_minimum_size.x = maxf(48, node.custom_minimum_size.x)
		node.add_theme_font_size_override("font_size", 18)
	if node is Label: node.add_theme_font_size_override("font_size", 18)
	if node is AcceptDialog:
		node.get_ok_button().custom_minimum_size = Vector2(100, 52)
		node.get_label().add_theme_font_size_override("font_size", 18)
		if node is ConfirmationDialog: node.get_cancel_button().custom_minimum_size = Vector2(100, 52)
	if node is OptionButton:
		node.get_popup().add_theme_font_size_override("font_size", 18)
		node.get_popup().add_theme_constant_override("v_separation", 24)
	for child in node.get_children(): _size_controls(child)

func _rect(control: Control, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size

func _process(delta: float) -> void:
	# Development builds only; F3 shares the existing developer toolbar.
	if not OS.is_debug_build(): return
	if not is_instance_valid(_perf):
		_perf = Label.new()
		_perf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game._debug_tools.add_child(_perf)
	_perf_time += delta
	if _perf_time >= 0.5 and game._debug_tools.visible:
		_perf_time = 0
		_perf.text = "%d FPS · %.1f ms · %d draws · %.0f MB" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]
