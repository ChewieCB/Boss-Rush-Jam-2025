extends BossMap

@export var boss_doors: ElevatorDoors
@export var exit_doors: ElevatorDoors
@export var chipling_prefab: PackedScene
@export var chiplings_to_spawn_1: int = 5
@onready var chipling_spawns_1: Array[Node] = get_tree().get_nodes_in_group("boss_chipling_spawn_1_marker")
@onready var chipling_wander_points_1: Array[Node] = get_tree().get_nodes_in_group("boss_chipling_wander_1_marker")
@export var chiplings_to_spawn_2: int = 8
@onready var chipling_spawns_2: Array[Node] = get_tree().get_nodes_in_group("boss_chipling_spawn_2_marker")
@onready var chipling_wander_points_2: Array[Node] = get_tree().get_nodes_in_group("boss_chipling_wander_2_marker")


func _ready() -> void:
	super()
	boss_doors.close()
	for i in range(chiplings_to_spawn_1):
		spawn_chipling(1, chipling_spawns_1, chipling_wander_points_1)


func spawn_chipling(spawn_group: int, spawn_points: Array[Node], wander_points: Array[Node]) -> void:
	# Pick spawn point
	var spawn_point = spawn_points.pick_random()
	# Instance chipling
	var chipling = chipling_prefab.instantiate()
	chipling.spawn_group = spawn_group
	chipling.wander_waypoints = wander_points
	add_child(chipling)
	chipling.global_position = spawn_point.global_position
	chipling.died.connect(_on_chipling_died.bind(chipling))
	# Trigger chipling drop
	#chipling.get_node("UI/StateChartDebugger").enabled = true
	await chipling.ready
	chipling.spawn()


func _on_chipling_died(chipling: Chipling) -> void:
	await get_tree().create_timer(0.6).timeout
	match chipling.spawn_group:
		1:
			spawn_chipling(1, chipling_spawns_1, chipling_wander_points_1)
		2:
			spawn_chipling(2, chipling_spawns_2, chipling_wander_points_2)


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
func _on_debug_boss_trigger_body_entered(body: Node3D) -> void:
	if body is Player:
		for i in range(chiplings_to_spawn_2):
			spawn_chipling(2, chipling_spawns_2, chipling_wander_points_2)
			await get_tree().create_timer(0.2).timeout
	$DEBUGBossTrigger.queue_free()
