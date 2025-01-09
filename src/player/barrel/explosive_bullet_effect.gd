extends BaseBarrelEffect

@export var explosion_range: float
@export var damage: int
@export var explosion_vfx: PackedScene


func on_projectile_impact(_has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	if (_has_pos):
		create_explosion(_pos)


func create_explosion(pos: Vector3):
	var explosion_inst = explosion_vfx.instantiate()
	get_parent().add_child(explosion_inst)
	explosion_inst.global_position = pos