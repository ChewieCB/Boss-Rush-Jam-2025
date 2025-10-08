extends BaseBarrelEffect

@export var explosion_range: float = 1
@export var damage: int
@export var explosion_damage: PackedScene


func on_projectile_impact(_projectile: BaseProjectile, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	if (_has_pos):
		create_explosion(_pos)


func create_explosion(pos: Vector3):
	var explosion_dmg_inst: ExplosionDamageArea = explosion_damage.instantiate()
	# Explosion damage equal to 50% of original damage
	explosion_dmg_inst.init(round(owner_barrel.owner_gun.modified_damage / 2.0))
	GameManager.player.get_parent().add_child(explosion_dmg_inst)
	explosion_dmg_inst.global_position = pos
	explosion_dmg_inst.scale = Vector3(explosion_range, explosion_range, explosion_range)