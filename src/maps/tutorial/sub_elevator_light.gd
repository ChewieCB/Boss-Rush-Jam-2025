extends Node3D

@onready var anim_player := $AnimationPlayer


func red() -> void:
	anim_player.play("red")


func yellow() -> void:
	anim_player.play("yellow")


func green() -> void:
	anim_player.play("green")


func reset() -> void:
	anim_player.play("RESET")
