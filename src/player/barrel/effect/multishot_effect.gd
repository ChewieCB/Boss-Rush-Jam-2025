extends BaseBarrelEffect

@export var ammo_consumed: int
@export var shot_count: int

func on_prepare_to_fire():
	super()
	owner_barrel.owner_gun.n_ammo_consume += 1
	owner_barrel.owner_gun.n_shot_repeat += 1

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

func on_damage_applied():
	super()

func on_enemy_killed():
	super()

func on_status_effect_tick():
	super()

func on_weapon_switched_to():
	super()