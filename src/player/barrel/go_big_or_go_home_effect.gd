extends BaseBarrelEffect

@export var crit_modify_dmg_perc: float = 100.0
@export var not_crit_modify_dmg_perc: float = -90

func on_before_damage_applied(_enemy: CharacterBody3D, projectile: BaseBullet):
	if projectile.is_crit:
		projectile.damage += round(projectile.damage * (crit_modify_dmg_perc / 100.0))
	else:
		projectile.damage += round(projectile.damage * (not_crit_modify_dmg_perc / 100.0))
