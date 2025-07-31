extends MarginContainer
class_name EffectInfoUI

@onready var icon_rect: TextureRect = $Background/NinePatchRect/MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/IconContainer/MarginContainer/TextureRect
@onready var name_label: RichTextLabel = $Background/NinePatchRect/MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/HeaderTextContainer/TitleContainer/RichTextLabel
@onready var desc_label: RichTextLabel = $Background/NinePatchRect/MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/HeaderTextContainer/DescriptionContainer/RichTextLabel
@onready var positives_container: Control = $Background/NinePatchRect/MarginContainer/VBoxContainer/BodyContainer/VBoxContainer/PositivesContainer
@onready var negatives_container: Control = $Background/NinePatchRect/MarginContainer/VBoxContainer/BodyContainer/VBoxContainer/NegativesContainer

@export var positive_icon: Texture2D
@export var negative_icon: Texture2D
@export var effect_info_textbox: PackedScene


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.modulate.a = 0.0


func add_positive(text: String) -> void:
	var textbox = effect_info_textbox.instantiate()
	positives_container.add_child(textbox)
	textbox.icon.texture = positive_icon
	textbox.icon.modulate = Color.WEB_GREEN
	textbox.label.text = text


func add_negative(text: String) -> void:
	var textbox = effect_info_textbox.instantiate()
	negatives_container.add_child(textbox)
	textbox.icon.texture = negative_icon
	textbox.icon.modulate = Color.RED
	textbox.label.text = text
