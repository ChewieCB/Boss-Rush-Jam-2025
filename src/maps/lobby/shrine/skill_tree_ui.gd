extends Control
class_name SkillTreeUI

@export var sfx_open: AudioStream
@export var first_item_focus: SkillItemUI

@onready var skill_title_label: Label = $SkillInfo/Title
@onready var skill_description_label: Label = $SkillInfo/Description
@onready var skill_point_label: Label = $SkillTreeView/SkillPointLabel

signal ui_opened

func _ready() -> void:
	visible = false


func toggle():
	SoundManager.play_sound(sfx_open, "SFX")
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
	GameManager.player.is_in_inventory = true
	update_description("", "")
	get_first_item_for_focus()
	skill_point_label.text = "Points left: {0}".format([GameManager.player_skill_points])
	ui_opened.emit()


func close():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.player.is_in_inventory = false
	visible = false


func refresh_all_items():
	skill_point_label.text = "Points left: {0}".format([GameManager.player_skill_points])
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

	
func get_first_item_for_focus():
	await get_tree().create_timer(0.02).timeout
	first_item_focus.button.grab_focus()


func _on_reset_button_pressed() -> void:
	reset_skill_points()

func _on_return_button_pressed() -> void:
	close()
