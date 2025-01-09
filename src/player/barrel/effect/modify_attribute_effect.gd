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

func calculate_new_value(old_value):
	var new_value = 0
	if is_perc:
		new_value = round(old_value * (1 + (modify_value / 100.0)))
	else:
		new_value = old_value + modify_value
	return new_value


func on_fire_rate_check():
	super()
	match attribute:
		AttributeNameEnum.FIRERATE:
			owner_barrel.owner_gun.modified_firerate = calculate_new_value(owner_barrel.owner_gun.modified_firerate)

func on_prepare_to_fire():
	super()
	match attribute:
		AttributeNameEnum.DAMAGE:
			owner_barrel.owner_gun.modified_damage = calculate_new_value(owner_barrel.owner_gun.modified_damage)
		AttributeNameEnum.PROJECTILE_AMOUNT:
			owner_barrel.owner_gun.modified_projectile_amount = calculate_new_value(owner_barrel.owner_gun.modified_projectile_amount)
		AttributeNameEnum.PROJECTILE_SPEED:
			owner_barrel.owner_gun.modified_projectile_speed = calculate_new_value(owner_barrel.owner_gun.modified_projectile_speed)
		AttributeNameEnum.MAGAZINE_SIZE:
			owner_barrel.owner_gun.modified_magazine_size = calculate_new_value(owner_barrel.owner_gun.modified_magazine_size)
		AttributeNameEnum.IS_HITSCAN:
			var res = true
			if modify_value == 0:
				res = false
			owner_barrel.owner_gun.modified_is_hitscan = res
		AttributeNameEnum.SPREAD_ANGLE:
			owner_barrel.owner_gun.modified_spread_angle = calculate_new_value(owner_barrel.owner_gun.modified_spread_angle)

func on_ammo_consumed():
	super()

func on_clip_empty():
	super()

func on_reload_start():
	super()
	match attribute:
		AttributeNameEnum.RELOAD_TIME:
			owner_barrel.owner_gun.modified_reload_time = calculate_new_value(owner_barrel.owner_gun.modified_reload_time)

func on_reload_end():
	super()
	match attribute:
		AttributeNameEnum.MAGAZINE_SIZE:
			owner_barrel.owner_gun.modified_magazine_size = calculate_new_value(owner_barrel.owner_gun.modified_magazine_size)

func on_reload_interrupted():
	super()

func on_projectile_spawn():
	super()

func on_projectile_travel_tick():
	super()

func on_projectile_impact():
	super()

func on_projectile_destroyed():
	super()

func on_damage_calculation():
	super()

func on_damage_applied():
	super()

func on_enemy_killed():
	super()

func on_status_effect_tick():
	super()

func on_weapon_switched_to():
	super()