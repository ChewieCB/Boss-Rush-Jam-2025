extends Control
class_name DifficultyMenu

@onready var risk_level_container: Container = $TitleRegion/HBoxContainer
@onready var risk_item_container: Container = $LeftRegion/RiskContainer
@onready var bet_value_label: Label = $RightRegion/Bet/BetInfo/BetValue
@onready var reward_label: Label = $RightRegion/Reward/RewardInfo/RewardValue

func _ready() -> void:
	set_risk_level(0)
	GameManager.difficulty_menu = self
	for elem in risk_item_container.get_children():
		var risk_item = elem as RiskItem
		risk_item.risk_level_changed.connect(_on_risk_level_changed)
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
	var value = GameManager.risk_level * 1000
	var bonus_mult = 2 + ((GameManager.risk_level - 1) * 0.05) # Extra 5% per risk lv
	bet_value_label.text = format_number_with_commas(value)
	reward_label.text = format_number_with_commas(int(value * bonus_mult))

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
	GameManager.risk_modifier_level_dict = {
		RiskItem.RiskModifierEnum.INCREASE_BOSS_HP: 0,
		RiskItem.RiskModifierEnum.INCREASE_BOSS_DMG: 0,
		RiskItem.RiskModifierEnum.INCREASE_BOSS_MOVE_ATK_SPEED: 0,
		RiskItem.RiskModifierEnum.INCREASE_BOSS_STATUS_RESIST: 0,
		RiskItem.RiskModifierEnum.INCREASE_PLAYER_SPIN_COST: 0,
		RiskItem.RiskModifierEnum.REDUCE_PLAYER_HEALING: 0,
		RiskItem.RiskModifierEnum.REDUCE_PLAYER_LUCK_BUILD_UP: 0,
		RiskItem.RiskModifierEnum.LIMIT_PLAYER_SPIN_AMOUNT: 0,
		RiskItem.RiskModifierEnum.LIMIT_FIGHT_TIME: 0
	}
	GameManager.risk_level = 0
	GameManager.boss_ante = 1
	for elem in risk_item_container.get_children():
		var risk_item = elem as RiskItem
		risk_item.refresh_value_label()