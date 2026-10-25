extends Node2D
class_name VillagerWalker

var villager_id: String = ""
var role: int = 0
var home_pos: Vector2
var work_pos: Vector2
var _label: Label
var _sprite: Sprite2D
var _citizen: Villager
var _source_save: Resource
static var _hover_until := 0
static var _hover_parent := 0
static var _nearest_id := ""

func configure(id: String, _name: String, v_role: int, home: Vector2, work: Vector2) -> void:
	villager_id = id
	role = v_role
	home_pos = home
	work_pos = work

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/art/converted/VILLAGERPORTRAITSMALL.png")
	_sprite.scale = Vector2.ONE * (23.0 / _sprite.texture.get_height())
	_sprite.position.y = -14
	LegacyArt.apply(_sprite)
	add_child(_sprite)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(-35, -40)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _process(_delta: float) -> void:
	if not SaveManager.current_save: return
	if _source_save != SaveManager.current_save or _citizen == null:
		_source_save = SaveManager.current_save
		_citizen = EconomyManager._find_villager_by_id(villager_id)
	if _citizen == null:
		queue_free()
		return
	visible = _citizen.map_position.x >= 0
	position = TownGridGeometry.cell_to_world(_citizen.map_position + Vector2(0.5, 0.5))
	z_index = clampi(int(position.y), 0, 4000)
	_refresh_hover()
	_label.visible = _nearest_id == villager_id
	if _label.visible: _label.text = "%s · %s" % [_citizen.villager_name, _citizen.activity]
	_sprite.position.y = -14 + (sin(Time.get_ticks_msec() * 0.015) * 2 if _citizen.activity == "traveling" else 0)

func _refresh_hover() -> void:
	var now := Time.get_ticks_msec()
	var parent_id := get_parent().get_instance_id()
	if now < _hover_until and _hover_parent == parent_id: return
	_hover_parent = parent_id
	_hover_until = now + 100
	_nearest_id = ""
	if get_parent().get_parent().get("touch_mode") == true: return
	var mouse := get_global_mouse_position()
	var nearest_distance := 45.0
	for other in get_parent().get_children():
		if not other is VillagerWalker or not other.visible: continue
		var distance: float = mouse.distance_to(other.global_position)
		if distance < nearest_distance or (is_equal_approx(distance, nearest_distance) and other.villager_id < _nearest_id):
			nearest_distance = distance
			_nearest_id = other.villager_id
