extends Node2D
class_name VillagerWalker

var villager_id: String = ""
var role: int = 0
var home_pos: Vector2
var work_pos: Vector2
var _label: Label
var _sprite: Sprite2D

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
	for citizen in SaveManager.current_save.villagers:
		if citizen.villager_id == villager_id:
			visible = citizen.map_position.x >= 0
			position = TownGridGeometry.cell_to_world(citizen.map_position + Vector2(0.5, 0.5))
			z_index = clampi(int(position.y), 0, 4000)
			_label.text = "%s · %s" % [citizen.villager_name, citizen.activity] if get_global_mouse_position().distance_to(global_position) < 55 else citizen.activity.capitalize()
			_sprite.position.y = -14 + (sin(Time.get_ticks_msec() * 0.015) * 2 if citizen.activity == "traveling" else 0)
			return
	queue_free()
