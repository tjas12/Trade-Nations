extends Node

func _ready() -> void:
	get_window().size = Vector2i(1152, 648)
	call_deferred("run")

func run() -> void:
	GameManager.start_new_game()
	SaveManager.current_save.player_state.active_land_size = 48
	if "--path-stress" in OS.get_cmdline_user_args():
		for x in range(32):
			for y in range(32):
				SaveManager.current_save.ground_decorations[Vector2i(x, y)] = ClassicPaths.MATERIALS[posmod(x + y, 3)]
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	for frame in range(30): await get_tree().process_frame
	var samples: Array[float] = []
	for frame in range(120):
		await get_tree().process_frame
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
	samples.sort()
	print("[PerformanceProbe] " + JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "land": 48, "median_process_ms": samples[60], "p95_process_ms": samples[114], "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}))
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
