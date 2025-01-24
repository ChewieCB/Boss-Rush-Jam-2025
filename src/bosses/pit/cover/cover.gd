extends StaticBody3D
class_name Cover

signal cover_destroyed(cover: Cover)

@export var explosion_vfx: PackedScene
@onready var mesh: MeshInstance3D = $Mesh


func show_cover() -> void:
	var tween = get_tree().create_tween()
	var mesh_size = mesh.get_aabb().size
	self.global_position -= Vector3(0, mesh_size.y, 0)
	tween.tween_property(self, "global_position:y", self.global_position.y + mesh_size.y, 3.5)


func destroy() -> void:
	var explosion_inst = explosion_vfx.instantiate()
	get_tree().get_root().add_child(explosion_inst)
	explosion_inst.global_position = mesh.global_position
	get_parent().remove_child(self)
	cover_destroyed.emit(self)
	self.queue_free()
