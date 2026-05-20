extends BaseBarrelEffect

@export var attribute: AttributeNameEnum
## By default is flat value. If is_perc is true, 50 = 50%. For boolean value, 0 for false and 1 for true
@export var modify_value: float
@export var is_perc: bool

func on_effect_set():
	super ()
	match attribute:
		AttributeNameEnum.FIRERATE:
			owner_barrel.owner_gun.modified_firerate = calculate_new_value(
				owner_barrel.owner_gun.modified_firerate, modify_value, is_perc, false)
		AttributeNameEnum.DAMAGE:
			owner_barrel.owner_gun.modified_damage = calculate_new_value(
				owner_barrel.owner_gun.modified_damage, modify_value, is_perc, true)
		AttributeNameEnum.PROJECTILE_AMOUNT:
			owner_barrel.owner_gun.modified_projectile_amount = calculate_new_value(
				owner_barrel.owner_gun.modified_projectile_amount, modify_value, is_perc, true)
			if owner_barrel.owner_gun.modified_projectile_amount < 1:
				owner_barrel.owner_gun.modified_projectile_amount = 1
		AttributeNameEnum.PROJECTILE_SPEED:
			owner_barrel.owner_gun.modified_projectile_speed = calculate_new_value(
				owner_barrel.owner_gun.modified_projectile_speed, modify_value, is_perc, false)
		AttributeNameEnum.IS_HITSCAN:
			var res = true
			if modify_value == 0:
				res = false
			owner_barrel.owner_gun.modified_is_hitscan = res
		AttributeNameEnum.MAGAZINE_SIZE:
			owner_barrel.owner_gun.modified_magazine_size = calculate_new_value(
				owner_barrel.owner_gun.modified_magazine_size, modify_value, is_perc, true)
		AttributeNameEnum.SPREAD_ANGLE:
			owner_barrel.owner_gun.modified_spread_angle = calculate_new_value(
				owner_barrel.owner_gun.modified_spread_angle, modify_value, is_perc, false)
		AttributeNameEnum.SPREAD_HORIZONTAL_BIAS:
			owner_barrel.owner_gun.modified_spread_horizontal_bias = calculate_new_value(
				owner_barrel.owner_gun.modified_spread_horizontal_bias, modify_value, is_perc, false)
		AttributeNameEnum.RICOCHET_COUNT:
			owner_barrel.owner_gun.modified_ricochet_count = calculate_new_value(
				owner_barrel.owner_gun.modified_ricochet_count, modify_value, is_perc, true)
		AttributeNameEnum.HOMING_STRENGTH:
			owner_barrel.owner_gun.modified_homing_strength = calculate_new_value(
				owner_barrel.owner_gun.modified_homing_strength, modify_value, is_perc, false)
		AttributeNameEnum.RECOIL:
			owner_barrel.owner_gun.modified_recoil = calculate_new_value(
				owner_barrel.owner_gun.modified_recoil, modify_value, is_perc, false)
		AttributeNameEnum.RELOAD_TIME:
			owner_barrel.owner_gun.modified_reload_time = calculate_new_value(
				owner_barrel.owner_gun.modified_reload_time, modify_value, is_perc, false)
		AttributeNameEnum.SCREENSHAKE:
			owner_barrel.owner_gun.modified_screenshake = calculate_new_value(
				owner_barrel.owner_gun.modified_screenshake, modify_value, is_perc, false)


func on_fire_rate_check():
	super ()
	#match attribute:
		#AttributeNameEnum.FIRERATE:
			#owner_barrel.owner_gun.modified_firerate = calculate_new_value(
				#owner_barrel.owner_gun.modified_firerate, modify_value, is_perc, false)

