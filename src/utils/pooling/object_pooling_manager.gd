extends Node3D
#class_name ObjectPoolingManager # Not an Autoload

enum PooledObjectEnum {
	EXPLOSION,
	EXPLOSION_OLD,
	PLAYER_GUN_PROJECTILE,
	PLAYER_GUN_HITSCAN,
	PLAYER_STICKY_BOMB_PROJECTILE,
	GUN_SPARK,
}

@export var pooled_object_prefabs: Array[PackedScene] = []
#@export var pooled_object_init_arr_size: Array[int] = []
@export var MAX_POOL_SIZE: int = 200:
	set(value):
		MAX_POOL_SIZE = value
		# Resize pools - remove any objects that no longer fit into the pool
		for _pool_arr in [active_object_pool, available_object_pool]:
			for object_enum in PooledObjectEnum.values():
				var pool = _pool_arr[object_enum]
				if pool.size() > MAX_POOL_SIZE:
					# If we reduce size, queue free any unused instances
					var _overflow = pool.slice(MAX_POOL_SIZE)
					for obj in _overflow:
						obj.queue_free()
					# Resize the pool to the new size
					pool.resize(MAX_POOL_SIZE)


var active_object_pool: Array[Array] = []
var available_object_pool: Array[Array] = []
@onready var _root = get_tree().get_root()

func _ready() -> void:
	assert(len(PooledObjectEnum.values()) == len(pooled_object_prefabs))
	
	if InputHelper.device == InputHelper.DEVICE_STEAMDECK_CONTROLLER:
		if MAX_POOL_SIZE > 150: # TODO - find a good default value for this
			MAX_POOL_SIZE = 150
	
	for object_enum in PooledObjectEnum.values():
		active_object_pool.append([])
		available_object_pool.append([])
	
	init_object_pools()


func init_object_pools() -> void:
	for object_enum in PooledObjectEnum.values():
		for i in range(MAX_POOL_SIZE):
			create_new_pooled_object.call_deferred(object_enum as PooledObjectEnum)
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	for pool in available_object_pool:
		for obj in pool:
			if obj.has_method("activate"):
				obj.activate()
	
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw # depth pre pass
	
	for pool in available_object_pool:
		for obj in pool:
			if obj.has_method("deactivate"):
				obj.deactivate()


func create_new_pooled_object(object_enum: PooledObjectEnum):
	var inst = pooled_object_prefabs[int(object_enum)].instantiate()
	_root.add_child.call_deferred(inst)
	return_object_to_pool(inst, object_enum, false)
	# FIXME - is the lanbda useful here over the dedicated method?
	(func():
		if inst is StickyBombProjectile:
			inst.make_material_unique()
		if inst.finished.is_connected(_on_inst_finished):
			inst.finished.disconnect(_on_inst_finished)
		inst.finished.connect(_on_inst_finished.bind(inst, object_enum))
		inst.deactivate()
	).call_deferred()

	return inst


func create_new_pooled_object_sync(object_enum: PooledObjectEnum):
	var inst = pooled_object_prefabs[int(object_enum)].instantiate()
	_root.add_child(inst)
	return_object_to_pool(inst, object_enum, false)
	_setup_pool_callback(inst, object_enum)
	
	return inst


func _setup_pool_callback(inst: Node, object_enum: PooledObjectEnum) -> void:
	if inst is StickyBombProjectile:
		inst.make_material_unique()
	if inst.finished.is_connected(_on_inst_finished):
		inst.finished.disconnect(_on_inst_finished)
	inst.finished.connect(_on_inst_finished.bind(inst, object_enum))
	inst.deactivate()


func _on_inst_finished(object: Node, object_enum: PooledObjectEnum) -> void:
	return_object_to_pool(object, object_enum)


func get_pooled_object(object_enum: PooledObjectEnum):
	var _available_pool = available_object_pool[object_enum]
	var _active_pool = active_object_pool[object_enum]
	var obj: Node
	if _available_pool.size() > 0:
		obj = _available_pool.pop_back()
		_active_pool.push_front(obj)
	else:
		if _active_pool.size() < MAX_POOL_SIZE:
			obj = create_new_pooled_object_sync(object_enum)
		else:
			obj = recycle_in_use_object(object_enum)
	
	return obj


func return_object_to_pool(object: Node, object_enum: PooledObjectEnum, deactivate: bool = true) -> void:
	var _available_pool = available_object_pool[object_enum]
	var _active_pool = active_object_pool[object_enum]
	
	if _active_pool.has(object):
		_active_pool.erase(object)
	
	if not _available_pool.has(object):
		_available_pool.push_front(object)
	
	if deactivate:
		object.deactivate()


func recycle_in_use_object(object_enum: PooledObjectEnum):
	var _active_pool = active_object_pool[object_enum]
	
	if _active_pool.is_empty():
		push_error("No objects to recycle for enum: %s" % object_enum)
		return null
	
	var oldest_obj = _active_pool.pop_back()
	oldest_obj.deactivate()
	
	return oldest_obj
