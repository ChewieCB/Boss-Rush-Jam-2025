extends Node3D

@export var bgm: AudioStream
@export var elevator_doors: ElevatorDoors
@export var elevator_buttons: Array[ElevatorButton]

var display_barrels: Array = []


func _ready() -> void:
	get_tree().paused = false
	SoundManager.play_music(bgm, 0.25)
	for button in elevator_buttons:
		button.pushed.connect(_on_level_select)
	for node in $DisplayBarrels.get_children():
		var model = node.get_node("Model")
		model.rotation_degrees.y = randf_range(0, 360)
		display_barrels.append(model)


func _process(delta: float) -> void:
	for node in display_barrels:
		node.rotation.y += delta


func _on_level_select(level_path: String) -> void:
	ResourceLoader.load_threaded_request(level_path)
	elevator_doors.close()
	await elevator_doors.anim_player.animation_finished
	# Wait until the level has been loaded on another thread
	while ResourceLoader.load_threaded_get_status(level_path) != ResourceLoader.THREAD_LOAD_LOADED:
		pass
	var loaded_scene = ResourceLoader.load_threaded_get(level_path)
	# HACK - do this properly with dynamic loading of scenes
	# Get the player's position relative to the elevator doors
	GameManager.cached_player_pos_relative_to_elevator_doors = elevator_doors.global_position - GameManager.player.global_position
	GameManager.cached_player_rotation = GameManager.player.rotation
	GameManager.cached_camera_rotation = GameManager.player.player_camera.rotation
	var new_bgm = loaded_scene.get_state().get_node_property_value(0, 1)
	SoundManager.play_music(new_bgm, 0.25)
	if is_inside_tree():
		get_tree().change_scene_to_packed(loaded_scene)


func _on_door_transition_area_body_entered(body: Node3D) -> void:
	if body is Player:
		elevator_doors.open()


func _on_door_transition_area_body_exited(body: Node3D) -> void:
	if body is Player:
		elevator_doors.close()
