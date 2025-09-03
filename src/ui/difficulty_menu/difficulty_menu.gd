extends Control
class_name DifficultyMenu

@export var chip_sfx: AudioStream
## Order matter
@export var boss_sprites: Array[TextureRect]
@export var boss_diff_profiles: Array[BossDifficultyProfile]

@onready var risk_level_container: Container = $TitleRegion/HBoxContainer
@onready var risk_item_container: Container = $LeftRegion/RiskContainer
@onready var bet_value_label: Label = $RightRegion/Bet/BetInfo/BetValue
@onready var reward_label: Label = $RightRegion/Reward/RewardInfo/RewardValue
@onready var start_button: TemplateButton = $LeftRegion/HBoxContainer/StartButton
@onready var not_enough_chip_timer: Timer = $NotEnoughChipTimer
@onready var bet_chip_sprite: TextureRect = $RightRegion/Bet/BetInfo/TextureRect
@onready var reward_chip_sprite: TextureRect = $RightRegion/Reward/RewardInfo/TextureRect
@onready var reset_risk_button: Button = $LeftRegion/ResetRiskButton
@onready var target_quite_label: Label = $TitleRegion/TargetLabel/TargetQuoteLabel
@onready var ante_card_container: Control = $RightRegion/AnteSection

signal bet_started
signal bet_cancelled
signal risk_changed

const BASE_REWARD_MULT = 1.5
const REWARD_MULT_PER_RISK = 0.05 # Extra 5% per risk lv
const HIGH_RISK_REWARD_MULT_PER_RISK = 0.15
const HIGH_RISK_THRESHOLD = 9
const OVER_RISK_REWARD_MULT_PER_RISK = 0.4
const OVER_RISK_THRESHOLD = 15

# const RISK_THRESHOLDS = [0, 3, 6, 9, 12, 15]
# const RISK_REWARD_MULT_PER_RISKS = [0.05, 0.1, 0.2, 0.25, 0.3, 0.4]

var bet_value: int = 0
var reward_value: int = 0
var bet_sprite_scale_tween = null
var reward_sprite_scale_tween = null
var is_controller_connected: bool = false
var locked: bool = false

func _ready() -> void:
	visible = false
	set_risk_level(0)
	GameManager.difficulty_menu = self
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.risk_level_changed.connect(_on_risk_level_changed)
	_on_risk_level_changed()
	is_controller_connected = Input.get_connected_joypads() != []


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("ui_cancel"):
			hide_menu()
			get_viewport().set_input_as_handled()

func show_menu():
	if locked:
		return
	visible = true
	GameManager.player.is_in_menu = true
	if not is_controller_connected:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	start_button.grab_focus()
	bet_value = GameManager.risk_level * 1000
	update_bet_and_reward_value()

	refresh_display()


func hide_menu():
	visible = false
	GameManager.player.is_in_menu = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func refresh_display():
	for elem in boss_sprites:
		elem.visible = false
	var boss_profile = boss_diff_profiles[int(GameManager.selected_boss_id) - 1]
	boss_sprites[int(GameManager.selected_boss_id) - 1].visible = true
	target_quite_label.text = boss_profile.boss_quote

	for i in range(ante_card_container.get_child_count()):
		var ante_item: AnteItem = ante_card_container.get_child(i)
		ante_item.set_ante_label(boss_profile.ante_names[i])

	bet_value_label.text = format_number_with_commas(bet_value)
	reward_label.text = format_number_with_commas(reward_value)
	
## Max lv 15
func set_risk_level(level: int):
	for i in range(risk_level_container.get_child_count()):
		if i < level:
			risk_level_container.get_child(i).self_modulate = Color.WHITE
			if i >= 15:
				risk_level_container.get_child(i).visible = true
				risk_level_container.get_child(i).get_child(0).text = str(level - 15)

		else:
			risk_level_container.get_child(i).self_modulate = Color.BLACK
			if i >= 15:
				risk_level_container.get_child(i).visible = false
	play_juicy_chip_sprite_anim()

func _on_risk_level_changed():
	update_bet_and_reward_value()
	bet_value_label.text = format_number_with_commas(bet_value)
	reward_label.text = format_number_with_commas(reward_value)
	start_button.text = "Start"
	start_button.set_text_color(Color.WHITE)
	if GameManager.risk_level > 0:
		reset_risk_button.visible = true
	else:
		reset_risk_button.visible = false

func update_bet_and_reward_value():
	bet_value = GameManager.risk_level * 1000
	var payout_mult = BASE_REWARD_MULT + ((GameManager.risk_level - 1) * REWARD_MULT_PER_RISK)
	if GameManager.risk_level >= HIGH_RISK_THRESHOLD:
		payout_mult = BASE_REWARD_MULT + ((GameManager.risk_level - 1) * HIGH_RISK_REWARD_MULT_PER_RISK)
	elif GameManager.risk_level >= OVER_RISK_THRESHOLD:
		payout_mult = BASE_REWARD_MULT + ((GameManager.risk_level - 1) * OVER_RISK_REWARD_MULT_PER_RISK)
	reward_value = int(bet_value * payout_mult * boss_diff_profiles[int(GameManager.selected_boss_id) - 1].boss_risk_reward_mult)

func format_number_with_commas(n: int) -> String:
	var str_n = str(n)
	var result = ""
	var count = 0
	for i in range(str_n.length() - 1, -1, -1):
		result = str_n[i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = "," + result
	return result

func _on_reset_risk_button_pressed() -> void:
	GameManager.reset_difficulty_modifier()
	for elem in risk_item_container.get_children():
		var risk_item = elem as RiskItem
		risk_item.refresh_value_label()

func _on_start_button_pressed() -> void:
	if GameManager.player_currency < bet_value:
		start_button.text = "Not enough chips!"
		start_button.set_text_color(Color.RED)
		not_enough_chip_timer.start()
	else:
		hide_menu()
		locked = true
		GameManager.bet_value = bet_value
		GameManager.reward_value = reward_value
		GameManager.player_currency -= bet_value
		bet_started.emit()


func _on_cancel_button_pressed() -> void:
	hide_menu()
	bet_cancelled.emit()


func _on_not_enough_chip_timer_timeout() -> void:
	start_button.text = "Start"
	start_button.set_text_color(Color.WHITE)

func play_juicy_chip_sprite_anim():
	if bet_sprite_scale_tween and bet_sprite_scale_tween.is_running():
		bet_sprite_scale_tween.stop()
	bet_sprite_scale_tween = get_tree().create_tween()
	bet_chip_sprite.custom_minimum_size = Vector2(96, 96) * 1.4
	bet_sprite_scale_tween.tween_property(bet_chip_sprite, "custom_minimum_size", Vector2(96, 96), 0.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

	if reward_sprite_scale_tween and reward_sprite_scale_tween.is_running():
		reward_sprite_scale_tween.stop()
	reward_sprite_scale_tween = get_tree().create_tween()
	reward_chip_sprite.custom_minimum_size = Vector2(96, 96) * 1.4
	reward_sprite_scale_tween.tween_property(reward_chip_sprite, "custom_minimum_size", Vector2(96, 96), 0.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

	var pitch = randf_range(0.8, 1.2)
	SoundManager.play_ui_sound_with_pitch(chip_sfx, pitch)
