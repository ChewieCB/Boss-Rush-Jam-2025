extends BaseBarrelEffect

@export var ammo_consumed_modify: int
@export var shot_count_modify: int

func on_prepare_to_fire():
	super()
	owner_barrel.owner_gun.n_ammo_consume += ammo_consumed_modify
	owner_barrel.owner_gun.n_shot_repeat += shot_count_modify
