extends Container
class_name KeybindButton

# PLAN: Mapping for Switch and PS5

@onready var action_label: Label = $HBoxContainer/ActionLabel
@onready var kbm_button: Button = $HBoxContainer/KBMButton
@onready var kbm_key_icon: TextureRect = $HBoxContainer/KBMButton/TextureRect
@onready var controller_button: Button = $HBoxContainer/ControllerButton
@onready var controller_key_icon: TextureRect = $HBoxContainer/ControllerButton/TextureRect
@onready var controller_button_border: Control = $HBoxContainer/ControllerButton/NinePatchRect

var assigned_action_name: String # something like "shoot" or "move_up"
var setting_ui: SettingUI

var banned_controller_keybind_action = [
	"move_up",
	"move_down",
	"move_left",
	"move_right",
]

var kbm_input_icon_mapping = {
	"mouse left button": "mouse_left",
	"mouse right button": "mouse_right",
	"mouse middle button": "mouse_scroll",
	"mouse button 4": "mouse_scroll_up",
	"mouse button 5": "mouse_scroll_down",
	"up": "keyboard_arrows_up",
	"down": "keyboard_arrows_down",
	"left": "keyboard_arrows_left",
	"right": "keyboard_arrows_right",
	"equal": "keyboard_equals",
	"quoteleft": "keyboard_tilde",
	"braceleft": "keyboard_bracket_open",
	"braceright": "keyboard_bracket_close",
	"backslash": "keyboard_slash_back",
	"slash": "keyboard_slash_forward",
}

# use InputHelper's XBOX_BUTTON_LABELS
var xbox_input_icon_mapping = {
	"left stick up": "xbox_stick_l_up",
	"left stick down": "xbox_stick_l_down",
	"left stick left": "xbox_stick_l_left",
	"left stick right": "xbox_stick_l_right",
	"left stick button": "xbox_stick_side_l",
	"right stick up": "xbox_stick_r_up",
	"right stick down": "xbox_stick_r_down",
	"right stick left": "xbox_stick_r_left",
	"right stick right": "xbox_stick_r_right",
	"right stick button": "xbox_stick_side_r",
	"a button": "xbox_button_color_a",
	"b button": "xbox_button_color_b",
	"x button": "xbox_button_color_x",
	"y button": "xbox_button_color_y",
	"up button": "xbox_dpad_up",
	"down button": "xbox_dpad_down",
	"left button": "xbox_dpad_left",
	"right button": "xbox_dpad_right",
	"lb button": "xbox_lb",
	"rb button": "xbox_rb",
	"left trigger": "xbox_lt",
	"right trigger": "xbox_rt",
	"back button": "xbox_button_back_icon",
	"start button": "xbox_button_menu",
	"guide button": "xbox_guide",
}

# use InputHelper's PLAYSTATION_3_4_BUTTON_LABELS
var sony_input_icon_mapping = {
	"left stick up": "playstation_stick_l_up",
	"left stick down": "playstation_stick_l_down",
	"left stick left": "playstation_stick_l_left",
	"left stick right": "playstation_stick_l_right",
	"l3 button": "playstation_stick_side_l",
	"right stick up": "playstation_stick_r_up",
	"right stick down": "playstation_stick_r_down",
	"right stick left": "playstation_stick_r_left",
	"right stick right": "playstation_stick_r_right",
	"r3 button": "playstation_stick_side_r",
	"cross button": "playstation_button_color_cross",
	"circle button": "playstation_button_color_circle",
	"square button": "playstation_button_color_square",
	"triangle button": "playstation_button_color_triangle",
	"up button": "playstation_dpad_up",
	"down button": "playstation_dpad_down",
	"left button": "playstation_dpad_left",
	"right button": "playstation_dpad_right",
	"l1 button": "playstation_trigger_l1",
	"r1 button": "playstation_trigger_r1",
	"left trigger": "playstation_trigger_l2",
	"right trigger": "playstation_trigger_r2",
	"share button": "playstation4_button_share",
	"options button": "playstation4_button_options",
	"ps button": "",
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
	var kbm_event = InputHelper.get_keyboard_input_for_action(assigned_action_name)
	var kbm_input_label = InputHelper.get_label_for_input(kbm_event).to_lower()
	if kbm_input_icon_mapping.has(kbm_input_label):
		kbm_input_label = kbm_input_icon_mapping[kbm_input_label]
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


func update_controller_icon():
	var controller_event = InputHelper.get_joypad_input_for_action(assigned_action_name)
	var controller_input_label = InputHelper.get_label_for_input(controller_event).to_lower()

	# Decide what type of controller player is using
	var controller_icon_mapping = {}
	var icon_pathname = ""
	var device = ""
	# If no controller connected, force use xbox buttons icon
	if not setting_ui.is_controller_connected:
		device = "xbox"
	else:
		device = InputHelper.guess_device_name().to_lower()
	if device == "sony" or device == "playstation":
		controller_icon_mapping = sony_input_icon_mapping
		icon_pathname = "res://assets/sprite/input/sony/{0}.png"
	elif device == "xbox":
		controller_icon_mapping = xbox_input_icon_mapping
		icon_pathname = "res://assets/sprite/input/xbox/{0}.png"
	else:
		# Forcing using text instead of icon
		controller_icon_mapping = {}
		icon_pathname = "{0}"


	# Update icon
	if controller_icon_mapping.has(controller_input_label):
		controller_input_label = controller_icon_mapping[controller_input_label]
	else:
		controller_input_label = controller_input_label
	var controller_icon_path = icon_pathname.format([controller_input_label])
	if FileAccess.file_exists(controller_icon_path):
		var texture = load(controller_icon_path)
		controller_key_icon.texture = texture
		controller_button.text = ""
	else:
		push_warning("Failed to load texture at: %s" % controller_icon_path)
		controller_key_icon.texture = null
		controller_button.text = InputHelper.get_label_for_input(controller_event)
