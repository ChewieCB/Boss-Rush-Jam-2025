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

func on_ammo_consumed():
	super()

func on_clip_empty():
	super()

func on_reload_start():
	super()

func on_reload_end():
	super()

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
	if GameManager.player.velocity.length() < STAND_STILL_THRESHOLD:
		owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + modify_perc_damage_stationary / 100.0))
	else:
		owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + modify_perc_damage_moving / 100.0))


func on_damage_applied():
	super()

func on_enemy_killed():
	super()

func on_status_effect_tick():
	super()

func on_weapon_switched_to():
	super()
