# scripts/ui/building_popup.gd
extends Panel

var building_instance: BuildingInstance
var release_button: Button
var production_label: Label
var progress: ProgressBar
var staff_choice: OptionButton
var release_one: Button
var _refresh_timer := 0.0

@onready var name_label: Label = $ContentScroll/VBoxContainer/BuildingNameLabel
@onready var building_icon: TextureRect = $ContentScroll/VBoxContainer/BuildingIcon
@onready var storage_label: Label = $ContentScroll/VBoxContainer/StoredResourcesLabel
@onready var workers_label: Label = $ContentScroll/VBoxContainer/AssignedWorkersLabel
@onready var assign_worker_button: Button = $ContentScroll/VBoxContainer/AssignWorkerButton
@onready var assign_hauler_button: Button = $ContentScroll/VBoxContainer/AssignHaulerButton
@onready var close_button: Button = $CloseButton

func _ready() -> void:
	assign_worker_button.pressed.connect(_on_assign_worker_pressed)
	assign_hauler_button.pressed.connect(_on_assign_hauler_pressed)
	close_button.pressed.connect(_on_close_pressed)
	release_button = Button.new()
	release_button.text = "Release staff for another job"
	release_button.pressed.connect(_release_staff)
	$ContentScroll/VBoxContainer.add_child(release_button)
	
	production_label = Label.new()
	production_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	production_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$ContentScroll/VBoxContainer.add_child(production_label)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 16
	$ContentScroll/VBoxContainer.add_child(progress)
	staff_choice = OptionButton.new()
	$ContentScroll/VBoxContainer.add_child(staff_choice)
	release_one = Button.new()
	release_one.text = "Unassign selected citizen"
	release_one.pressed.connect(func():
		if staff_choice.selected >= 0:
			WorkerManager.unassign(staff_choice.get_item_metadata(staff_choice.selected))
			_refresh_staff_choices()
	)
	$ContentScroll/VBoxContainer.add_child(release_one)
	var move := Button.new()
	move.text = "Move · free"
	move.pressed.connect(func(): EventBus.building_move_requested.emit(building_instance))
	$ContentScroll/VBoxContainer.add_child(move)
	var confirmation := ConfirmationDialog.new()
	confirmation.title = "Demolish building?"
	confirmation.dialog_text = "Refund: 50% of building costs (rounded down).\nReserved inputs and stored output return up to storage capacity.\nStaff become available; residents stay and may be homeless."
	confirmation.confirmed.connect(func(): EventBus.building_demolish_requested.emit(building_instance))
	add_child(confirmation)
	var demolish := Button.new()
	demolish.text = "Demolish… · 50% refund"
	demolish.pressed.connect(func():
		if DataManager.get_building_definition(building_instance.def_id).sellable:
			confirmation.popup_centered()
		else:
			EventBus.town_notice.emit("Town Hall cannot be demolished.")
	)
	$ContentScroll/VBoxContainer.add_child(demolish)
	EventBus.population_changed.connect(func(_total, _idle): _update_display())
	EventBus.building_storage_changed.connect(_on_building_storage_changed)
	EventBus.worker_assigned.connect(_on_worker_or_hauler_assigned)
	EventBus.hauler_assigned.connect(_on_worker_or_hauler_assigned)
	
	hide()

func show_for_building(instance: BuildingInstance) -> void:
	building_instance = instance
	if not building_instance:
		push_error("[BuildingPopup] show_for_building called with null instance.")
		hide()
		return
		
	show()
	_update_display()
	_refresh_staff_choices()

