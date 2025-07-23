extends RigidBody3D
class_name PokerChip

@export var value_array: Array[int] = [1, 2, 5, 10, 25, 50, 100]
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
	# 5% chip 1
	# 5% chip 2
	# 25% chip 5
	# 35% chip 10
	# 15% chip 25
	# 10% chip 50
	# 5% chip 100
	for i in randi_range(0, 99):
		if i < 5:
			chosen_idx = 0
		elif i < 10:
			chosen_idx = 1
		elif i < 35:
			chosen_idx = 2
		elif i < 70:
			chosen_idx = 3
		elif i < 85:
			chosen_idx = 4
		elif i < 95:
			chosen_idx = 5
		else:
			chosen_idx = 6

	if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.JACKPOT):
		var min_chosen_idx = GameManager.player_skill_dict[SkillItemUI.SkillIdEnum.JACKPOT]
		if chosen_idx < min_chosen_idx:
			chosen_idx = min_chosen_idx

	sprite.texture = sprite_array[chosen_idx]
	# Little hack to make chip value 1 slightly different from chip value 2
	if chosen_idx == 1:
		sprite.modulate = Color.GRAY
	value = value_array[chosen_idx]
	value_label_1.text = str(value)
	value_label_2.text = str(value)

	add_to_group("currency_chips")


func _process(delta: float) -> void:
	sprite.rotate(Vector3(0, 1, 0), SPIN_RATE * delta)


func _on_collect() -> void:
	GameManager.player_currency += value
	SoundManager.play_sound_with_pitch(sfx_pickup.pick_random(), randf_range(0.8, 1.1), "SFX")
	if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.BLESSED_CHIP):
		var bonus_luck = 0
		match GameManager.player_skill_dict[SkillItemUI.SkillIdEnum.BLESSED_CHIP]:
			1:
				bonus_luck = 1
			2:
				bonus_luck = 2
			3:
				bonus_luck = 3
			4:
				bonus_luck = 4
		GameManager.player.luck_component.current_luck += bonus_luck
	queue_free()


func _on_pickup_area_body_entered(body: Node3D) -> void:
	if body is Player:
		var tween = get_tree().create_tween()
		set_linear_velocity(Vector3.ZERO)
		freeze = true
		tween.tween_property(sprite, "global_position", body.global_position, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(_on_collect)
