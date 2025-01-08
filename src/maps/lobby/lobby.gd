extends Node3D

@export var TEMP_bgm: AudioStream
@export var elevator_doors: ElevatorDoors
@export var elevator_buttons: Array[ElevatorButton]

var display_barrels: Array = []


func _ready() -> void:
	SoundManager.play_music(TEMP_bgm)
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
	elevator_doors.close()
	await elevator_doors.anim_player.animation_finished
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file(level_path)


func _on_door_transition_area_body_entered(body: Node3D) -> void:
	if body is Player:
		elevator_doors.open()


func _on_door_transition_area_body_exited(body: Node3D) -> void:
	if body is Player:
		elevator_doors.close()
