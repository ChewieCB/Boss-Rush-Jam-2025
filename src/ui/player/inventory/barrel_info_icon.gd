extends ColorRect
class_name BarrelInfoIcon

@onready var texture_rect: TextureRect = $TextureRect
@onready var border_focus: Control = $BorderFocus
@export var pulse_speed: float = 5 # How fast the pulse happens
@export var pulse_strength: float = 0.3 # How bright/dark it changes (0–1 range)

signal display_description(content)

const SCALE_FACTOR = 1.2
var barrel_info_region: BarrelInfoRegion = null
var barrel_roll_data: Dictionary = {
	"title": "",
	"description": "",
	"is_archetype": false,
	"positive_desc": [],
	"negative_desc": [],
}
var _base_color: Color
var _time: float = 0.0
var is_expanded = false

func _ready() -> void:
	self_modulate = Color(0.5, 0.5, 0.5)
	_base_color = color

func _process(delta: float) -> void:
	if is_expanded:
		return
	_time += delta * pulse_speed
	# Make a smooth oscillation between -1 and 1
	var pulse = sin(_time) * 0.5 + 0.5 # normalized to 0..1
	# Adjust brightness based on pulse_strength
	var brightness = 1.0 - pulse_strength + pulse * pulse_strength * 2.0
	color = _base_color * brightness
	color.a = 1

func set_barrel_roll_data(_data) -> void:
	barrel_roll_data = _data


func expand_button_size():
	is_expanded = true
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(SCALE_FACTOR, SCALE_FACTOR), 0.1)

func return_button_size():
	is_expanded = false
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1)

func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()

func _on_focus_exited() -> void:
	border_focus.visible = false
	self_modulate = Color(0.5, 0.5, 0.5)
	return_button_size()


func _on_focus_entered() -> void:
	barrel_info_region.unfocus_other_barrel_info_icon()
	expand_button_size()
	play_button_hover_sfx()
	border_focus.visible = true
	self_modulate = Color(1, 1, 1)
	var content = "[center]{0}[/center]\n\n{1}\n".format([
		barrel_roll_data["title"],
		barrel_roll_data["description"]]
	)
	if len(barrel_roll_data["positive_desc"]) > 0:
		content += "[color=green]\n"
		for line in barrel_roll_data["positive_desc"]:
			content += "+ " + line + "\n"
		content += "[/color]"
	if len(barrel_roll_data["negative_desc"]) > 0:
		content += "[color=red]\n"
		for line in barrel_roll_data["negative_desc"]:
			content += "- " + line + "\n"
		content += "[/color]"
	barrel_info_region.set_description_content(content)
