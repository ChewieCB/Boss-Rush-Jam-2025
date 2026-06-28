extends BaseBarrelEffect

@export var new_prefab: PackedScene
@export var new_pool: ObjectPoolingManager.PooledObjectEnum
@export var prefab_can_be_pooled: bool = false


func on_effect_set():
	super()
	var gun = owner_barrel.owner_gun
	gun.modified_projectile_prefab = new_prefab
	gun.modified_projectile_pool = new_pool


func on_effect_removed():
	super()
	var gun = owner_barrel.owner_gun
	gun.modified_projectile_prefab = gun.base_custom_projectile_prefab
	gun.modified_projectile_pool = gun.base_projectile_pool


func on_barrel_start_spin():
	owner_barrel.owner_gun.reset_modifier()
	super()


func on_reload_end():
	super()
	owner_barrel.owner_gun.modified_projectile_prefab = new_prefab
	owner_barrel.owner_gun.modified_projectile_pool = new_pool
