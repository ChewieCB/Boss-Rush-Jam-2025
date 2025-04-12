extends RigidBody3D
class_name PokerChip

@export var value_array: Array[int] = [1, 5, 10, 25, 100]
@export var sprite_array: Array[Texture2D] = []
@export var sfx_pickup: Array[AudioStream]

@onready var sprite: Sprite3D = $Sprite3D
@onready var value_label_1: Label3D = $Sprite3D/Label3D
@onready var value_label_2: Label3D = $Sprite3D/Label3D2

var chosen_idx = -1
var value = 0

const SPIN_RATE = 5

func _ready() -> void:
	# Roll random for chip value
	# 10% chip 1
	# 30% chip 5
	# 40% chip 10
	# 15% chip 25
	# 5% chip 100
	for i in randi_range(0, 99):
		if i < 10:
			chosen_idx = 0
		elif i < 40:
			chosen_idx = 1
		elif i < 80:
			chosen_idx = 2
		elif i < 95:
			chosen_idx = 3
		else:
			chosen_idx = 4
	sprite.texture = sprite_array[chosen_idx]
	value = value_array[chosen_idx]
	value_label_1.text = str(value)
	value_label_2.text = str(value)


func _process(delta: float) -> void:
	sprite.rotate(Vector3(0, 1, 0), SPIN_RATE * delta)


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


# DEBUG - comment to trigger git
