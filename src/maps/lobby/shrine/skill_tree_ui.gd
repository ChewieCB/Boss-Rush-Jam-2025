extends Control
class_name SkillTreeUI

@export var sfx_open: AudioStream

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
	# get_first_item_for_focus()


func close():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.player.is_in_inventory = false
	visible = false
