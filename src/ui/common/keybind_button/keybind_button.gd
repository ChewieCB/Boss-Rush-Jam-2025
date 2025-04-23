extends Container
class_name KeybindButton

# PLAN: Mapping for Switch and PS5

@onready var action_label: Label = $HBoxContainer/ActionLabel
@onready var kbm_button: Button = $HBoxContainer/KBMButton
@onready var kbm_key_icon: DeviceInputPrompt = $HBoxContainer/KBMButton/DeviceInputPrompt
@onready var controller_button: Button = $HBoxContainer/ControllerButton
@onready var controller_key_icon: DeviceInputPrompt = $HBoxContainer/ControllerButton/DeviceInputPrompt
@onready var controller_button_border: Control = $HBoxContainer/ControllerButton/NinePatchRect

var assigned_action_name: String # something like "shoot" or "move_up"
var setting_ui: SettingUI

var banned_controller_keybind_action = [
	"move_up",
	"move_down",
	"move_left",
	"move_right",
]


func _ready() -> void:
	InputHelper.keyboard_input_changed.connect(_on_input_changed)
	InputHelper.joypad_input_changed.connect(_on_input_changed)
	kbm_button.mouse_entered.connect(play_button_hover_sfx)
	kbm_button.focus_entered.connect(play_button_hover_sfx)
	controller_button.mouse_entered.connect(play_button_hover_sfx)
	controller_button.focus_entered.connect(play_button_hover_sfx)

func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()


func _on_input_changed(action: String, _input: InputEvent):
	if assigned_action_name == action:
		update_button_detail()

func set_changing_keybind_text(text: String, is_controller = false) -> void:
	if is_controller:
		controller_key_icon.texture = null
		controller_button.text = text
	else:
		kbm_key_icon.texture = null
		kbm_button.text = text

## Update icon for input. If failed, use text instead
func update_button_detail() -> void:
	if assigned_action_name == "":
		return

	update_kbm_icon()
	update_controller_icon()

	controller_button_border.visible = true
	if assigned_action_name in banned_controller_keybind_action:
		controller_button.disabled = true
		controller_key_icon.modulate = Color.DARK_GRAY
		controller_button_border.visible = false

func update_kbm_icon():
	kbm_key_icon.assigned_action = assigned_action_name
	kbm_key_icon.update_texture()
	if kbm_key_icon.texture == null:
		var kbm_event = InputHelper.get_keyboard_input_for_action(assigned_action_name)
		kbm_button.text = InputHelper.get_label_for_input(kbm_event).to_lower()


func update_controller_icon():
	controller_key_icon.assigned_action = assigned_action_name
	controller_key_icon.update_texture()
	if controller_key_icon.texture == null:
		var controller_event = InputHelper.get_joypad_input_for_action(assigned_action_name)
		controller_button.text = InputHelper.get_label_for_input(controller_event).to_lower()