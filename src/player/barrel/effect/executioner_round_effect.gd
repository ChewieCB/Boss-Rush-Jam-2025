extends BaseBarrelEffect

## From 0 to 100
@export var enemy_hp_threshold_perc = 30
@export var dmg_modify_perc_above_threshold = -25
@export var dmg_modify_perc_below_threshold = 25

func on_before_damage_applied(enemy: CharacterBody3D, projectile: BaseProjectile):
	if enemy.health_component == null:
		return
	var health_component = enemy.health_component as HealthComponent
	if health_component.current_health_ratio >= (enemy_hp_threshold_perc / 100.0):
		projectile.damage = projectile.damage * (1 + dmg_modify_perc_above_threshold / 100.0)
	else:
		projectile.damage = projectile.damage * (1 + dmg_modify_perc_below_threshold / 100.0)
