extends Control
class_name SkillTreeUI

@export var sfx_open: AudioStream
@export var first_item_focus: SkillItemUI

@onready var skill_title_label: Label = $SkillInfo/Title
@onready var skill_description_label: RichTextLabel = $SkillInfo/Description
@onready var skill_point_label: Label = $SkillTreeView/SkillPointLabel
@onready var level_label: Label = $SkillTreeView/LevelLabel
@onready var level_up_button: Button = $LevelUpButton
@onready var reset_button: Button = $ResetButton
@onready var reset_timer: Timer = $ResetTimer


signal ui_opened

var level_up_btn_clicked_once = false
var reset_btn_clicked_once = false

func _ready() -> void:
	visible = false


func toggle():
	SoundManager.play_sound(sfx_open, "SFX")
	refresh_all_items()
	if visible:
		close()
	else:
		open()

func _unhandled_input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()

func open():
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	GameManager.player.is_in_menu = true
	update_description("", "")
	get_first_item_for_focus()
	skill_point_label.text = "Points left: {0}".format([GameManager.player_skill_points])
	reset_button.text = "Reset all skills"
	update_level_up_button_text()
	ui_opened.emit()


func close():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.player.is_in_menu = false
	visible = false


func update_level_up_button_text():
	var next_level_cost = GameManager.player_level * GameManager.CHIP_COST_PER_LEVEL_UP
	level_up_button.text = "Level up to {0} ({1} chips)".format([GameManager.player_level + 1, next_level_cost])

func refresh_all_items():
	level_up_btn_clicked_once = false
	reset_btn_clicked_once = false
	skill_point_label.text = "Points left: {0}".format([GameManager.player_skill_points])
	var new_high_luck_theshold = (GameManager.BASE_PLAYER_LUCK_THRESHOLD * 100) - (GameManager.player_level - 1)
	level_label.text = "Level: {0}\nHigh luck threshold: {1}%".format([GameManager.player_level, new_high_luck_theshold])
	update_level_up_button_text()
	reset_button.text = "Reset all skills"
	ui_opened.emit()

func update_description(title: String, description: String):
	skill_title_label.text = title
	skill_description_label.text = description

func reset_skill_points():
	var allocated_points = 0
	for skill in GameManager.player_skill_dict:
		allocated_points += GameManager.player_skill_dict[skill]
	GameManager.player_skill_points += allocated_points
	GameManager.player_skill_dict = {}
	refresh_all_items()
	GameManager.player.check_permanent_buffs()
	GameManager.player.luck_component.check_for_high_luck_buffs()

	
func get_first_item_for_focus():
	await get_tree().create_timer(0.02).timeout
	first_item_focus.button.grab_focus()


func _on_reset_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	if not reset_btn_clicked_once:
		refresh_all_items()
		reset_timer.start(3)
		reset_btn_clicked_once = true
		reset_button.text = "Confirm reset?"
	else:
		reset_skill_points()
		refresh_all_items()
		reset_timer.stop()

func _on_return_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	close()


func _on_level_up_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	var next_level_cost = GameManager.player_level * GameManager.CHIP_COST_PER_LEVEL_UP
	if GameManager.player_currency >= next_level_cost:
		if not level_up_btn_clicked_once:
			refresh_all_items()
			reset_timer.start(3)
			level_up_btn_clicked_once = true
			level_up_button.text = "Confirm? (Cost {0} chips)".format([next_level_cost])
		else:
			GameManager.player_currency -= next_level_cost
			GameManager.player_level += 1
			GameManager.player_skill_points += 1
			refresh_all_items()
			reset_timer.stop()
	else:
		level_up_button.text = "Not enough chips!"
		reset_timer.start(3)


func _on_reset_timer_timeout() -> void:
	refresh_all_items()
