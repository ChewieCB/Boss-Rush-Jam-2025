extends Container
class_name KeybindButton

@onready var action_label: Label = $HBoxContainer/ActionLabel
@onready var kbm_button: Button = $HBoxContainer/KBMButton
@onready var controller_button: Button = $HBoxContainer/ControllerButton

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


func _on_input_changed(action: String, _input: InputEvent):
	if assigned_action_name == action:
		update_button_detail()


func update_button_detail():
	# Update icon for input. If failed, use text instead
	# NOTE: For now, just show text first.
	if assigned_action_name == "":
		return

	var kbm_event = InputHelper.get_keyboard_input_for_action(assigned_action_name)
	kbm_button.text = InputHelper.get_label_for_input(kbm_event)

	var controller_event = InputHelper.get_joypad_input_for_action(assigned_action_name)
	controller_button.text = InputHelper.get_label_for_input(controller_event)

	if assigned_action_name in banned_controller_keybind_action:
		controller_button.disabled = true