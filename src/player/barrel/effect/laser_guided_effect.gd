extends BaseBarrelEffect

@export var bonus_flat_speed_for_hitscan = 50

func on_prepare_to_fire():
	super ()
	if owner_barrel.owner_gun.modified_is_hitscan:
		owner_barrel.owner_gun.modified_is_hitscan = false
		owner_barrel.owner_gun.modified_projectile_speed = calculate_new_value(
			owner_barrel.owner_gun.modified_projectile_speed, bonus_flat_speed_for_hitscan, false, false)
func on_projectile_spawn(projectile: BaseBullet):
	projectile.can_be_aim_guided = true
