extends Container
class_name KeybindButton

@onready var action_label: Label = $HBoxContainer/ActionLabel
@onready var kbm_button: Button = $HBoxContainer/KBMButton
@onready var kbm_key_icon: TextureRect = $HBoxContainer/KBMButton/TextureRect
@onready var controller_button: Button = $HBoxContainer/ControllerButton
@onready var controller_key_icon: TextureRect = $HBoxContainer/ControllerButton/TextureRect

var assigned_action_name: String # something like "shoot" or "move_up"
var setting_ui: SettingUI

var banned_controller_keybind_action = [
	"move_up",
	"move_down",
	"move_left",
	"move_right",
]

var inputname_to_icon_filename_mapping = {
	"mouse left button": "mouse_left",
	"mouse right button": "mouse_right",
	"mouse middle button": "mouse_scroll",
	"mouse button 4": "mouse_scroll_up",
	"mouse button 5": "mouse_scroll_down",
}

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


func update_button_detail() -> void:
	# Update icon for input. If failed, use text instead
	# NOTE: For now, just show text first.
	if assigned_action_name == "":
		return

	var kbm_event = InputHelper.get_keyboard_input_for_action(assigned_action_name)
	var kbm_input_label = InputHelper.get_label_for_input(kbm_event).to_lower()
	if inputname_to_icon_filename_mapping.has(kbm_input_label):
		kbm_input_label = inputname_to_icon_filename_mapping[kbm_input_label]
	else:
		kbm_input_label = "keyboard_" + kbm_input_label
	var kbm_icon_path = "res://assets/sprite/input/keyboard_and_mouse/{0}.png".format([kbm_input_label])
	if FileAccess.file_exists(kbm_icon_path):
		var texture = load(kbm_icon_path)
		kbm_key_icon.texture = texture
		kbm_button.text = ""
	else:
		push_warning("Failed to load texture at: %s" % kbm_icon_path)
		kbm_key_icon.texture = null
		kbm_button.text = InputHelper.get_label_for_input(kbm_event)

	var controller_event = InputHelper.get_joypad_input_for_action(assigned_action_name)
	controller_button.text = InputHelper.get_label_for_input(controller_event)

	if assigned_action_name in banned_controller_keybind_action:
		controller_button.disabled = true