extends Node3D
class_name SlidingDoor

@export var is_open: bool = false
@export var TEMP_sfx_open: AudioStream
@export var TEMP_sfx_close: AudioStream
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if is_open:
		anim_player.play("open")


func open() -> void:
	anim_player.play("open")
	SoundManager.play_sound(TEMP_sfx_open)


func close() -> void:
	anim_player.play("close")
	SoundManager.play_sound(TEMP_sfx_close)


func _on_door_trigger_area_body_entered(body: Node3D) -> void:
	if body is Player:
		open()


func _on_door_trigger_area_body_exited(body: Node3D) -> void:
	if body is Player:
		close()
