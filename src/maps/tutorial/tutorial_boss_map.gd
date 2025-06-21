extends BossMap

@export var boss_doors: ElevatorDoors
@export var exit_doors: ElevatorDoors
@export var chipling_prefab: PackedScene
@export var chiplings_to_spawn_1: int = 5
@onready var chipling_spawns_1: Array[Node] = get_tree().get_nodes_in_group("boss_chipling_spawn_1_marker")
@onready var chipling_wander_points_1: Array[Node] = get_tree().get_nodes_in_group("boss_chipling_wander_1_marker")


func _ready() -> void:
	super()
	boss_doors.close()
	for i in range(chiplings_to_spawn_1):
		spawn_chipling_area_1()


func spawn_chipling_area_1() -> void:
	# Pick spawn point
	var spawn_point = chipling_spawns_1.pick_random()
	# Instance chipling
	var chipling = chipling_prefab.instantiate()
	chipling.wander_waypoints = chipling_wander_points_1
	add_child(chipling)
	chipling.global_position = spawn_point.global_position
	chipling.died.connect(_on_chipling_died)
	# Trigger chipling drop
	#chipling.get_node("UI/StateChartDebugger").enabled = true
	await chipling.ready
	chipling.spawn()


func _on_chipling_died() -> void:
	await get_tree().create_timer(0.6).timeout
	# TODO - make this generic for all spawning areas
	spawn_chipling_area_1()


func _on_boss_door_trigger_volume_body_entered(body: Node3D) -> void:
	if body is Player:
		boss_doors.open()


func _on_boss_door_trigger_volume_body_exited(body: Node3D) -> void:
	if body is Player:
		boss_doors.close()


func _on_elevator_door_trigger_volume_body_entered(body: Node3D) -> void:
	if body is Player:
		exit_doors.open()


func _on_elevator_door_trigger_volume_body_exited(body: Node3D) -> void:
	if body is Player:
		exit_doors.close()

#
#func _on_debug_boss_trigger_body_entered(body: Node3D) -> void:
	#if body is Player:
		#for i in range(chiplings_to_spawn_1):
			#spawn_chipling_area_1()
			#await get_tree().create_timer(0.2).timeout
	#$DEBUGBossTrigger.queue_free()
