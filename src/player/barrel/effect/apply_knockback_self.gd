extends BaseBarrelEffect

@export var force: float
@export var max_range: float

func on_projectile_impact(_projectile: BaseProjectile, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	if (_has_pos):
		var dist = _pos.distance_to(GameManager.player.global_position)
		if dist <= max_range:
			var dir = _pos.direction_to(GameManager.player.global_position)
			GameManager.player.apply_impulse_to_player(dir * force)
