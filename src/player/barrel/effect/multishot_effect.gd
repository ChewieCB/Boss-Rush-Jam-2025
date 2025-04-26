extends BaseBarrelEffect

@export var shot_count_per_trigger_modify: int
@export var ammo_consumed_per_shot_modify: int

func on_effect_set():
	super()
	owner_barrel.owner_gun.n_ammo_consume += ammo_consumed_per_shot_modify
	owner_barrel.owner_gun.n_shot_repeat += shot_count_per_trigger_modify
