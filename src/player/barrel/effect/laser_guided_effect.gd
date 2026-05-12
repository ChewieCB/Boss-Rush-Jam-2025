extends BaseBarrelEffect

@export var bonus_flat_speed_for_hitscan = 50

func on_prepare_to_fire():
	super ()
	if owner_barrel.owner_gun.modified_is_hitscan:
		owner_barrel.owner_gun.modified_is_hitscan = false
		owner_barrel.owner_gun.modified_projectile_speed = calculate_new_value(
			owner_barrel.owner_gun.modified_projectile_speed, bonus_flat_speed_for_hitscan, false, false)

func on_projectile_spawn(projectile: BaseBullet):
	super (projectile)
	projectile.can_be_aim_guided = true
	projectile.misc_data["laser_guided_start_vector"] = \
		GameManager.player.aim_ray.aim_ray_end.global_position - GameManager.player.global_position

func on_before_damage_applied(enemy: CharacterBody3D, projectile: BaseBullet):
	super (enemy, projectile)
	var player_to_enemy_vector = enemy.global_position - GameManager.player.global_position
	if "laser_guided_start_vector" in projectile.misc_data:
		const ELABORATED_ANGLE_BONUS_LUCK = 10
		const ELABORATED_ANGLE_REQUIRE = 89
		if GunUtils.angle_between_vectors(player_to_enemy_vector, projectile.misc_data["laser_guided_start_vector"]) >= ELABORATED_ANGLE_REQUIRE:
			LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.LASER_GUIDED__ELABORATED_ANGLE)
			LuckHandler.increase_luck(ELABORATED_ANGLE_BONUS_LUCK, "+10 Elaborated Angle!")
