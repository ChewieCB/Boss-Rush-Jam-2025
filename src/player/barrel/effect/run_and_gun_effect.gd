extends BaseBarrelEffect

@export var modify_perc_spread_stationary: float
@export var modify_perc_damage_stationary: float

@export var modify_perc_spread_moving: float
@export var modify_perc_damage_moving: float

const STAND_STILL_THRESHOLD = 1

func on_prepare_to_fire():
	super()
	if GameManager.player.velocity.length() < STAND_STILL_THRESHOLD:
		owner_barrel.owner_gun.modified_spread_angle = round(owner_barrel.owner_gun.modified_spread_angle * (1 + modify_perc_spread_stationary / 100.0))
	else:
		owner_barrel.owner_gun.modified_spread_angle = round(owner_barrel.owner_gun.modified_spread_angle * (1 + modify_perc_spread_moving / 100.0))

func on_damage_calculation():
	super()
	if GameManager.player.velocity.length() < STAND_STILL_THRESHOLD:
		owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + modify_perc_damage_stationary / 100.0))
	else:
		owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + modify_perc_damage_moving / 100.0))
