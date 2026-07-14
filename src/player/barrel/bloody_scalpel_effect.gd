extends BaseBarrelEffect


var shot_count = 0
var proj_amount_per_shot = 0
var hit_count_tracker = {}


func on_prepare_to_fire():
	super()
	var increased_spread_amount = (2.0 / owner_barrel.owner_gun.modified_projectile_amount) + 2
	owner_barrel.owner_gun.modified_spread_angle = calculate_new_value(
		owner_barrel.owner_gun.modified_spread_angle, increased_spread_amount, false, false)


func on_gun_damage_calculation():
	super()
	proj_amount_per_shot = owner_barrel.owner_gun.modified_projectile_amount
	shot_count += 1
	hit_count_tracker[shot_count] = 0

func on_projectile_spawn(projectile: BaseBullet):
	super(projectile)
	projectile.misc_data["bloody_scalpel_shot_count"] = shot_count


func on_before_damage_applied(enemy: CharacterBody3D, projectile: BaseBullet):
	super(enemy, projectile)
	if "bloody_scalpel_shot_count" in projectile.misc_data:
		var this_proj_shot_count = projectile.misc_data["bloody_scalpel_shot_count"]
		hit_count_tracker[this_proj_shot_count] += 1
		if hit_count_tracker[this_proj_shot_count] == proj_amount_per_shot:
			LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.BLOODY_SCALPEL__FULL_CUT)
			LuckHandler.increase_luck(2, "+2 Full Cut!")


func on_reload_end():
	super()
	shot_count = 0
	hit_count_tracker = {}
