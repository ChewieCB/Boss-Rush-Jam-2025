extends GPUParticles3D

@export var anim_player: AnimationPlayer



func spark() -> void:
	anim_player.play("spark")
	await anim_player.animation_finished
	return


func start_smoke() -> void:
	anim_player.play("smoke_start")
	await anim_player.animation_finished
	return


func end_smoke() -> void:
	anim_player.play("smoke_end")
	await anim_player.animation_finished
	return
