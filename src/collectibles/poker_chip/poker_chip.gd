extends RigidBody3D
class_name PokerChip

signal collected(chip: PokerChip, value: int)
signal finished

@export var value_array: Array[int] = [1, 2, 5, 10, 25, 50, 100]
@export var chance_array: Array[int] = [5, 5, 25, 35, 15, 10, 5]
@export var sprite_array: Array[Texture2D] = []
@export var sfx_pickup: Array[AudioStream]
@export var sfx_spark: Array[AudioStream]

@onready var sprite: Sprite3D = $Sprite3D
@onready var value_label_1: Label3D = $Sprite3D/Label3D
@onready var value_label_2: Label3D = $Sprite3D/Label3D2
@onready var col: CollisionShape3D = $CollisionShape3D
@onready var spark_particles: GPUParticles3D = $StackSpark
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer

var chosen_idx: int = -1
var value: int = 0
var _chip_value_bag: Array[int] = []

const SPIN_RATE: int = 5

var collecting_by_player: bool = false
var absorbing_by_boss: bool = false


func _ready() -> void:
	add_to_group("currency_chips")
	randomise_chip_value()


func _sum_int_arr(arr: Array[int], end: int = 0x7FFFFFFF) -> int:
	var result: int = 0
	var _slice = arr.slice(0, end)
	for i in _slice:
		result += i
	
	return result


func _refill_chip_bag() -> void:
	_chip_value_bag.clear()
	for idx in chance_array.size():
		for i in chance_array[idx]:
			_chip_value_bag.append(idx)
	_chip_value_bag.shuffle()


func randomise_chip_value_from_bag() -> int:
	if _chip_value_bag.is_empty():
		_refill_chip_bag()
	return _chip_value_bag.pop_back()


# OLD method, wider variance
func randomise_chip_value() -> int:
	var roll: int = randi_range(0, 99)
	for i in range(0, 6):
		if roll < _sum_int_arr(chance_array, i + 1):
			return i
	return 6


func set_value(high_variance: bool = false) -> void:
	chosen_idx = randomise_chip_value() if high_variance else randomise_chip_value_from_bag()
	
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


#func _physics_process(delta: float) -> void:
	#if self.linear_velocity.length() < 0.05 and not self.freeze:
		#self.linear_velocity = Vector3.ZERO
		#self.angular_velocity = Vector3.ZERO
		#deactivate(false)


func _process(delta: float) -> void:
	sprite.rotate(Vector3(0, 1, 0), SPIN_RATE * delta)


func _on_collect() -> void:
	GameManager.player_currency += value
	SoundManager.play_sound_with_pitch(sfx_pickup.pick_random(), randf_range(0.8, 1.1), "SFX")
	if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.BLESSED_CHIP):
		var bonus_luck = 0
		match int(GameManager.player_skill_dict[SkillItemUI.SkillIdEnum.BLESSED_CHIP]):
			1:
				bonus_luck = 1
			2:
				bonus_luck = 2
			3:
				bonus_luck = 3
			4:
				bonus_luck = 4
		GameManager.player.luck_component.current_luck += bonus_luck
	
	finished.emit()
	deactivate()


func _on_pickup_area_body_entered(body: Node3D) -> void:
	if absorbing_by_boss:
		return
	
	if body is Player:
		activate()
		collecting_by_player = true
		var tween = get_tree().create_tween()
		set_linear_velocity(Vector3.ZERO)
		collected.emit(self, value)
		tween.tween_property(sprite, "global_position", body.global_position, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(_on_collect)


func activate() -> void:
	col.set_deferred("disabled", false)
	await get_tree().physics_frame
	self.process_mode = Node.PROCESS_MODE_INHERIT
	self.freeze = false
	self.visible = true


func spark() -> void:
	spark_particles.process_mode = Node.PROCESS_MODE_PAUSABLE
	sfx_player.stream = sfx_spark.pick_random()
	sfx_player.play()
	spark_particles.restart()
	await spark_particles.finished
	spark_particles.process_mode = Node.PROCESS_MODE_DISABLED


func deactivate(disable_process: bool = true, hide_sprite: bool = true) -> void:
	if hide_sprite:
		self.visible = false
	self.freeze = true
	col.set_deferred("disabled", true)
	if disable_process:
		self.process_mode = Node.PROCESS_MODE_DISABLED


func _on_visible_on_screen_notifier_3d_screen_entered() -> void:
	activate()


func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	deactivate(true, false)
