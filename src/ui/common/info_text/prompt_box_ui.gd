extends Control
class_name PromptInfoBox

@export var elements: Array[String] = []
@export var input_prompt_prefab: PackedScene

@onready var panel_container = $PanelContainer
@onready var content_container = $PanelContainer/Background/NinePatchRect/VBoxContainer
@onready var header_label = $PanelContainer/Background/NinePatchRect/MarginContainer/VBoxContainer/WinLabelHeader
@onready var separator = $PanelContainer/Background/NinePatchRect/MarginContainer/VBoxContainer/MarginContainer/HSeparator
@onready var prompt_container = $PanelContainer/MarginContainer/VBoxContainer/MarginContainer4/HBoxContainer

@export var max_resize_steps: int = 40
@export var show_header: bool = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for element in elements:
		var node: Control
		if element.begins_with("["):
			var _action_str := element.trim_prefix("[").trim_suffix("]")
			var _prompt = input_prompt_prefab.instantiate()
			_prompt.assigned_action = _action_str
			node = _prompt
		else:
			var _label = Label.new()
			_label.add_theme_font_size_override("font_size", 64)
			_label.text = element
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			node = _label
			
		prompt_container.add_child(node)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
