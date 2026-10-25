extends Node

# No wall-clock catch-up: focus/resume only resumes the existing simulation.
var dirty := false
var suspended := false
var _focus_lost := false
var _paused := false
var _elapsed := 0.0
var _quiet := 0.0
var _resume_frame := -10
var writes := 0
var last_result := true
var _visibility_callback: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in ["resource_changed", "building_placed", "worker_assigned", "hauler_assigned", "population_changed", "town_changed", "ground_decorations_changed", "recipe_completed", "xp_changed"]:
		EventBus.connect(key, func(_a = null, _b = null, _c = null): mark_dirty())
	SaveManager.save_activated.connect(mark_dirty)
	if OS.has_feature("web"):
		_visibility_callback = JavaScriptBridge.create_callback(_web_visibility)
		var window := JavaScriptBridge.get_interface("window")
		window.tradeNationsVisibility = _visibility_callback
		JavaScriptBridge.eval("document.addEventListener('visibilitychange',()=>window.tradeNationsVisibility(document.hidden));")

func _web_visibility(arguments: Array) -> void:
	if not arguments.is_empty():
		_notification(NOTIFICATION_APPLICATION_PAUSED if bool(arguments[0]) else NOTIFICATION_APPLICATION_RESUMED)

func mark_dirty() -> void:
	dirty = true
	_quiet = 0.0

func _process(delta: float) -> void:
	if suspended: return
	_elapsed += delta
	_quiet += delta
	# Debounce bursts, but ongoing production cannot postpone writes indefinitely.
	if dirty and ((_quiet >= 1.5 and _elapsed >= 2.0) or _elapsed >= 15.0): flush()
	# Movement/cycle progress also survives interruptions, even without a signal.
	elif _elapsed >= 30.0 and SaveManager.current_save: flush()

func flush() -> bool:
	if SaveManager.current_save == null: return true
	last_result = SaveManager.save_to_slot(1)
	if last_result:
		writes += 1
		dirty = false
		_elapsed = 0.0
	else:
		_elapsed = 0.0 # Avoid hammering failing storage each frame.
		EventBus.town_notice.emit("Autosave failed. Keep the game open and retry Save; previous save retained.")
	return last_result

func simulation_suspended() -> bool:
	return suspended or Engine.get_process_frames() <= _resume_frame + 1

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT: _focus_lost = true
		NOTIFICATION_APPLICATION_FOCUS_IN: _focus_lost = false
		NOTIFICATION_APPLICATION_PAUSED: _paused = true
		NOTIFICATION_APPLICATION_RESUMED: _paused = false
		_: return
	var next := _focus_lost or _paused
	if next == suspended: return
	suspended = next
	if suspended:
		flush()
	else:
		_resume_frame = Engine.get_process_frames()
