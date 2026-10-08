extends BaseBarrelEffect

@export var attribute: AttributeNameEnum
## By default is flat value. If is_perc is true, 50 = 50%. For boolean value, 0 for false and 1 for true
@export var modify_value: float
@export var is_perc: bool
@export var exclude_frames: Array[GunFrameResource.GunFrameIdEnum] = []

func on_effect_set():
	super()
	
	if GameManager.equipped_gun_frame.frame_id in exclude_frames:
		return
	
	match attribute:
		AttributeNameEnum.FIRERATE:
			owner_barrel.owner_gun.modified_firerate = calculate_new_value(
				owner_barrel.owner_gun.modified_firerate, modify_value, is_perc, false)
		AttributeNameEnum.MAGAZINE_SIZE:
			owner_barrel.owner_gun.modified_magazine_size = calculate_new_value(
				owner_barrel.owner_gun.modified_magazine_size, modify_value, is_perc, true)
		AttributeNameEnum.RELOAD_TIME:
			owner_barrel.owner_gun.modified_reload_time = calculate_new_value(
				owner_barrel.owner_gun.modified_reload_time, modify_value, is_perc, false)


func on_fire_rate_check():
	super()
	#match attribute:
		#AttributeNameEnum.FIRERATE:
			#owner_barrel.owner_gun.modified_firerate = calculate_new_value(
				#owner_barrel.owner_gun.modified_firerate, modify_value, is_perc, false)

func preview_spread_angle(spread_angle: float) -> float:
	if attribute == AttributeNameEnum.SPREAD_ANGLE:
		return calculate_new_value(spread_angle, modify_value, is_perc, false)
	return spread_angle

func preview_spread_horizontal_bias(horizontal_bias: float) -> float:
	if attribute == AttributeNameEnum.SPREAD_HORIZONTAL_BIAS:
		return calculate_new_value(horizontal_bias, modify_value, is_perc, false)
	return horizontal_bias

func on_prepare_to_fire():
	super()
	
	if GameManager.equipped_gun_frame.frame_id in exclude_frames:
		return
	
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
