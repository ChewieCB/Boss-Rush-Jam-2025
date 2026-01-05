extends BaseBarrelEffect

@export var damage: int


func on_projectile_impact(_projectile: BaseBullet, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	if (_has_pos):
		create_explosion(_pos)


func create_explosion(pos: Vector3):
	var explosion_inst = GameManager.object_pooling_manager.get_pooled_object(ObjectPoolingManager.PooledObjectEnum.EXPLOSION)
	explosion_inst.init(damage)
	explosion_inst.activate(pos)
