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
	RELOAD_TIME,
	RICOCHET_COUNT,
	HOMING_STRENGTH,
	RECOIL,
	SCREENSHAKE
}

@export var attribute: AttributeNameEnum
## For boolean value, 0 for false and 1 for true
@export var new_value: float


func on_effect_set():
	super()
	match attribute:
		AttributeNameEnum.FIRERATE:
			owner_barrel.owner_gun.modified_firerate = new_value
		AttributeNameEnum.DAMAGE:
			owner_barrel.owner_gun.modified_damage = new_value
		AttributeNameEnum.PROJECTILE_AMOUNT:
			owner_barrel.owner_gun.modified_projectile_amount = new_value
		AttributeNameEnum.PROJECTILE_SPEED:
			owner_barrel.owner_gun.modified_projectile_speed = new_value
		AttributeNameEnum.IS_HITSCAN:
			var res = true
			if new_value == 0:
				res = false
			owner_barrel.owner_gun.modified_is_hitscan = res
		AttributeNameEnum.SPREAD_ANGLE:
			owner_barrel.owner_gun.modified_spread_angle = new_value
		AttributeNameEnum.RICOCHET_COUNT:
			owner_barrel.owner_gun.modified_ricochet_count = new_value
		AttributeNameEnum.HOMING_STRENGTH:
			owner_barrel.owner_gun.modified_homing_strength = new_value
		AttributeNameEnum.MAGAZINE_SIZE:
			owner_barrel.owner_gun.modified_magazine_size = new_value
		AttributeNameEnum.RECOIL:
			owner_barrel.owner_gun.modified_recoil = new_value
		AttributeNameEnum.SCREENSHAKE:
			owner_barrel.owner_gun.modified_screenshake = new_value
		AttributeNameEnum.RELOAD_TIME:
			owner_barrel.owner_gun.modified_reload_time = new_value
