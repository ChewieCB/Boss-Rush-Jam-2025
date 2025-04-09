extends Control


@onready var content_container = $PanelContainer/Background/NinePatchRect/VBoxContainer
@onready var header_label = $PanelContainer/Background/NinePatchRect/VBoxContainer/WinLabelHeader
@onready var subheader_label = $PanelContainer/Background/NinePatchRect/VBoxContainer/MarginContainer2/WinLabelSubHeader
@onready var separator = $PanelContainer/Background/NinePatchRect/VBoxContainer/MarginContainer/HSeparator

@export var max_resize_steps: int = 40


func win(header_text: String, subheader_text: String) -> void:
	header_label.text = "[center]%s[/center]" % [header_text]
	subheader_label.text = "[center]%s[/center]" % [subheader_text]
	resize_font(header_label)
	resize_font(subheader_label)


func text_no_resize(header_text: String, subheader_text: String) -> void:
	header_label.text = "[center]%s[/center]" % [header_text]
	subheader_label.text = "[center]%s[/center]" % [subheader_text]


func lose(hint_text: String = "") -> void:
	header_label.text = "[center]The House always wins[/center]"
	subheader_label.text = "[center]%s[/center]" % [hint_text]
	resize_font(header_label)
	resize_font(subheader_label)


func resize_font(label: RichTextLabel) -> void:
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
