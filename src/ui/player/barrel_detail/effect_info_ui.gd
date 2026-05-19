extends MarginContainer
class_name EffectInfoUI

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/IconContainer/MarginContainer/TextureRect
@onready var name_label: RichTextLabel = $MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/HeaderTextContainer/TitleContainer/RichTextLabel
@onready var tag_label: RichTextLabel = $MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/HeaderTextContainer/DescriptionContainer/RichTextLabel
@onready var effect_description_label: RichTextLabel = $MarginContainer/VBoxContainer/BodyContainer/VBoxContainer/EffectDescriptionLabel
@onready var luck_trigger_container: Control = $MarginContainer/VBoxContainer/BodyContainer/VBoxContainer/LuckTriggersContainer
@onready var luck_trigger_1: LuckTriggerInfoUI = $MarginContainer/VBoxContainer/BodyContainer/VBoxContainer/LuckTriggersContainer/LuckTriggerInfoUI
@onready var luck_trigger_2: LuckTriggerInfoUI = $MarginContainer/VBoxContainer/BodyContainer/VBoxContainer/LuckTriggersContainer/LuckTriggerInfoUI2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.modulate.a = 0.0


func update_luck_trigger(idx: int, trigger_name: String, trigger_desc: String, trigger_discovered: bool) -> void:
	var luck_trigger_ui: LuckTriggerInfoUI
	match idx:
		0:
			luck_trigger_ui = luck_trigger_1
		1:
			luck_trigger_ui = luck_trigger_2
		_:
			push_error("Invalid luck trigger index, limit is 2 | idx = %s" % [idx])
	
	luck_trigger_ui.set_info(trigger_name, trigger_desc, trigger_discovered)


func clear_luck_triggers() -> void:
	luck_trigger_container.visible = false
	for i in range(2):
		update_luck_trigger(i, "", "", false)
