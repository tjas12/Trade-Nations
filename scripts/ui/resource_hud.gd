# scripts/ui/resource_hud.gd
extends Panel

@onready var gold_label: Label = $HBoxContainer/GoldLabel
@onready var wood_label: Label = $HBoxContainer/WoodLabel
@onready var wheat_label: Label = $HBoxContainer/WheatLabel
@onready var level_label: Label = $HBoxContainer/LevelLabel
@onready var xp_label: Label = $HBoxContainer/XPLabel

# Map resource IDs to their UI labels
var _resource_labels: Dictionary = {}
var population_label: Label
var compact := false

func set_compact(enabled: bool) -> void:
	compact = enabled
	_initialize_display()

func _ready() -> void:
	population_label = Label.new()
	population_label.name = "PopulationLabel"
	$HBoxContainer.add_child(population_label)
	EventBus.population_changed.connect(_on_population_changed)
	# Resource IDs are defined in their .tres files
	# Gold = 1, Wood = 10, Wheat = 40
	_resource_labels[1] = gold_label
	_resource_labels[10] = wood_label
	_resource_labels[40] = wheat_label
	var cookies := Label.new()
	$HBoxContainer.add_child(cookies)
	_resource_labels[90040] = cookies
	
	call_deferred("_initialize_display")
	
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.level_up.connect(_on_level_up)
	EventBus.xp_changed.connect(_on_xp_changed)

func _initialize_display() -> void:
	_on_population_changed(WorkerManager.total_population(), WorkerManager.idle_villagers().size())
	# Init resource labels
	for res_id in _resource_labels:
		var amount = InventoryManager.amount(res_id)
		_update_label(res_id, amount)
		
	# Init progression labels
	if SaveManager.current_save and SaveManager.current_save.player_state:
		var player_state = SaveManager.current_save.player_state
		_on_level_up(player_state.mayor_level)
		_on_xp_changed(player_state.xp_total)

func _on_resource_changed(resource_id: int, new_amount: float) -> void:
	_update_label(resource_id, new_amount)

func _update_label(resource_id: int, amount: float) -> void:
	if _resource_labels.has(resource_id):
		var label = _resource_labels[resource_id]
		var resource_def = DataManager.get_resource_definition(resource_id)
		if resource_def:
			label.text = ("%s %d" if compact else "%s: %d") % [resource_def.display_name, floor(amount)]

func _on_level_up(new_level: int) -> void:
	level_label.text = ("Lvl %d" if compact else "Level: %d") % new_level
	# Also update XP label since the threshold changes
	if SaveManager.current_save and SaveManager.current_save.player_state:
		_on_xp_changed(SaveManager.current_save.player_state.xp_total)

func _on_xp_changed(new_xp: float) -> void:
	if SaveManager.current_save and SaveManager.current_save.player_state:
		var current_level = SaveManager.current_save.player_state.mayor_level
		var xp_for_next_level = ProgressionManager.XP_THRESHOLDS.get(current_level, INF)
		xp_label.text = ("XP %d/%s" if compact else "XP: %d/%s") % [floor(new_xp), str(xp_for_next_level) if xp_for_next_level != INF else "---"]

func _on_population_changed(total: int, idle: int) -> void:
	population_label.text = ("Pop %d/%d · Jobs %d · Free %d" if compact else "People: %d/%d · Jobs: %d · Free: %d") % [total, WorkerManager.housing_capacity(), total - idle, idle]
