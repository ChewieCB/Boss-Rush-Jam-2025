extends Control

@onready var anim_player: AnimationPlayer = $AnimationPlayer

@onready var vignette: ColorRect = $HurtVignette
@onready var stun_shader: ColorRect = $StunShader


func hurt() -> void:
	anim_player.play("hurt")


func stun(stun_time: float) -> void:
	var tween = get_tree().create_tween()
	vignette.modulate.a = 0
	stun_shader.modulate.a = 0
	tween.tween_property(vignette, "modulate:a", 255/4, 0.2)
	tween.parallel().tween_property(stun_shader, "modulate:a", 255/4, 0.2)
	await get_tree().create_timer(stun_time).timeout
	tween = get_tree().create_tween()
	tween.tween_property(vignette, "modulate:a", 0, 0.2)
	tween.parallel().tween_property(stun_shader, "modulate:a", 0, 0.2)


func dead() -> void:
	anim_player.play("dead")
