extends BaseBarrelEffect

@export var split_count = 2
@export var split_spread_radius = 10.0

func on_projectile_impact(_projectile: BaseBullet, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	if not is_instance_valid(_projectile):
		return
	_projectile.split(split_count, split_spread_radius, _has_pos, _pos)
