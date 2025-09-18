extends Node3D

@onready var anim_player := $AnimationPlayer
@onready var light := $OmniLight3D


func red() -> void:
	anim_player.play("red")
	light.light_color = Color("ff2121")


func yellow() -> void:
	anim_player.play("yellow")
	light.light_color = Color("ffc421")


func green() -> void:
	anim_player.play("green")
	light.light_color = Color("33db1d")


func reset() -> void:
	anim_player.play("RESET")
	light.light_color = Color.WHITE
