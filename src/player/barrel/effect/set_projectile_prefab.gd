extends BaseBarrelEffect

@export var new_prefab: PackedScene
@export var new_pool: ObjectPoolingManager.PooledObjectEnum
@export var prefab_can_be_pooled: bool = false


func on_effect_set():
	super()
	owner_barrel.owner_gun.modified_projectile_prefab = new_prefab
	owner_barrel.owner_gun.modified_projectile_pool = new_pool
	owner_barrel.owner_gun.projectile_prefab_can_be_pooled = prefab_can_be_pooled


func on_reload_end():
	super()
	owner_barrel.owner_gun.modified_projectile_prefab = new_prefab
	owner_barrel.owner_gun.modified_projectile_pool = new_pool
	owner_barrel.owner_gun.projectile_prefab_can_be_pooled = prefab_can_be_pooled
