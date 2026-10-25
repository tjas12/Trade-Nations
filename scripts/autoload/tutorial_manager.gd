extends Node

var _tutorial_popup = null
var _timer: float = 0

func _ready() -> void:
	SaveManager.save_activated.connect(func(): call_deferred("refresh"))

func set_tutorial_popup(popup) -> void:
	_tutorial_popup = popup
	refresh()

func start_tutorials() -> void:
	refresh()

func _process(delta: float) -> void:
	_timer += delta
	if _timer > 0.25:
		_timer = 0
		refresh()

func satisfied(objective: Dictionary) -> bool:
	var save = SaveManager.current_save
	match objective.kind:
		"building":
			var count := 0
			for instance in save.town_layouts["Vanilla"].starting_objects:
				if instance.def_id == int(objective.target) and instance.construction_complete:
					count += 1
			return count >= int(objective.count)
		"population": return save.villagers.size() >= int(objective.count)
		"logging_staff":
			for instance in save.town_layouts["Vanilla"].starting_objects:
				if instance.def_id in [8, 10008] and not instance.assigned_worker_ids.is_empty() and not instance.assigned_hauler_ids.is_empty():
					return true
		"produced", "sold": return save.economy_stats[objective.kind].get(int(objective.target), 0) >= objective.count
		"expansion": return save.expansion_count >= int(objective.count)
	return false

func refresh() -> void:
	if not SaveManager.current_save or DataManager.rules.is_empty():
		return
	var save = SaveManager.current_save
	var objectives: Array = DataManager.rules.objectives
	for index in range(objectives.size()):
		var objective: Dictionary = objectives[index]
		if save.objective_claims.has(objective.id):
			continue
		if satisfied(objective):
			# Claim first, then reward, including when several objectives complete together.
			save.objective_claims.append(objective.id)
			InventoryManager.add(1, objective.gold)
			ProgressionManager.add_xp(objective.xp)
			EventBus.town_notice.emit("Objective complete: +%d Gold, +%d XP" % [objective.gold, objective.xp])
			continue
		if is_instance_valid(_tutorial_popup):
			_tutorial_popup.show_objective("%d/%d · %s\nReward: %d Gold + %d XP" % [index + 1, objectives.size(), objective.text, objective.gold, objective.xp])
		return
	if is_instance_valid(_tutorial_popup):
		_tutorial_popup.show_objective("Town established! Build more homes and production, sell goods, and shape your town.")
