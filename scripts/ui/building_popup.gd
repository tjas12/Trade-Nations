extends Panel

var building_instance: BuildingInstance
var release_button: Button
var production_label: Label
var progress: ProgressBar
var staff_choice: OptionButton
var release_one: Button
var tabs: TabBar
var orientation_label: Label
var rotate_row: HBoxContainer
var move_button: Button
var demolish_button: Button
var staff_summary: Label
var _refresh_timer := 0.0
var upgrade_choice: OptionButton
var upgrade_button: Button
var tax_button: Button
var _upgrade_confirmation: ConfirmationDialog
var recipe_choice: OptionButton

@onready var name_label: Label = $ContentScroll/VBoxContainer/BuildingNameLabel
@onready var building_icon: TextureRect = $ContentScroll/VBoxContainer/BuildingIcon
@onready var storage_label: Label = $ContentScroll/VBoxContainer/StoredResourcesLabel
@onready var workers_label: Label = $ContentScroll/VBoxContainer/AssignedWorkersLabel
@onready var assign_worker_button: Button = $ContentScroll/VBoxContainer/AssignWorkerButton
@onready var assign_hauler_button: Button = $ContentScroll/VBoxContainer/AssignHaulerButton
@onready var close_button: Button = $CloseButton

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.11, 0.96)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var header := HBoxContainer.new()
	header.position = Vector2(10, 8)
	header.size = Vector2(266, 30)
	add_child(header)
	name_label.reparent(header)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	close_button.reparent(header)
	close_button.pressed.connect(hide)
	tabs = TabBar.new()
	tabs.position = Vector2(10, 45)
	tabs.size = Vector2(266, 28)
	for section in ["Overview", "Workers", "Layout"]: tabs.add_tab(section)
	tabs.tab_changed.connect(func(_index): _update_display())
	add_child(tabs)
	assign_worker_button.pressed.connect(_on_assign_worker_pressed)
	assign_hauler_button.pressed.connect(_on_assign_hauler_pressed)
	upgrade_choice = OptionButton.new()
	$ContentScroll/VBoxContainer.add_child(upgrade_choice)
	_upgrade_confirmation = ConfirmationDialog.new()
	_upgrade_confirmation.title = "Upgrade this building?"
	_upgrade_confirmation.get_ok_button().custom_minimum_size = Vector2(100, 48)
	_upgrade_confirmation.get_cancel_button().custom_minimum_size = Vector2(100, 48)
	_upgrade_confirmation.confirmed.connect(func():
		var message := HistoricalGameplay.begin_upgrade(building_instance, int(upgrade_choice.get_selected_metadata()))
		EventBus.town_notice.emit(message)
		_update_display()
	)
	add_child(_upgrade_confirmation)
	upgrade_button = _button("Upgrade…", func():
		var target = DataManager.get_building_definition(int(upgrade_choice.get_selected_metadata()))
		var costs := ""
		for entry in target.cost.entries: costs += "%d %s · " % [entry.amount, DataManager.get_resource_definition(entry.resource_id).display_name]
		_upgrade_confirmation.dialog_text = "Upgrade to %s\n%s\nResidents and jobs stay. Housing upgrades keep their current footprint.\nFull listed construction cost is charged." % [target.display_name, costs]
		_upgrade_confirmation.popup_centered(Vector2i(560, 240))
	)
	tax_button = _button("Collect taxes", func():
		var gold := HistoricalGameplay.collect_tax(building_instance)
		EventBus.town_notice.emit("Collected %d Gold in taxes." % gold)
		_update_display()
	)
	recipe_choice = OptionButton.new()
	$ContentScroll/VBoxContainer.add_child(recipe_choice)
	recipe_choice.item_selected.connect(func(index):
		EventBus.town_notice.emit(HistoricalGameplay.choose_recipe(building_instance, int(recipe_choice.get_item_metadata(index))))
		_update_display()
	)
	production_label = _label()
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 18
	$ContentScroll/VBoxContainer.add_child(progress)
	staff_summary = _label()
	staff_choice = OptionButton.new()
	$ContentScroll/VBoxContainer.add_child(staff_choice)
	release_one = _button("Unassign selected citizen", func():
		if staff_choice.selected >= 0:
			WorkerManager.unassign(staff_choice.get_item_metadata(staff_choice.selected))
			_refresh_staff_choices()
	)
	release_button = _button("Release all staff", _release_staff)
	orientation_label = _label()
	rotate_row = HBoxContainer.new()
	$ContentScroll/VBoxContainer.add_child(rotate_row)
	for item in [["↶ Preview turn", -1], ["Preview turn ↷", 1]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(func(): EventBus.building_rotate_requested.emit(building_instance, item[1]))
		rotate_row.add_child(button)
	move_button = _button("Move · free preview", func(): EventBus.building_move_requested.emit(building_instance))
	var confirmation := ConfirmationDialog.new()
	confirmation.title = "Demolish building?"
	confirmation.dialog_text = "Refund: 50% of configured costs, rounded down.\nReserved inputs and stored output return up to capacity.\nStaff become free. Residents stay and may lose housing."
	confirmation.confirmed.connect(func(): EventBus.building_demolish_requested.emit(building_instance))
	add_child(confirmation)
	demolish_button = _button("Demolish… · 50% refund", func(): confirmation.popup_centered())
	SaveManager.save_activated.connect(hide)
	EventBus.town_changed.connect(func():
		if visible and building_instance: show_for_building(building_instance)
	)
	EventBus.population_changed.connect(func(_total, _idle):
		if visible:
			_refresh_staff_choices()
			_update_display()
	)
	hide()

func _label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$ContentScroll/VBoxContainer.add_child(label)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	$ContentScroll/VBoxContainer.add_child(button)
	return button

func show_for_building(instance: BuildingInstance) -> void:
	building_instance = instance
	if not instance: return
	tabs.current_tab = 0
	recipe_choice.clear()
	var definition = DataManager.get_building_definition(instance.def_id)
	for id in definition.shop_recipe_ids:
		var option = DataManager.get_production_recipe(id)
		recipe_choice.add_item("%s · L%d" % [option.display_name, HistoricalGameplay.recipe_level(id)])
		recipe_choice.set_item_metadata(recipe_choice.item_count - 1, id)
		recipe_choice.set_item_disabled(recipe_choice.item_count - 1, SaveManager.current_save.player_state.mayor_level < HistoricalGameplay.recipe_level(id) and instance.active_recipe_id != id)
	var current_recipe = EconomyManager.recipe_for(instance)
	for index in range(recipe_choice.item_count):
		if current_recipe and int(recipe_choice.get_item_metadata(index)) == (instance.queued_recipe_id if instance.queued_recipe_id >= 0 else current_recipe.id): recipe_choice.select(index)
	upgrade_choice.clear()
	for target_id in HistoricalGameplay.upgrade_targets(instance):
		var target = DataManager.get_building_definition(target_id)
		upgrade_choice.add_item("%s · Level %d" % [target.display_name, target.playable_level])
		upgrade_choice.set_item_metadata(upgrade_choice.item_count - 1, target_id)
	show()
	_refresh_staff_choices()
	_update_display()

func _update_display() -> void:
	if not building_instance or not visible: return
	var definition = DataManager.get_building_definition(building_instance.def_id)
	var recipe = EconomyManager.recipe_for(building_instance)
	recipe_choice.visible = tabs.current_tab == 0 and recipe_choice.item_count > 0
	upgrade_choice.visible = tabs.current_tab == 0 and upgrade_choice.item_count > 0
	upgrade_button.visible = upgrade_choice.visible
	upgrade_button.disabled = building_instance.pending_upgrade_id >= 0 or not building_instance.construction_complete
	tax_button.visible = tabs.current_tab == 0 and not HistoricalGameplay.profile(building_instance.def_id).get("tax", {}).is_empty()
	tax_button.disabled = building_instance.tax_gold <= 0
	tax_button.text = "Collect %d Gold tax" % building_instance.tax_gold if building_instance.tax_gold > 0 else "Taxes accruing · Collect when ready"
	if tax_button.visible and building_instance.tax_gold <= 0:
		var tax: Dictionary = HistoricalGameplay.profile(building_instance.def_id).tax
		var minutes := ceili(maxf(0, float(tax.seconds) - building_instance.tax_elapsed) / 60)
		tax_button.text = "%d Gold tax · %dh %dm remaining" % [tax.reward.get("1", 0), minutes / 60, minutes % 60]
	var overview := tabs.current_tab == 0
	var people := tabs.current_tab == 1
	var layout := tabs.current_tab == 2
	name_label.text = definition.display_name
	name_label.tooltip_text = definition.display_name
	building_icon.hide()
	storage_label.visible = overview and recipe != null
	workers_label.visible = overview
	production_label.visible = overview
	progress.visible = overview and (recipe != null or not building_instance.construction_complete)
	staff_summary.visible = people
	for control in [staff_choice, release_one, release_button]: control.visible = people and recipe != null
	for control in [orientation_label, rotate_row, move_button, demolish_button]: control.visible = layout
	assign_worker_button.visible = (overview or people) and recipe != null
	assign_hauler_button.visible = (overview or people) and recipe != null and recipe.hauler_max > 0
	var idle := WorkerManager.idle_villagers().size()
	var names: Array[String] = []
	var residents := 0
	for citizen in SaveManager.current_save.villagers:
		if citizen.home_instance_id == building_instance.instance_id: residents += 1
		if citizen.assigned_building_instance_id == building_instance.instance_id:
			names.append("%s · %s" % [citizen.villager_name, citizen.activity])
	staff_summary.text = "Available in town: %d\n%s" % [idle, "\n".join(names)]
	if definition.house_capacity > 0:
		workers_label.text = "Residents: %d/%d · Free in town: %d" % [residents, WorkerManager.capacity_for(building_instance), idle]
		staff_summary.text = "Residents: %d/%d\nAvailable in town: %d" % [residents, WorkerManager.capacity_for(building_instance), idle]
	if recipe:
		workers_label.text = "Workers %d/%d · Haulers %d/%d\nAvailable: %d" % [building_instance.assigned_worker_ids.size(), recipe.worker_max, building_instance.assigned_hauler_ids.size(), recipe.hauler_max, idle]
		assign_worker_button.disabled = idle == 0 or not building_instance.construction_complete or building_instance.assigned_worker_ids.size() >= recipe.worker_max
		assign_hauler_button.disabled = idle == 0 or not building_instance.construction_complete or building_instance.assigned_hauler_ids.size() >= recipe.hauler_max
		var output = DataManager.get_resource_definition(recipe.output_resource_id)
		storage_label.text = "Stock: %d %s" % [InventoryManager.amount(output.id) if recipe.kind == ProductionRecipe.RecipeKind.CRAFT else building_instance.stored_resources.get(output.id, 0), output.display_name]
		var inputs := "Gather"
		if not recipe.input_cost.is_empty():
			inputs = ""
			for resource in recipe.input_cost: inputs += "%d %s " % [recipe.input_cost[resource], DataManager.get_resource_definition(resource).display_name]
		var reason := EconomyManager.pause_reason(building_instance)
		production_label.text = "%s → %d %s / %ds\n%s" % [inputs, recipe.cycle_amount, output.display_name, recipe.cycle_seconds, reason if not reason.is_empty() else "%ds remaining" % ceili(recipe.cycle_seconds - building_instance.cycle_elapsed)]
		if building_instance.queued_recipe_id >= 0: production_label.text += "\nNext: " + DataManager.get_production_recipe(building_instance.queued_recipe_id).display_name
		progress.max_value = maxf(1, recipe.cycle_seconds)
		progress.value = building_instance.cycle_elapsed
	else:
		production_label.text = "Housing capacity: %d" % WorkerManager.capacity_for(building_instance) if definition.house_capacity else definition.info_text
	if building_instance.pending_upgrade_id >= 0:
		var target = DataManager.get_building_definition(building_instance.pending_upgrade_id)
		production_label.text = "Upgrading to %s: %ds left. Residents remain housed." % [target.display_name, ceili(target.build_time_seconds - building_instance.upgrade_elapsed)]
		progress.visible = overview
		progress.max_value = maxf(1, target.build_time_seconds)
		progress.value = building_instance.upgrade_elapsed
	if not building_instance.construction_complete:
		production_label.text = "Construction: %ds remaining" % ceili(definition.build_time_seconds - building_instance.construction_elapsed)
		progress.max_value = maxf(1, definition.build_time_seconds)
		progress.value = building_instance.construction_elapsed
	orientation_label.text = "%s\n%d supported view(s) · Confirm/Cancel in layout bar" % [BuildingVisuals.facing_label(definition, building_instance.rotation_degrees), BuildingVisuals.orientations(definition).size()]
	if building_instance.legacy_entrance.x >= 0:
		orientation_label.text += "\nLegacy entrance retained; editing validates new access."
	for button in rotate_row.get_children(): button.disabled = BuildingVisuals.orientations(definition).size() < 2
	move_button.disabled = definition.type == BuildingDefinition.BuildingType.TOWNHALL
	demolish_button.disabled = not definition.sellable or building_instance.pending_upgrade_id >= 0

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer > 0.2:
		_refresh_timer = 0
		_update_display()

func _refresh_staff_choices() -> void:
	staff_choice.clear()
	if not building_instance: return
	for citizen in SaveManager.current_save.villagers:
		if citizen.assigned_building_instance_id == building_instance.instance_id:
			staff_choice.add_item(citizen.villager_name)
			staff_choice.set_item_metadata(staff_choice.item_count - 1, citizen.villager_id)
	release_one.disabled = staff_choice.item_count == 0
	release_button.disabled = staff_choice.item_count == 0

func _on_assign_worker_pressed() -> void:
	if building_instance: WorkerManager.assign_worker(building_instance)

func _on_assign_hauler_pressed() -> void:
	if building_instance: WorkerManager.assign_hauler(building_instance)

func _release_staff() -> void:
	if not building_instance: return
	for id in building_instance.assigned_worker_ids.duplicate() + building_instance.assigned_hauler_ids.duplicate(): WorkerManager.unassign(id)
	_refresh_staff_choices()
	_update_display()