func _update_display() -> void:
	if not building_instance or not is_visible():
		return

	var building_def = DataManager.get_building_definition(building_instance.def_id)
	if not building_def:
		push_error("[BuildingPopup] Could not find definition for instance.")
		hide()
		return

	name_label.text = building_def.display_name
	
	# Set building icon
	if building_def.icon_path != "":
		var texture = load(building_def.icon_path)
		if texture:
			building_icon.texture = texture
			LegacyArt.apply(building_icon)
			building_icon.show()
		else:
			building_icon.hide()
	else:
		building_icon.hide()
	
	_refresh_production()
	var has_gather_recipe = building_def.gather_recipe_id != -1
	staff_choice.visible = has_gather_recipe
	release_one.visible = has_gather_recipe
	if not has_gather_recipe:
		storage_label.hide()
		workers_label.hide()
		assign_worker_button.hide()
		assign_hauler_button.hide()
		release_button.hide()
		if building_def.house_capacity > 0:
			var residents := 0
			for citizen in SaveManager.current_save.villagers:
				if citizen.home_instance_id == building_instance.instance_id:
					residents += 1
			workers_label.text = "Residents: %d/%d\nIdle citizens: %d" % [residents, building_def.house_capacity, WorkerManager.idle_villagers().size()]
			workers_label.show()
		return
	
	storage_label.show()
	workers_label.show()
	assign_worker_button.show()
	assign_hauler_button.show()
	release_button.show()
	
	var recipe = DataManager.get_production_recipe(building_def.gather_recipe_id)
	
	# Update storage label
	var output_res_id = recipe.output_resource_id
	var output_res_def = DataManager.get_resource_definition(output_res_id)
	var current_stored = building_instance.stored_resources.get(output_res_id, 0.0)
	storage_label.text = "Storage: %d / %d %s" % [floor(current_stored), recipe.max_output_stack_size, output_res_def.display_name]
	if recipe.kind == ProductionRecipe.RecipeKind.CRAFT:
		storage_label.text = "Town stock: %d %s" % [InventoryManager.amount(output_res_id), output_res_def.display_name]
	assign_hauler_button.visible = recipe.hauler_max > 0
	
	# Update workers label
	var worker_names = _get_villager_names(building_instance.assigned_worker_ids)
	var hauler_names = _get_villager_names(building_instance.assigned_hauler_ids)
	workers_label.text = "Workers (%d/%d): %s\nHaulers (%d/%d): %s" % [
		worker_names.size(), recipe.worker_max, ", ".join(worker_names),
		hauler_names.size(), recipe.hauler_max, ", ".join(hauler_names)
	]

	var idle_count := WorkerManager.idle_villagers().size()
	workers_label.text += "\nIdle citizens: %d | Housing: %d/%d" % [idle_count, WorkerManager.total_population(), WorkerManager.housing_capacity()]
	assign_worker_button.disabled = worker_names.size() >= recipe.worker_max or idle_count == 0 or not building_instance.construction_complete
	assign_hauler_button.disabled = hauler_names.size() >= recipe.hauler_max or idle_count == 0 or not building_instance.construction_complete
	release_button.disabled = worker_names.is_empty() and hauler_names.is_empty()

func _get_villager_names(villager_ids: Array) -> Array:
	var names = []
	if not SaveManager.current_save: return names
	
	for villager in SaveManager.current_save.villagers:
		if villager.villager_id in villager_ids:
			names.append(villager.villager_name)
	return names

# --- Signal Handlers ---

func _on_assign_worker_pressed() -> void:
	if building_instance:
		WorkerManager.assign_worker(building_instance)
		_refresh_staff_choices()

func _on_assign_hauler_pressed() -> void:
	if building_instance:
		WorkerManager.assign_hauler(building_instance)
		_refresh_staff_choices()

func _on_close_pressed() -> void:
	hide()

func _on_building_storage_changed(instance_id: String, resource_id: int, new_amount: float) -> void:
	if building_instance and building_instance.instance_id == instance_id:
		_update_display()

func _on_worker_or_hauler_assigned(villager: Villager, instance: BuildingInstance) -> void:
	if building_instance and building_instance.instance_id == instance.instance_id:
		_update_display()

func _release_staff() -> void:
	if building_instance == null:
		return
	var staff = building_instance.assigned_worker_ids.duplicate() + building_instance.assigned_hauler_ids.duplicate()
	for villager_id in staff:
		WorkerManager.unassign(villager_id)
	_update_display()

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer > 0.2:
		_refresh_timer = 0
		_update_display()

func _refresh_staff_choices() -> void:
	staff_choice.clear()
	if not building_instance:
		return
	for citizen in SaveManager.current_save.villagers:
		if citizen.assigned_building_instance_id == building_instance.instance_id:
			staff_choice.add_item(citizen.villager_name)
			staff_choice.set_item_metadata(staff_choice.item_count - 1, citizen.villager_id)
	release_one.disabled = staff_choice.item_count == 0

func _refresh_production() -> void:
	var definition = DataManager.get_building_definition(building_instance.def_id)
	var recipe = DataManager.get_production_recipe(definition.gather_recipe_id)
	progress.visible = recipe != null or not building_instance.construction_complete
	if not building_instance.construction_complete:
		progress.max_value = definition.build_time_seconds
		progress.value = building_instance.construction_elapsed
		production_label.text = "Construction: %ds remaining" % ceili(definition.build_time_seconds - building_instance.construction_elapsed)
	elif recipe:
		progress.max_value = maxf(1, recipe.cycle_seconds)
		progress.value = building_instance.cycle_elapsed
		var inputs := ""
		for resource in recipe.input_cost:
			inputs += "%d %s " % [recipe.input_cost[resource], DataManager.get_resource_definition(resource).display_name]
		var reason := EconomyManager.pause_reason(building_instance)
		production_label.text = "%s → %d %s / %ds\n%s" % [inputs if not inputs.is_empty() else "Gather", recipe.cycle_amount, DataManager.get_resource_definition(recipe.output_resource_id).display_name, recipe.cycle_seconds, reason if not reason.is_empty() else "%ds remaining" % ceili(recipe.cycle_seconds - building_instance.cycle_elapsed)]
	else:
		production_label.text = "Provides housing" if definition.house_capacity > 0 else definition.info_text
