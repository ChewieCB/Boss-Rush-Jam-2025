extends BaseBarrelEffect

enum AttributeNameEnum {
	NONE,
	DAMAGE,
	PROJECTILE_AMOUNT,
	PROJECTILE_SPEED,
	FIRERATE,
	MAGAZINE_SIZE,
	IS_HITSCAN,
	SPREAD_ANGLE
}

@export var attribute: AttributeNameEnum
## For boolean value, 0 for false and 1 for true
@export var new_value: float


func on_fire_rate_check():
	super()
	match attribute:
		AttributeNameEnum.FIRERATE:
			owner_barrel.owner_gun.modified_firerate = new_value

func on_prepare_to_fire():
	super()
	match attribute:
		AttributeNameEnum.DAMAGE:
			owner_barrel.owner_gun.modified_damage = new_value
		AttributeNameEnum.PROJECTILE_AMOUNT:
			owner_barrel.owner_gun.modified_projectile_amount = new_value
		AttributeNameEnum.PROJECTILE_SPEED:
			owner_barrel.owner_gun.modified_projectile_speed = new_value
		AttributeNameEnum.MAGAZINE_SIZE:
			owner_barrel.owner_gun.modified_magazine_size = new_value
		AttributeNameEnum.IS_HITSCAN:
			var res = true
			if new_value == 0:
				res = false
			owner_barrel.owner_gun.modified_is_hitscan = res
		AttributeNameEnum.SPREAD_ANGLE:
			owner_barrel.owner_gun.modified_spread_angle = new_value

func on_ammo_consumed():
	super()

func on_clip_empty():
	super()

func on_reload_start():
	super()

func on_reload_end():
	super()
	match attribute:
		AttributeNameEnum.MAGAZINE_SIZE:
			owner_barrel.owner_gun.modified_magazine_size = new_value

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