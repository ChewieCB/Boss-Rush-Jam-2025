extends BossMap

signal ui_accept

@export var boss_doors: ElevatorDoors
@export var exit_doors: SlidingDoor
@export var info_ui_prefab: PackedScene

@export var exit_elevator_button: Area3D
@export var lobby_entry_elevator: Node3D

@export var boss_intro_spawn: Marker3D
@export var boss_laser_spawn_markers: Array[Marker3D]
@onready var elevator_spawns: Array[Node] = get_tree().get_nodes_in_group("boss_elevator_spawn_marker")
@onready var boss_origin: Array[Node] = get_tree().get_nodes_in_group("boss_arena_origin_marker")
@export var sub_elevator_doors: Array[SlidingDoor]
@export var sub_elevator_lights: Array[Node3D]


func _ready() -> void:
	#GameManager.equipped_barrels = []
	#player.gun.reinstall_barrels()
	# FIXME - workaround
	elevator_doors = lobby_entry_elevator

	super()
	if GameManager.cached_player_rotation:
		player.global_position = elevator_doors.global_position - Vector3(0, 0, 1.5)
		player.global_rotation.y = PI

	if boss_doors:
		boss_doors.close()

	boss.boss_origin = boss_origin[0]
	boss.elevator_spawns = elevator_spawns
	boss.sub_elevator_doors = sub_elevator_doors
	boss.sub_elevator_lights = sub_elevator_lights
	boss.intro_spawn_marker = boss_intro_spawn
	boss.laser_spawn_markers = boss_laser_spawn_markers
	boss.global_position = boss_intro_spawn.global_position
