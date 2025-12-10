extends TextureRect
class_name DeviceInputPrompt

enum DeviceType {
	AUTO,
	KEYBOARD_MOUSE,
	XBOX,
	SONY,
	STEAMDECK,
}

## Example: ui_action, ui_up, shoot, jump, reload
@export var assigned_action: String
## Set this to force display input icon from certain device. Otherwise leave at AUTO.
@export var device_type: DeviceType
@export var hide_background = false
# Force only show input type that is not KB/M. Aka it will show Xbox if no other controller detected.
@export var force_non_kbm = false

var kbm_input_icon_mapping = {
	"device_icon": "keyboard",
	"mouse left button": "mouse_left",
	"mouse right button": "mouse_right",
	"mouse middle button": "mouse_scroll",
	"mouse button 4": "mouse_scroll_up",
	"mouse button 5": "mouse_scroll_down",
	"move_generic": "keyboard_arrows",
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
	"device_icon": "controller_xboxseries",
	"move_generic": "xbox_stick_l",
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
	"device_icon": "controller_playstation5",
	"move_generic": "playstation_stick_l",
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

var steamdeck_input_icon_mapping = {
	"device_icon": "controller_steamdeck",
	"move_generic": "steamdeck_stick_l",
	"left stick up": "steamdeck_stick_l_up",
	"left stick down": "steamdeck_stick_l_down",
	"left stick left": "steamdeck_stick_l_left",
	"left stick right": "steamdeck_stick_l_right",
	"left stick button": "steamdeck_stick_l_press",
	"right stick up": "steamdeck_stick_r_up",
	"right stick down": "steamdeck_stick_r_down",
	"right stick left": "steamdeck_stick_r_left",
	"right stick right": "steamdeck_stick_r_right",
	"right stick button": "steamdeck_stick_r_press",
	"a button": "steamdeck_button_a",
	"b button": "steamdeck_button_b",
	"x button": "steamdeck_button_x",
	"y button": "steamdeck_button_y",
	"up button": "steamdeck_dpad_up",
	"down button": "steamdeck_dpad_down",
	"left button": "steamdeck_dpad_left",
	"right button": "steamdeck_dpad_right",
	"l1 button": "steamdeck_button_l1",
	"r1 button": "steamdeck_button_r1",
	"left trigger": "steamdeck_button_l2",
	"right trigger": "steamdeck_button_r2",
	"view button": "steamdeck_button_view",
	"options button": "steamdeck_button_options",
}

func _ready() -> void:
	InputHelper.keyboard_input_changed.connect(func(_action, _input_event): update_texture())
	InputHelper.joypad_input_changed.connect(func(_action, _input_event): update_texture())
	if device_type == DeviceType.AUTO:
		InputHelper.device_changed.connect(func(_device, _index): update_texture())
	update_texture()

	if hide_background:
		get_node("ColorRect").visible = false


func update_texture():
	var loaded_texture = null
	match device_type:
		DeviceType.KEYBOARD_MOUSE:
			loaded_texture = get_image_for_keyboard_input(assigned_action)
			texture = loaded_texture
		DeviceType.XBOX:
			loaded_texture = get_image_for_controller_input("xbox", assigned_action)
			texture = loaded_texture
		DeviceType.SONY:
			loaded_texture = get_image_for_controller_input("playstation", assigned_action)
			texture = loaded_texture
		DeviceType.STEAMDECK:
			loaded_texture = get_image_for_controller_input("steamdeck", assigned_action)
			texture = loaded_texture
		DeviceType.AUTO:
			var guessed_device = InputHelper.device
			if ["xbox", "playstation", "steamdeck"].has(guessed_device):
				loaded_texture = get_image_for_controller_input(guessed_device, assigned_action)
			else:
				if force_non_kbm:
					loaded_texture = get_image_for_controller_input("xbox", assigned_action)
				else:
					loaded_texture = get_image_for_keyboard_input(assigned_action)

	texture = loaded_texture


func get_image_for_keyboard_input(action: String):
	var kbm_input_label: String
	if action == "move_generic":
		kbm_input_label = "keyboard_arrows"
	elif action == "device_icon":
		kbm_input_label = kbm_input_icon_mapping["device_icon"]
	else:
		var kbm_event = InputHelper.get_keyboard_input_for_action(action)
		kbm_input_label = InputHelper.get_label_for_input(kbm_event).to_lower()
		if kbm_input_icon_mapping.has(kbm_input_label):
			kbm_input_label = kbm_input_icon_mapping[kbm_input_label]
		else:
			kbm_input_label = "keyboard_" + kbm_input_label
	var kbm_icon_path = "res://assets/sprite/input/keyboard_and_mouse/{0}.png".format([kbm_input_label])

	var icon_texture = null
	if ResourceLoader.exists(kbm_icon_path):
		icon_texture = load(kbm_icon_path)
	else:
		push_warning("Failed to load texture at: %s" % kbm_icon_path)
	return icon_texture

func get_image_for_controller_input(device: String, action: String):
	var controller_event = InputHelper.get_joypad_input_for_action(action)
	var controller_input_label = InputHelper.get_label_for_input(controller_event).to_lower()

	# Decide what type of controller player is using
	var controller_icon_mapping = {}
	var icon_pathname = ""
	print("IMAGE FOR CONTROLLER INPUT: %s - %s" % [device, action])
	if device == "playstation":
		controller_icon_mapping = sony_input_icon_mapping
		icon_pathname = "res://assets/sprite/input/sony/{0}.png"
	elif device == "xbox":
		controller_icon_mapping = xbox_input_icon_mapping
		icon_pathname = "res://assets/sprite/input/xbox/{0}.png"
	elif device == "steamdeck":
		controller_icon_mapping = steamdeck_input_icon_mapping
		icon_pathname = "res://assets/sprite/input/steam_deck/{0}.png"
	else:
		# Forcing using text instead of icon
		controller_icon_mapping = {}
		icon_pathname = "{0}"
	
	if action == "move_generic":
		controller_input_label = "move_generic"
	elif action == "device_icon":
		controller_input_label = "device_icon"

	if controller_icon_mapping.has(controller_input_label):
		controller_input_label = controller_icon_mapping[controller_input_label]
	else:
		controller_input_label = ""
	
	var controller_icon_path = icon_pathname.format([controller_input_label])
	
	var icon_texture = null
	if ResourceLoader.exists(controller_icon_path):
		icon_texture = load(controller_icon_path)
	else:
		push_warning("Failed to load texture at: %s" % controller_icon_path)
	return icon_texture
