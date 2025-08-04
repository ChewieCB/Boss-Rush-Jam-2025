extends Control
class_name DifficultyMenu

@onready var risk_level_container: Container = $TitleRegion/HBoxContainer
@onready var risk_item_container: Container = $LeftRegion/RiskContainer
@onready var bet_value_label: Label = $RightRegion/Bet/BetInfo/BetValue
@onready var reward_label: Label = $RightRegion/Reward/RewardInfo/RewardValue
@onready var start_button: TemplateButton = $LeftRegion/StartButton
@onready var not_enough_chip_timer: Timer = $NotEnoughChipTimer

var bet_value = 0
var reward_value = 0


func _ready() -> void:
	set_risk_level(0)
	GameManager.difficulty_menu = self
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.risk_level_changed.connect(_on_risk_level_changed)
	_on_risk_level_changed()

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
			

func _on_risk_level_changed():
	bet_value = GameManager.risk_level * 1000
	var payout_mult = 2 + ((GameManager.risk_level - 1) * 0.05) # Extra 5% per risk lv
	reward_value = bet_value * payout_mult
	bet_value_label.text = format_number_with_commas(bet_value)
	reward_label.text = format_number_with_commas(int(reward_value))

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


func _on_not_enough_chip_timer_timeout() -> void:
	start_button.text = "Start"
	start_button.set_text_color(Color.WHITE)
