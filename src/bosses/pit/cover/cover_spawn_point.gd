@tool
extends Node3D
class_name CoverSpawnPoint

@export var cover_scenes: Dictionary
@export var cover_spawn_weights: Dictionary

@export var entProperties: Dictionary = {
	"cover_type": "",
}

var cover_type: String


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
		var chance: float = randf()
		for weight in cover_spawn_weights.values():
			sum_of_weight += weight
		for cover_type in cover_spawn_weights:
			var spawn_weight = cover_spawn_weights[cover_type]
			if chance < spawn_weight:
				cover = cover_scenes[cover_type]
				break
			chance -= spawn_weight

	var cover_instance = cover.instantiate()
	add_child(cover_instance)
	cover_instance.rotation.y = randf_range(0, 2*PI) #self.rotation.y
	
	var tween = get_tree().create_tween()
	var mesh_size = cover_instance.mesh.get_aabb().size
	cover_instance.global_position = self.global_position - Vector3(0, mesh_size.y, 0)
	tween.tween_property(cover_instance, "global_position:y", self.global_position.y, 3.5)
	
	return cover_instance
	
