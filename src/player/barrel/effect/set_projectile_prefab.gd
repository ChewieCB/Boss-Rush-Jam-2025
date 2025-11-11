extends BaseBarrelEffect

@export var new_prefab: PackedScene
@export var prefab_can_be_pooled: bool = false

func on_reload_end():
	super ()
	owner_barrel.owner_gun.modified_projectile_prefab = new_prefab
	owner_barrel.owner_gun.projectile_prefab_can_be_pooled = prefab_can_be_pooled
