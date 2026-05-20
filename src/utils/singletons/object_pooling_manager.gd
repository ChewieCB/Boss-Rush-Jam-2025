extends Node3D
class_name ObjectPoolingManager # Not an Autoload

enum PooledObjectEnum {
	EXPLOSION,
	EXPLOSION_OLD,
	GEL_STREAM_PROJECTILE
}

@export var pooled_object_prefabs: Array[PackedScene] = []
@export var pooled_object_init_arr_size: Array[int] = []

var object_pool: Array[Array] = []
@onready var _root = get_tree().get_root()

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
	if inst.has_signal("finished"):
		inst.finished.connect(_on_inst_finished.bind(inst, object_pool[int(object_enum)]))
	_root.add_child(inst)
	inst.deactivate()
	object_pool[int(object_enum)].push_back(inst)
	
	return inst


func _on_inst_finished(object, object_pool) -> void:
	object_pool.push_back(object)


func get_pooled_object(object_enum: PooledObjectEnum):
	var obj = object_pool[object_enum].pop_front()
	if not obj:
		return create_new_pooled_object(object_enum)
	else:
		return obj
