extends Control


@onready var header_label = $PanelContainer/Background/NinePatchRect/VBoxContainer/WinLabelHeader
@onready var subheader_label = $PanelContainer/Background/NinePatchRect/VBoxContainer/MarginContainer2/WinLabelSubHeader
@onready var separator = $PanelContainer/Background/NinePatchRect/VBoxContainer/MarginContainer/HSeparator


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
	while label.get_line_count() > 1:
		var current_font_size = label.get_theme_font_size("normal_font_size")
		label.add_theme_font_size_override("normal_font_size", current_font_size - 16)
	var current_font_size = label.get_theme_font_size("normal_font_size")
	label.add_theme_font_size_override("normal_font_size", current_font_size - 8)
