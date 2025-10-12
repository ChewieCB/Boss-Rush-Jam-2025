extends Node3D
class_name ObjectPoolingManager # Not an Autoload

enum PooledObjectEnum {
	EXPLOSION,
}

@export var pooled_object_prefabs: Array[PackedScene] = []
@export var pooled_object_init_arr_size: Array[int] = []

var object_pool: Array[Array] = []

func _ready() -> void:
	assert(len(PooledObjectEnum.values()) == len(pooled_object_prefabs))
	# Pooled object should have activate() and deactivate() funcs
	# Pre-instantiate
	for object_enum in PooledObjectEnum.values():
		object_pool.append([])
		for i in range(pooled_object_init_arr_size[int(object_enum as PooledObjectEnum)]):
			create_new_pooled_object(object_enum as PooledObjectEnum)

	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.object_pooling_manager = self


func create_new_pooled_object(object_enum: PooledObjectEnum):
	var inst = pooled_object_prefabs[int(object_enum)].instantiate()
	add_child(inst)
	inst.deactivate()
	object_pool[int(object_enum)].append(inst)
	return inst


func get_pooled_object(object_enum: PooledObjectEnum):
	for child in object_pool[object_enum]:
		if not child.active:
			return child

	# If all are active, create new 
	return create_new_pooled_object(object_enum)