extends MarginContainer
class_name LuckTriggerInfoUI

@export var trigger_name: String
@export var trigger_description: String
@export var is_discovered: bool = false

const INACTIVE_COLOR := Color.WEB_GRAY
const INACTIVE_OUTLINE_COLOR := Color.DIM_GRAY
const ACTIVE_COLOR := Color("#d4b70b")
const ACTIVE_OUTLINE_COLOR := Color("#8c7530")

@onready var active_icon: TextureRect = $HBoxContainer/IconContainer/ActiveIcon
@onready var active_icon_outline: TextureRect = $HBoxContainer/IconContainer/ActiveIconOutline
@onready var name_label: RichTextLabel = $HBoxContainer/MarginContainer/VBoxContainer/LuckTriggerNameLabel
@onready var desc_label: RichTextLabel = $HBoxContainer/MarginContainer/VBoxContainer/MarginContainer/LuckTriggerDescLabel


func set_info(p_name: String, p_desc: String, p_is_discovered: bool) -> void:
	trigger_name = p_name
	trigger_description = p_desc
	is_discovered = p_is_discovered
	
	if is_discovered:
		active_icon.modulate = ACTIVE_COLOR
		active_icon_outline.modulate = ACTIVE_OUTLINE_COLOR
		name_label.text = trigger_name
		desc_label.text = trigger_description
	else:
		active_icon.modulate = INACTIVE_COLOR
		active_icon_outline.modulate = INACTIVE_OUTLINE_COLOR
		name_label.text = "Undiscovered"
		desc_label.text = "???"
