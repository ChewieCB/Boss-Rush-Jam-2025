extends Node3D

signal path_finished

@export var _pathfollow: PathFollow3D
@export var path_mesh: MeshInstance3D
@export var _anim_player: AnimationPlayer
var projectile: BaseBullet


func vary_mesh_visuals() -> void:
	var _mat: ShaderMaterial = path_mesh.get_surface_override_material(0)
	var colour_var = _mat.get_shader_parameter("ring_color")
	colour_var += Color(  
		randf_range(-0.1, 0.1),
		randf_range(-0.1, 0.1),
		randf_range(-0.1, 0.1)
	)
	_mat.set_shader_parameter("ring_color", colour_var)
	var freq_var: float = _mat.get_shader_parameter("ring_frequency")
	freq_var += randf_range(-5.0, 5.0)
	_mat.set_shader_parameter("ring_frequency", freq_var)
	path_mesh.set_surface_override_material(0, _mat)
	print()


func add_to_path(obj: Node3D) -> void:
	if is_instance_valid(obj.get_parent()):
		obj.get_parent().remove_child(obj)
	_pathfollow.add_child(obj)
	obj.position = Vector3.ZERO
	path_finished.connect(
		func():
			obj.queue_free()
	)	

func unpack_pathfollow() -> PathFollow3D:
	self.remove_child(_pathfollow)
	return _pathfollow

func _repack_pathfollow() -> void:
	if is_instance_valid(_pathfollow.get_parent()):
		_pathfollow.get_parent().remove_child(_pathfollow)
	self.add_child(_pathfollow)


func start_path() -> void:
	_anim_player.play("ammo_leech_spiral")
	await _anim_player.animation_finished
	_repack_pathfollow()
	path_finished.emit()
		
