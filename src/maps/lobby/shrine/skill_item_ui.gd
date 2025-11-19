extends TextureRect
class_name SkillItemUI

enum SkillIdEnum {
	NONE,
	HOT_HAND,
	LUCKY_SHOT,
	LUCKY_CRIT, # Inreased crit mult from 2.0x to 2.5x
	DOUBLE_DOWN,
	IOU,
	CHEAT_DEATH,
	POKER_FACE,
	BLINDSPOT,
	PLOT_ARMOR,
	JACKPOT,
	BLESSED_CHIP,
	HIGH_ROLLER # spin barrel with higher cost will restore more hp
}

@export var skill_name: String
@export_multiline var description: String
@export var skill_id_enum: SkillIdEnum
@export var max_level: int = 1
@export var prerequisite_skills: Array[SkillIdEnum]
## These paths will be highlighted after skill acquired
@export var highlight_paths: Array[TextureRect]
@export var learned_color: Color
@export var unlearnable_color: Color

@onready var button: Button = $Button
@onready var border_normal: Control = $BorderNormal
@onready var border_selected: Control = $BorderSelected
@onready var level_label: Label = $LevelLabel


var skill_tree_ui: SkillTreeUI
var clicked_once = false
var acquired = false
var scale_factor = 1.2

func _ready() -> void:
	skill_tree_ui = get_owner()
	skill_tree_ui.ui_opened.connect(reset)
	if max_level == 1:
		level_label.visible = false
	reset()

	button.mouse_entered.connect(expand_button_size)
	button.mouse_exited.connect(return_button_size)
	button.focus_entered.connect(expand_button_size)
	button.focus_exited.connect(return_button_size)

func reset():
	button.text = ""
	border_normal.visible = true
	border_selected.visible = false
	self_modulate = Color.WHITE
	border_normal.self_modulate = Color.WHITE
	border_selected.self_modulate = Color.WHITE
	clicked_once = false
	check_skill_status()

func check_skill_status():
	self_modulate = Color.WHITE
	level_label.self_modulate = Color.WHITE
	button.disabled = false
	for path in highlight_paths:
		path.self_modulate = unlearnable_color

	# Check if learned
	if GameManager.player_skill_dict.has(skill_id_enum):
		acquired = true
		self_modulate = learned_color
		level_label.text = "{0}/{1}".format([GameManager.player_skill_dict[skill_id_enum], max_level])
		for path in highlight_paths:
			path.self_modulate = Color.WHITE
		# Check if max levelled
		if GameManager.player_skill_dict[skill_id_enum] == max_level:
			button.disabled = true
			border_normal.visible = false
			border_selected.visible = true
			border_selected.self_modulate = learned_color
			level_label.self_modulate = learned_color
			return
		# Check if upgradable
		if GameManager.player_skill_points <= 0:
			button.disabled = true
			border_normal.visible = false
			return
	else:
		# Skill not yet learned
		level_label.text = "0/{0}".format([max_level])
		# Check prerequisite skills and skill points
		var unlearnable = false
		for skill in prerequisite_skills:
			if not GameManager.player_skill_dict.has(skill):
				unlearnable = true
		if unlearnable or GameManager.player_skill_points <= 0:
			self_modulate = unlearnable_color
			button.disabled = true
			border_normal.visible = false


func learn_skill():
	GameManager.player_skill_points -= 1
	if GameManager.player_skill_dict.has(skill_id_enum):
		GameManager.player_skill_dict[skill_id_enum] += 1
	else:
		GameManager.player_skill_dict[skill_id_enum] = 1
	button.disabled = true
	skill_tree_ui.refresh_all_items()
	GameManager.player.check_permanent_buffs()
	GameManager.player.luck_component.check_for_high_luck_buffs()

func _on_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	for skill in prerequisite_skills:
		if not GameManager.player_skill_dict.has(skill):
			return
		if GameManager.player_skill_points <= 0:
			return

	if not clicked_once:
		clicked_once = true
		if GameManager.player_skill_dict.has(skill_id_enum):
			button.text = "Upgrade?"
		else:
			button.text = "Acquired?"
		border_selected.visible = true
	else:
		learn_skill()

func _on_button_mouse_entered() -> void:
	SoundManager.play_button_hover_sfx()
	skill_tree_ui.update_description(skill_name, description)


func _on_button_focus_entered() -> void:
	SoundManager.play_button_hover_sfx()
	skill_tree_ui.update_description(skill_name, description)

func _on_button_mouse_exited() -> void:
	reset()

func _on_button_focus_exited() -> void:
	reset()

func expand_button_size():
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(scale_factor, scale_factor), 0.1)

func return_button_size():
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1)