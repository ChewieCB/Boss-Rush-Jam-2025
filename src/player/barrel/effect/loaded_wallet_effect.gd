extends BaseBarrelEffect

@export var bonus_flat_crit_chance = 0.25

func on_projectile_spawn(projectile: BaseBullet):
	projectile.crit_chance += bonus_flat_crit_chance


func on_damage_applied(damage: float, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	var rounded_damage = int(damage)
	if GameManager.player_currency >= rounded_damage:
		GameManager.player_currency -= rounded_damage
	else:
		GameManager.player.health_component.damage(rounded_damage)