func on_prepare_to_fire():
	super ()
	match attribute:
		AttributeNameEnum.DAMAGE:
			owner_barrel.owner_gun.modified_damage = calculate_new_value(
				owner_barrel.owner_gun.modified_damage, modify_value, is_perc, true)
		AttributeNameEnum.PROJECTILE_AMOUNT:
			owner_barrel.owner_gun.modified_projectile_amount = calculate_new_value(
				owner_barrel.owner_gun.modified_projectile_amount, modify_value, is_perc, true)
			if owner_barrel.owner_gun.modified_projectile_amount < 1:
				owner_barrel.owner_gun.modified_projectile_amount = 1
		AttributeNameEnum.PROJECTILE_SPEED:
			owner_barrel.owner_gun.modified_projectile_speed = calculate_new_value(
				owner_barrel.owner_gun.modified_projectile_speed, modify_value, is_perc, false)
		AttributeNameEnum.IS_HITSCAN:
			var res = true
			if modify_value == 0:
				res = false
			owner_barrel.owner_gun.modified_is_hitscan = res
		AttributeNameEnum.SPREAD_ANGLE:
			owner_barrel.owner_gun.modified_spread_angle = calculate_new_value(
				owner_barrel.owner_gun.modified_spread_angle, modify_value, is_perc, false)
		AttributeNameEnum.SPREAD_HORIZONTAL_BIAS:
			owner_barrel.owner_gun.modified_spread_horizontal_bias = calculate_new_value(
				owner_barrel.owner_gun.modified_spread_horizontal_bias, modify_value, is_perc, false)
		AttributeNameEnum.RICOCHET_COUNT:
			owner_barrel.owner_gun.modified_ricochet_count = calculate_new_value(
				owner_barrel.owner_gun.modified_ricochet_count, modify_value, is_perc, true)
		AttributeNameEnum.HOMING_STRENGTH:
			owner_barrel.owner_gun.modified_homing_strength = calculate_new_value(
				owner_barrel.owner_gun.modified_homing_strength, modify_value, is_perc, false)
		AttributeNameEnum.RECOIL:
			owner_barrel.owner_gun.modified_recoil = calculate_new_value(
				owner_barrel.owner_gun.modified_recoil, modify_value, is_perc, false)
		AttributeNameEnum.SCREENSHAKE:
			owner_barrel.owner_gun.modified_screenshake = calculate_new_value(
				owner_barrel.owner_gun.modified_screenshake, modify_value, is_perc, false)


func on_reload_start():
	super ()
	#match attribute:
		#AttributeNameEnum.MAGAZINE_SIZE:
			#owner_barrel.owner_gun.modified_magazine_size = calculate_new_value(
				#owner_barrel.owner_gun.modified_magazine_size, modify_value, is_perc, true)
		#AttributeNameEnum.RELOAD_TIME:
			#owner_barrel.owner_gun.modified_reload_time = calculate_new_value(
				#owner_barrel.owner_gun.modified_reload_time, modify_value, is_perc, false)

func on_reload_end():
	super ()
	#match attribute:
		#AttributeNameEnum.MAGAZINE_SIZE:
			#owner_barrel.owner_gun.modified_magazine_size = calculate_new_value(
				#owner_barrel.owner_gun.modified_magazine_size, modify_value, is_perc, true)


func on_before_damage_applied(enemy: CharacterBody3D, projectile: BaseBullet):
	super (enemy, projectile)
	if projectile.is_ricochet_shot and !(enemy is Player):
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.RICOCHET__RICOSHOT)
		if projectile.time_ricochetted >= 10:
			LuckHandler.increase_luck(20, "+100 Ultra Ricoshot?", LuckHandler.LuckTriggerType.DEVIL)
		elif projectile.time_ricochetted >= 5:
			LuckHandler.increase_luck(20, "+20 Mega Ricoshot!!", LuckHandler.LuckTriggerType.RARE)
		elif projectile.time_ricochetted >= 3:
			LuckHandler.increase_luck(10, "+10 Super Ricoshot!!", LuckHandler.LuckTriggerType.RARE)
		else:
			LuckHandler.increase_luck(3, "+3 Ricoshot!")
