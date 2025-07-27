extends Control
class_name InfoBox

@onready var panel_container = $PanelContainer
@onready var content_container = $PanelContainer/Background/NinePatchRect/VBoxContainer
@onready var header_label = $PanelContainer/Background/NinePatchRect/MarginContainer/VBoxContainer/WinLabelHeader
@onready var subheader_label = $PanelContainer/Background/NinePatchRect/MarginContainer/VBoxContainer/MarginContainer2/WinLabelSubHeader
@onready var separator = $PanelContainer/Background/NinePatchRect/MarginContainer/VBoxContainer/MarginContainer/HSeparator

@export var max_resize_steps: int = 40
@export var show_header: bool = true


func text_no_resize(header_text: String, subheader_text: String) -> void:
	header_label.text = "[center]%s[/center]" % [header_text]
	subheader_label.text = "[center]%s[/center]" % [subheader_text]


func _resize_font(label: RichTextLabel) -> void:
	var font_size = label.get_theme_font_size("normal_font_size")
	var font = label.get_theme_font("font")
	
	var line := TextLine.new()
	for i in range(max_resize_steps):
		line.clear()
		var created = line.add_string(label.text, font, font_size)
		if created:
			var text_size = line.get_line_width()
			if text_size > floor(content_container.size.x):
				font_size -= 1
			else:
				break
		else:
			push_warning("Could not resize label")
	
	label.add_theme_font_size_override("font_size", font_size)


func show_text(header_text: String, subheader_text: String) -> void:
	if not show_header:
		header_label.visible = false
		separator.visible = false
	text_no_resize(header_text, subheader_text)
	var lines = subheader_label.get_line_count()
	panel_container.size.y = panel_container.get_minimum_size().y + ((48 + 16) * lines)
	#_resize_font(header_label)
	#_resize_font(subheader_label)


func lose(hint_text: String = "") -> void:
	var _header_text = "[center]The House always wins[/center]"
	var _sub_text = "[center]%s[/center]" % [hint_text]
	text_no_resize(_header_text, _sub_text)
	_resize_font(header_label)
	_resize_font(subheader_label)
