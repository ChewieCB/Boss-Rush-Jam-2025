extends StaticBody3D
class_name Cover

signal cover_destroyed(cover: Cover)

@export var spawn_sfx: Array[AudioStream]
@export var destroy_sfx: Array[AudioStream]

@export var explosion_vfx: PackedScene
@onready var mesh: MeshInstance3D = $Mesh
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer


func _get_class() -> String:
		return "cover"


func show_cover() -> void:
	var tween = get_tree().create_tween()
	var mesh_size = mesh.get_aabb().size
	self.global_position -= Vector3(0, mesh_size.y, 0)
	if sfx_player.playing:
		await sfx_player.finished
	sfx_player.stream = spawn_sfx.pick_random()
	sfx_player.pitch_scale = randf_range(0.7, 1.2)
	sfx_player.play()
	tween.tween_property(self, "global_position:y", self.global_position.y + mesh_size.y, 3.5)


func destroy() -> void:
	sfx_player.stream = destroy_sfx.pick_random()
	sfx_player.pitch_scale = randf_range(0.7, 1.2)
	sfx_player.play()
	var explosion_inst = explosion_vfx.instantiate()
	get_tree().get_root().add_child(explosion_inst)
	explosion_inst.global_position = mesh.global_position
	get_parent().remove_child(self)
	cover_destroyed.emit(self)
	self.queue_free()
