extends Node3D
class_name ObjectPoolingManager # Not an Autoload

@export var explosion_node_prefab: PackedScene
@export var explosion_pool_size: int = 10

var explosion_pool: Array[ExplosionDamageArea] = []
var explosion_next_index: int = 0

func _ready() -> void:
	# Pooled object should have activate() and deactivate() funcs
	# Pre-instantiate
	for i in range(explosion_pool_size):
		create_new_explosion_node()

	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.object_pooling_manager = self


func create_new_explosion_node() -> ExplosionDamageArea:
	var explosion_inst: ExplosionDamageArea = explosion_node_prefab.instantiate()
	explosion_inst.visible = false
	explosion_inst.damage_disabled = true
	explosion_inst.active = false
	add_child(explosion_inst)
	explosion_pool.append(explosion_inst)
	return explosion_inst

func get_explosion_node() -> ExplosionDamageArea:
	for child in explosion_pool:
		if not child.active:
			return child

	# If all are active, create new 
	return create_new_explosion_node()