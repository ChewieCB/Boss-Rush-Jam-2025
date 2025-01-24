extends Node3D

@export var bgm: AudioStream

@export var boss: BossCore
@export var player: Player
@export var elevator_doors: ElevatorDoors
@export var floor_pivot: AnimatableBody3D
@export var ROTATION_SPEED: float = 0.0:
	set(value):
		ROTATION_SPEED = value
		boss.wheel_rotation_speed = ROTATION_SPEED
var goal_rotation_speed: float = ROTATION_SPEED : set = set_goal_rotation_speed
# Floor segments array stores tuples of [mesh, collider] since we separate them
# for the purposes of the AnimatableBody3D rotation
var floor_segments: Array

@onready var win_ui: Control = $UI/BossDefeatedUI
@onready var boss_trigger: Area3D = $BossTriggerVolume


func _ready() -> void:
	boss.defeated.connect(_on_boss_defeated)
	boss.change_wheel_speed.connect(set_goal_rotation_speed)
	player.health_component.died.connect(_on_player_death)
	
	# Build the animatable body's collision from each wheel segment collider
	for segment in floor_pivot.get_children():
		var static_body: StaticBody3D = segment.get_child(0)
		var mesh: MeshInstance3D = static_body.get_child(0)
		var collider: CollisionShape3D = static_body.get_child(2)
		var new_collider = collider.duplicate()
		floor_pivot.add_child(new_collider)
		new_collider.global_position += static_body.global_position
		collider.disabled = true
		
		floor_segments.append([mesh, new_collider, mesh.global_position.y])
	boss.floor_segments = floor_segments
	
	if GameManager.cached_player_pos_relative_to_elevator_doors:
		var player_start_pos: Vector3 = elevator_doors.global_position - GameManager.cached_player_pos_relative_to_elevator_doors
		player.global_position = player_start_pos
		player.rotation = GameManager.cached_player_rotation
		player.player_camera.rotation = GameManager.cached_camera_rotation
	
	elevator_doors.open()


func _physics_process(delta) -> void:
	if ROTATION_SPEED != goal_rotation_speed:
		ROTATION_SPEED = lerp(ROTATION_SPEED, goal_rotation_speed, delta)
	floor_pivot.rotation.y += ROTATION_SPEED * delta
	boss.wheel_rotation_speed = ROTATION_SPEED


func shove_player(shove_force: float = 25.0) -> void:
	var shove_vector = player.global_position.direction_to(boss.global_position)
	player.dash_disabled = true
	#player.velocity = Vector3.ZERO
	player.vel_horizontal += Vector2(shove_vector.x, shove_vector.z) * shove_force 
	player.vel_vertical += shove_vector.y * shove_force 
	await get_tree().create_timer(0.5).timeout
	player.dash_disabled = false


func set_goal_rotation_speed(value: float) -> void:
	goal_rotation_speed = value


func _on_boss_defeated(_boss: BossCore) -> void:
	win_ui.win()
	show_end_panel()


func _on_player_death() -> void:
	win_ui.lose()
	show_end_panel()


func show_end_panel() -> void:
	win_ui.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 1.0), 1.0)
	await tween.finished
	await get_tree().create_timer(5.0).timeout
	tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 0.0), 1.0)
	tween.tween_callback(_return_to_lobby)


func _return_to_lobby() -> void:
	get_tree().change_scene_to_file("res://src/maps/lobby/Lobby.tscn")

func _return_to_main() -> void:
	get_tree().change_scene_to_file("res://src/ui/temp/TempMain.tscn")


func _reload_scene() -> void:
	get_tree().reload_current_scene()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is BossCore:
		body.jump()


func _on_boss_trigger_volume_body_entered(body: Node3D) -> void:
	if body is Player:
		boss.activate()
		boss_trigger.queue_free()
		shove_player()


func _on_killbox_area_body_entered(body: Node3D) -> void:
	if body is RouletteBall:
		body.destroy()
	elif body.health_component:
		body.health_component.damage(9999999)
	else:
		body.queue_free()
