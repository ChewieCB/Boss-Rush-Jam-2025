extends Node3D
class_name CoverSpawnPoint


@export var cover_scenes: Array[PackedScene]


func _ready() -> void:
	var cover = cover_scenes.pick_random()
	var cover_instance = cover.instantiate()
	get_tree().get_root().add_child(cover_instance)
	cover_instance.global_position = self.global_position
	cover_instance.rotation.y = self.rotation.y
