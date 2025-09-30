extends ColorRect
class_name BarrelInfoIcon

@onready var texture_rect: TextureRect = $TextureRect
@onready var border_focus: Control = $BorderFocus

signal display_description(content)

const SCALE_FACTOR = 1.2
var barrel_info_region: BarrelInfoRegion = null
var barrel_data: Dictionary = {
	"display_text_title": "",
	"display_text_tag": "",
	"is_archetype": false,
	"positive_desc": [],
	"negative_desc": [],
}


func _ready() -> void:
	self_modulate = Color(0.5, 0.5, 0.5)
	focus_entered.connect(expand_button_size)
	focus_exited.connect(return_button_size)


func set_barrel_data(_data) -> void:
	barrel_data = _data


func expand_button_size():
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(SCALE_FACTOR, SCALE_FACTOR), 0.1)

func return_button_size():
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1)


func _on_focus_exited() -> void:
	border_focus.visible = false
	self_modulate = Color(0.5, 0.5, 0.5)


func _on_focus_entered() -> void:
	border_focus.visible = true
	self_modulate = Color(1, 1, 1)
	var content = "[center]{0}[/center]\n\n{1}\n".format([
		barrel_data["display_text_title"],
		barrel_data["display_text_tag"]]
	)
	if len(barrel_data["positive_desc"]) > 0:
		content += "[color=green]\n"
		for line in barrel_data["positive_desc"]:
			content += "+ " + line + "\n"
		content += "[/color]"
	if len(barrel_data["negative_desc"]) > 0:
		content += "[color=red]\n"
		for line in barrel_data["negative_desc"]:
			content += "- " + line + "\n"
		content += "[/color]"
	barrel_info_region.set_description_content(content)
