extends BaseBarrelEffect

enum AttributeNameEnum {
	NONE,
	DAMAGE,
	PROJECTILE_AMOUNT,
	PROJECTILE_SPEED,
	FIRERATE,
	MAGAZINE_SIZE,
	IS_HITSCAN,
	SPREAD_ANGLE,
	RELOAD_TIME
}

@export var attribute: AttributeNameEnum
## By default is flat value. For boolean value, 0 for false and 1 for true
@export var modify_value: float
@export var is_perc: bool


func on_fire_rate_check():
	super()
	match attribute:
		AttributeNameEnum.FIRERATE:
			owner_barrel.owner_gun.modified_firerate = calculate_new_value(
				owner_barrel.owner_gun.modified_firerate, modify_value, is_perc, false)

func on_prepare_to_fire():
	super()
	match attribute:
		AttributeNameEnum.DAMAGE:
			owner_barrel.owner_gun.modified_damage = calculate_new_value(
				owner_barrel.owner_gun.modified_damage, modify_value, is_perc)
		AttributeNameEnum.PROJECTILE_AMOUNT:
			owner_barrel.owner_gun.modified_projectile_amount = calculate_new_value(
				owner_barrel.owner_gun.modified_projectile_amount, modify_value, is_perc)
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

func on_reload_start():
	super()
	match attribute:
		AttributeNameEnum.RELOAD_TIME:
			owner_barrel.owner_gun.modified_reload_time = calculate_new_value(
				owner_barrel.owner_gun.modified_reload_time, modify_value, is_perc, false)

func on_reload_end():
	super()
	match attribute:
		AttributeNameEnum.MAGAZINE_SIZE:
			owner_barrel.owner_gun.modified_magazine_size = calculate_new_value(
				owner_barrel.owner_gun.modified_magazine_size, modify_value, is_perc)
