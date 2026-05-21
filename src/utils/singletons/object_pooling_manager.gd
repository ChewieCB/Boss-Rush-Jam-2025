extends Node3D
#class_name ObjectPoolingManager # Not an Autoload

enum PooledObjectEnum {
	EXPLOSION,
	EXPLOSION_OLD,
	#GEL_STREAM_PROJECTILE,
	STICKY_BOMB_PROJECTILE
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
			create_new_pooled_object.call_deferred(object_enum as PooledObjectEnum)

	await get_tree().process_frame
	await get_tree().process_frame
	
	for pool in object_pool:
		for obj in pool:
			if obj.has_method("activate"):
				obj.activate()

	await RenderingServer.frame_post_draw

	for pool in object_pool:
		for obj in pool:
			if obj.has_method("deactivate"):
				obj.deactivate()


func create_new_pooled_object(object_enum: PooledObjectEnum):
	var inst = pooled_object_prefabs[int(object_enum)].instantiate()
	_root.add_child.call_deferred(inst)
	_setup_pool_callback.call_deferred(inst, object_enum)
	inst.deactivate.call_deferred()
	object_pool[int(object_enum)].push_back(inst)
	
	if inst is StickyBombProjectile:
		inst.make_material_unique.call_deferred()

	return inst


func _setup_pool_callback(inst: Node, object_enum: PooledObjectEnum) -> void:
	inst.finished.connect(_on_inst_finished.bind(inst, object_pool[int(object_enum)]))
	


func _on_inst_finished(object, object_pool) -> void:
	object.deactivate()
	object_pool.push_back(object)


func get_pooled_object(object_enum: PooledObjectEnum):
	var obj = object_pool[object_enum].pop_front()
	if not obj:
		return create_new_pooled_object(object_enum)
	else:
		return obj
