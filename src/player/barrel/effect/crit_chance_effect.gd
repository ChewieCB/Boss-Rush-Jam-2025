extends BaseBarrelEffect

## In %, so 50 = 50%
@export var crit_chance: float = 25

func on_projectile_spawn(projectile: BaseBullet):
	projectile.crit_chance += (crit_chance / 100.0)
