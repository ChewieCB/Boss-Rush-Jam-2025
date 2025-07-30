extends MarginContainer
class_name EffectInfoUI

@onready var icon_rect: TextureRect = $Background/NinePatchRect/MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/IconContainer/MarginContainer/TextureRect
@onready var name_label: RichTextLabel = $Background/NinePatchRect/MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/HeaderTextContainer/TitleContainer/RichTextLabel
@onready var desc_label: RichTextLabel = $Background/NinePatchRect/MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/HeaderTextContainer/DescriptionContainer/RichTextLabel


# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	#icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
