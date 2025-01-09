extends Node3D
class_name ElevatorDoors

@export var TEMP_sfx_open: AudioStream
@export var TEMP_sfx_close: AudioStream
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func open() -> void:
	anim_player.play("open")
	SoundManager.play_sound(TEMP_sfx_open)


func close() -> void:
	anim_player.play("close")
	SoundManager.play_sound(TEMP_sfx_close)
