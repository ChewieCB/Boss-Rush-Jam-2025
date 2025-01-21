extends BaseBarrelEffect

@export var new_prefab: PackedScene

func on_reload_end():
	super()
	owner_barrel.owner_gun.modified_projectile_prefab = new_prefab
