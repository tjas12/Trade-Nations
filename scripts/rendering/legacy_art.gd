class_name LegacyArt
extends RefCounted

static var _material: ShaderMaterial

static func apply(item: CanvasItem) -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://scripts/rendering/legacy_art.gdshader")
	item.material = _material
