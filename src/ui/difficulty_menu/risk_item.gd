@tool
extends HBoxContainer
class_name RiskItem

enum RiskModifierEnum {
	NONE,
	INCREASE_BOSS_HP,
	INCREASE_BOSS_DMG,
	INCREASE_BOSS_MOVE_ATK_SPEED,
	INCREASE_BOSS_STATUS_RESIST,
	INCREASE_PLAYER_SPIN_COST,
	REDUCE_PLAYER_HEALING,
	REDUCE_PLAYER_LUCK_BUILD_UP,
	LIMIT_PLAYER_SPIN_AMOUNT,
	LIMIT_FIGHT_TIME
}

@export var risk_modifier: RiskModifierEnum
@export var risk_description: String
@export var prefix_value_text: String = ""
@export var value_unit_text: String = "%"
@export var icon_sprite: Texture2D

@onready var name_label: Label = $RiskName
@onready var value_label: Label = $ModifyValue
@onready var risk_icon: TextureRect = $RiskIcon

const STARTING_MAX_LIMIT_PLAYER_SPIN_AMOUNT = 10
const STARTING_MAX_LIMIT_FIGHT_TIME = 5

static var risk_value_per_level_dict = {
	RiskModifierEnum.NONE: 0,
	RiskModifierEnum.INCREASE_BOSS_HP: 0.5, # Mean 50% each lv
	RiskModifierEnum.INCREASE_BOSS_DMG: 0.25,
	RiskModifierEnum.INCREASE_BOSS_MOVE_ATK_SPEED: 0.2,
	RiskModifierEnum.INCREASE_BOSS_STATUS_RESIST: 0.25,
	RiskModifierEnum.INCREASE_PLAYER_SPIN_COST: 0.25,
	RiskModifierEnum.REDUCE_PLAYER_HEALING: 0.25,
	RiskModifierEnum.REDUCE_PLAYER_LUCK_BUILD_UP: 0.25,
	RiskModifierEnum.LIMIT_PLAYER_SPIN_AMOUNT: 3, # 3 times each lv
	RiskModifierEnum.LIMIT_FIGHT_TIME: 1 # 1 min each lv
}

static var max_risk_level_dict = {
	RiskModifierEnum.NONE: 0,
	RiskModifierEnum.INCREASE_BOSS_HP: 10,
	RiskModifierEnum.INCREASE_BOSS_DMG: 10,
	RiskModifierEnum.INCREASE_BOSS_MOVE_ATK_SPEED: 10,
	RiskModifierEnum.INCREASE_BOSS_STATUS_RESIST: 10,
	RiskModifierEnum.INCREASE_PLAYER_SPIN_COST: 10,
	RiskModifierEnum.REDUCE_PLAYER_HEALING: 4,
	RiskModifierEnum.REDUCE_PLAYER_LUCK_BUILD_UP: 4,
	RiskModifierEnum.LIMIT_PLAYER_SPIN_AMOUNT: 4,
	RiskModifierEnum.LIMIT_FIGHT_TIME: 3
}

func _ready() -> void:
	name_label.text = risk_description
	risk_icon.texture = icon_sprite

	if not Engine.is_editor_hint():
		await get_tree().process_frame
		await get_tree().process_frame
		refresh_value_label()


func refresh_value_label():
	var value = GameManager.risk_modifier_level_dict[risk_modifier] * risk_value_per_level_dict[risk_modifier]
	if value_unit_text == "%":
		value *= 100
	match risk_modifier:
		RiskModifierEnum.LIMIT_PLAYER_SPIN_AMOUNT:
			if GameManager.risk_modifier_level_dict[risk_modifier] == 0:
				value = "Unlimited"
			else:
				value = STARTING_MAX_LIMIT_PLAYER_SPIN_AMOUNT - \
				((GameManager.risk_modifier_level_dict[risk_modifier] - 1) * risk_value_per_level_dict[risk_modifier])
		RiskModifierEnum.LIMIT_FIGHT_TIME:
			if GameManager.risk_modifier_level_dict[risk_modifier] == 0:
				value = "Unlimited"
			else:
				value = STARTING_MAX_LIMIT_FIGHT_TIME - \
				((GameManager.risk_modifier_level_dict[risk_modifier] - 1) * risk_value_per_level_dict[risk_modifier])

	if GameManager.risk_modifier_level_dict[risk_modifier] == 0:
		name_label.self_modulate = Color.WHITE
		value_label.self_modulate = Color.WHITE
	else:
		name_label.self_modulate = Color.RED
		value_label.self_modulate = Color.RED
	value_label.text = "{0} {1} {2}".format([prefix_value_text, value, value_unit_text])
	GameManager.difficulty_menu.set_risk_level(GameManager.risk_level)


func _on_plus_button_pressed() -> void:
	if GameManager.risk_modifier_level_dict[risk_modifier] < max_risk_level_dict[risk_modifier]:
		GameManager.risk_modifier_level_dict[risk_modifier] += 1
		GameManager.risk_level += 1
	refresh_value_label()

func _on_minus_button_pressed() -> void:
	if GameManager.risk_modifier_level_dict[risk_modifier] > 0:
		GameManager.risk_modifier_level_dict[risk_modifier] -= 1
		GameManager.risk_level -= 1
	refresh_value_label()
