extends Node3D

@export var bgm: AudioStream

@export var boss: BossCore
@export var player: Player
@export var elevator_doors: ElevatorDoors
@export var floor_pivot: AnimatableBody3D
# Floor segments array stores tuples of [mesh, collider] since we separate them
# for the purposes of the AnimatableBody3D rotation
@export var floor_segments: Array

@onready var win_ui: Control = $UI/BossDefeatedUI
@onready var boss_trigger: Area3D = $BossTriggerVolume

func _ready() -> void:
	#boss.health_component.died.connect(_on_boss_defeated)
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
		
		floor_segments.append([mesh, new_collider])
	
	if GameManager.cached_player_pos_relative_to_elevator_doors:
		var player_start_pos: Vector3 = elevator_doors.global_position - GameManager.cached_player_pos_relative_to_elevator_doors
		player.global_position = player_start_pos
		player.rotation = GameManager.cached_player_rotation
		player.player_camera.rotation = GameManager.cached_camera_rotation
	
	elevator_doors.open()


func _physics_process(delta) -> void:
	floor_pivot.rotation.y += delta
	
	if Input.is_action_just_released("interact"):
		if floor_segments.size() > 0:
			var idx: int = randi_range(0, floor_segments.size() - 1)
			var segment_arr = floor_segments[idx]
			floor_segments.remove_at(idx)
			drop_floor_segment(segment_arr)


func drop_floor_segment(segment_arr: Array) -> void:
	var mesh: MeshInstance3D = segment_arr[0]
	var collider: CollisionShape3D = segment_arr[1]
	collider.disabled = true
	var tween = get_tree().create_tween()
	tween.tween_property(mesh, "position:y", mesh.position.y - 20.0, 0.6)
	tween.tween_callback(mesh.queue_free)
	tween.tween_callback(collider.queue_free)


func _on_boss_defeated() -> void:
	pass
	win_ui.win()
	show_end_panel()


func _on_player_death() -> void:
	pass
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
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://src/maps/lobby/Lobby.tscn"))


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
