extends Control

@onready var anim_player: AnimationPlayer = $AnimationPlayer



func hurt() -> void:
	anim_player.play("hurt")


func dead() -> void:
	anim_player.play("dead")
