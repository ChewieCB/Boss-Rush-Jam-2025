extends Control
class_name PromptInfoBox

@export var elements: Array[String] = []
@export var input_prompt_prefab: PackedScene

@onready var panel_container = $PanelContainer
@onready var content_container = $PanelContainer/MarginContainer/VBoxContainer
@onready var prompt_line_container = $PanelContainer/MarginContainer/VBoxContainer
@onready var prompt_container = $PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer

@export var line_container: PackedScene


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
			
			if element.begins_with("\\n"):
				# Create a new label on a new line and remove the \n
				var newline_box = line_container.instantiate()
				_label.text = _label.text.trim_prefix("\\n")
				_label.add_theme_font_size_override("font_size", 42)
				newline_box.get_node("HBoxContainer").add_child(_label)
				prompt_line_container.add_child(newline_box)
				continue
			
			node = _label
			
		prompt_container.add_child(node)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
