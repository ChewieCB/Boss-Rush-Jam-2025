extends RigidBody3D
class_name PokerChip

@export var value: int = 10
@export var sfx_pickup: Array[AudioStream]

@onready var sprite: Sprite3D = $Sprite3D


func _on_collect() -> void:
	GameManager.player_currency += value
	SoundManager.play_sound_with_pitch(sfx_pickup.pick_random(), randf_range(0.8, 1.1), "SFX")
	# TODO - sfx
	# TODO - particles
	queue_free()


func _on_pickup_area_body_entered(body: Node3D) -> void:
	if body is Player:
		var tween = get_tree().create_tween()
		set_linear_velocity(Vector3.ZERO)
		freeze = true
		tween.tween_property(sprite, "global_position", body.global_position, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(_on_collect)
