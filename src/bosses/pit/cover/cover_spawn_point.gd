@tool
extends Node3D
class_name CoverSpawnPoint

@export var cover_scenes: Dictionary
@export var cover_spawn_weights: Dictionary

@export var entProperties: Dictionary = {
	"cover_type": "",
}

var cover_type: String
var current_cover: Cover


func _func_godot_apply_properties(properties: Dictionary) -> void:
	entProperties = properties


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	cover_type = entProperties["cover_type"]


func spawn_cover() -> Cover:
	var cover: PackedScene
	if cover_type:
		cover = cover_scenes[cover_type]
	else:
		var sum_of_weight: float = 0.0
		for weight in cover_spawn_weights.values():
			sum_of_weight += weight
		var chance: float = randf_range(0, sum_of_weight)
		for _cover_type in cover_spawn_weights:
			var spawn_weight = cover_spawn_weights[_cover_type]
			if chance < spawn_weight:
				cover = cover_scenes[_cover_type]
				break
			chance -= spawn_weight

	var cover_instance = cover.instantiate()
	add_child(cover_instance)
	cover_instance.rotation.y = randf_range(0, 2*PI) #self.rotation.y
	
	current_cover = cover_instance
	
	return cover_instance
