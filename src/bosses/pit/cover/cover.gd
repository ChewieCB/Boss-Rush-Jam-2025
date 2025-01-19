extends StaticBody3D
class_name Cover

signal cover_destroyed

@export var explosion_vfx: PackedScene
@onready var mesh: MeshInstance3D = $Mesh


func destroy() -> void:
	var explosion_inst = explosion_vfx.instantiate()
	get_tree().get_root().add_child(explosion_inst)
	explosion_inst.global_position = mesh.global_position
	get_parent().remove_child(self)
	cover_destroyed.emit()
	self.queue_free()
