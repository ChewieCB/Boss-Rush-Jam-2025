extends Node3D

@export var bgm: AudioStream
@export var active_bgm: AudioStream

@onready var func_godot_parent: FuncGodotMap = $FuncGodotMap
@onready var worldspawn_mesh: StaticBody3D = func_godot_parent.find_child("entity_0_worldspawn")
@onready var win_ui: Control = $UI/BossDefeatedUI
@export var win_subtext: Array[String]
@export var lose_tips: Array[String]
#@onready var boss_trigger: Area3D = $BossTrigger

@onready var player: Player = find_children("*", "Player").front()
@onready var elevator_doors: ElevatorDoors = find_children("*", "ElevatorDoors").front()

#var nav_region: NavigationRegion3D
@export var directional_light: DirectionalLight3D

@export var breakable_floor: Node3D


func _ready() -> void:
	if GameManager.cached_player_pos_relative_to_elevator_doors:
		var player_start_pos: Vector3 = elevator_doors.global_position - GameManager.cached_player_pos_relative_to_elevator_doors
		player.global_position = player_start_pos
		player.rotation = GameManager.cached_player_rotation
		player.player_camera.rotation = GameManager.cached_camera_rotation
	
	elevator_doors.open()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("input_1"):
		if breakable_floor:
			breakable_floor.queue_free()
