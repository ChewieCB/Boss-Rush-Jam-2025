extends Node3D
class_name CoverSpawnPoint


@export var cover_scenes: Array[PackedScene]


func _ready() -> void:
	var cover = cover_scenes.pick_random()
	var cover_instance = cover.instantiate()
	add_child(cover_instance)
	cover_instance.rotation.y = randf_range(0, 2*PI) #self.rotation.y
	
	var tween = get_tree().create_tween()
	var mesh_size = cover_instance.mesh.get_aabb().size
	cover_instance.global_position = self.global_position - Vector3(0, mesh_size.y, 0)
	tween.tween_property(cover_instance, "global_position:y", self.global_position.y, 3.5)
