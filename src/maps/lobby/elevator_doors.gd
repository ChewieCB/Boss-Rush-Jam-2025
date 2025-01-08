extends Node3D
class_name ElevatorDoors

@onready var anim_player: AnimationPlayer = $AnimationPlayer


func open() -> void:
	anim_player.play("open")


func close() -> void:
	anim_player.play("close")
