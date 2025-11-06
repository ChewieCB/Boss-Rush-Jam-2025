extends BaseBarrelEffect

@export var damage_modify_perc: float = 20
## In %, so 50 = 50%
@export var crit_chance: float = 20


func on_projectile_spawn(projectile: BaseBullet):
	# If the player is looking downward (negative local Y axis points up)
	if GameManager.player.player_camera.transform.basis.z.y > 0:
		projectile.crit_chance += (crit_chance / 100.0)

func on_damage_calculation():
	super ()
	if not GameManager.player.is_on_floor():
		owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + (damage_modify_perc / 100.0)))
