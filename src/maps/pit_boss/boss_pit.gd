extends Node3D

@export var bgm: AudioStream

@onready var boss: BossCore = find_children("*", "BossCore").front()
@onready var player: Player = find_children("*", "Player").front()
@onready var elevator_doors: ElevatorDoors = find_children("*", "ElevatorDoors").front()


func _ready() -> void:
	#boss.health_component.died.connect(_on_boss_defeated)
	#player.health_component.died.connect(_on_player_death)
	
	if GameManager.cached_player_pos_relative_to_elevator_doors:
		var player_start_pos: Vector3 = elevator_doors.global_position - GameManager.cached_player_pos_relative_to_elevator_doors
		player.global_position = player_start_pos
		player.rotation = GameManager.cached_player_rotation
		player.player_camera.rotation = GameManager.cached_camera_rotation
	
	elevator_doors.open()
