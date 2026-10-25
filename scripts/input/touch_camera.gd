class_name TouchCamera
extends RefCounted

# A gesture owns only fingers that began on the map. UI fingers never join it.
var points: Dictionary = {}
var start := Vector2.ZERO
var dragged := false
var multitouch := false
const TAP_SLOP := 12.0

func reset() -> void:
	points.clear()
	dragged = false
	multitouch = false

func handle(event: InputEvent, game: Node) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			if game.is_ui_point(event.position): return false
			if points.is_empty():
				start = event.position
				dragged = false
				multitouch = false
			points[event.index] = event.position
			if points.size() > 1: multitouch = true
			return true
		if not points.has(event.index): return false
		points.erase(event.index)
		if points.is_empty():
			if not event.canceled and not dragged and not multitouch and start.distance_to(event.position) < TAP_SLOP:
				game.map_tap(event.position, true)
		return true
	if event is InputEventScreenDrag and points.has(event.index):
		var old: Vector2 = points[event.index]
		if points.size() > 2:
			points[event.index] = event.position
			return true
		if points.size() == 2:
			var ids := points.keys()
			var a: Vector2 = points[ids[0]]
			var b: Vector2 = points[ids[1]]
			var before := (a + b) * 0.5
			var distance := a.distance_to(b)
			points[event.index] = event.position
			a = points[ids[0]]
			b = points[ids[1]]
			if distance > 4.0:
				game.zoom_camera(before, (a + b) * 0.5, a.distance_to(b) / distance)
		else:
			points[event.index] = event.position
			if start.distance_to(event.position) >= TAP_SLOP: dragged = true
			if dragged: game._pan_camera(event.position - old)
		return true
	return false
