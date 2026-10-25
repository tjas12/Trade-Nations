extends Node

func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	call_deferred("run")

func run() -> void:
	GameManager.start_new_game()
	SaveManager.current_save.player_state.active_land_size = 48
	SaveManager.current_save.player_state.mayor_level = 16
	for id in [1, 10, 20, 40, 11, 21, 50, 51]: SaveManager.current_save.inventory.resource_amounts[id] = 100000
	for index in range(12):
		var home := BuildingInstance.new()
		home.instance_id = "stress_home_%d" % index
		home.def_id = 14
		home.x = 4 + (index % 6) * 4
		home.y = 4 + (index / 6) * 4
		SaveManager.current_save.town_layouts.Vanilla.starting_objects.append(home)
	WorkerManager.reconcile_housing()
	var producers: Array[BuildingInstance] = []
	for index in range(25):
		var producer := BuildingInstance.new()
		producer.instance_id = "stress_producer_%d" % index
		producer.def_id = [10008, 9, 11, 36, 15, 17, 23][index % 7]
		producer.x = 4 + (index % 7) * 4
		producer.y = 16 + (index / 7) * 5
		SaveManager.current_save.town_layouts.Vanilla.starting_objects.append(producer)
		producers.append(producer)
	for x in range(32):
		for y in range(32): SaveManager.current_save.ground_decorations[Vector2i(x, y)] = ClassicPaths.MATERIALS[posmod(x + y, 3)]
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	for producer in producers:
		WorkerManager.assign_worker(producer)
		WorkerManager.assign_hauler(producer)
	WorkerManager._update_travel(400)
	for frame in range(30): await get_tree().process_frame
	var samples: Array[float] = []
	for frame in range(120):
		await get_tree().process_frame
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
	samples.sort()
	print("[HistoricalPerformanceProbe] " + JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "land": 48, "population": WorkerManager.total_population(), "producers": producers.size(), "path_tiles": 1024, "median_process_ms": samples[60], "p95_process_ms": samples[114], "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}))
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
