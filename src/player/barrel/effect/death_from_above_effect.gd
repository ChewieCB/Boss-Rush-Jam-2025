extends BaseBarrelEffect

## In %, so 50 = 50%
@export var damage_modify_perc: float = 20
@export var crit_chance_perc: float = 20


func on_projectile_spawn(projectile: BaseBullet):
	# If the player is looking downward (negative local Y axis points up)
	if GameManager.player.player_camera.transform.basis.z.y > 0:
		projectile.crit_chance += (crit_chance_perc / 100.0)
		if not GameManager.player.is_on_floor():
			projectile.misc_data["has_death_from_above_effect"] = true

func on_gun_damage_calculation():
	super()
	if not GameManager.player.is_on_floor():
		owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + (damage_modify_perc / 100.0)))

func on_before_damage_applied(_enemy: CharacterBody3D, projectile: BaseBullet):
	super(_enemy, projectile)
	if projectile.is_crit and "has_death_from_above_effect" in projectile.misc_data:
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.DEATH_FROM_ABOVE__AERIAL_CRITICAL)
		LuckHandler.increase_luck(+6, "+6 Aerial Critical")
