extends Control
class_name InfoBox

@onready var panel_container = $PanelContainer
@onready var content_container = $PanelContainer/MarginContainer/VBoxContainer
@onready var header_label = $PanelContainer/MarginContainer/VBoxContainer/WinLabelHeader
@onready var separator = $PanelContainer/MarginContainer/VBoxContainer/MarginContainer/HSeparator
@onready var particles: GPUParticles2D = $PanelContainer/MarginContainer/VBoxContainer/BossLockedBarrelOverlay/MarginContainer/VBoxContainer/MarginContainer2/UnlockParticles
@onready var unlock_container: MarginContainer = $PanelContainer/MarginContainer/VBoxContainer/BossLockedBarrelOverlay
@onready var unlock_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/BossLockedBarrelOverlay/MarginContainer/VBoxContainer/MarginContainer2/Panel/NinePatchRect/TextureRect
@onready var unlock_label: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/BossLockedBarrelOverlay/MarginContainer/VBoxContainer/MarginContainer/RichTextLabel

@export var max_resize_steps: int = 40
@export var show_header: bool = true
@export var sfx_unlock: AudioStream


func text_no_resize(header_text: String) -> void:
	header_label.text = "[center]%s[/center]" % [header_text]
	unlock_container.visible = false


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
	unlock_container.visible = false
	
	if not show_header:
		header_label.visible = false
		separator.visible = false
	text_no_resize(header_text)
	_resize_font(header_label)


func win(barrel_data: BarrelDataResource) -> void:
	if GameManager.boss_barrels_unlocked[barrel_data.boss_id] == 1:
		unlock_container.visible = false
	else:
		unlock_container.visible = true
		var unlock_string: String = "[i]Unlocked [wave amp=30.0 freq=3.0 connected=0][color=green][font_size=64]%s[/font_size][/color][/wave][/i]" % barrel_data.barrel_name
		unlock_label.text = unlock_string
		unlock_icon.texture = barrel_data.barrel_image
	
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(Color.WHITE, 1.0), 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tween.finished
	
	if unlock_container.visible:
		particles.restart()
		SoundManager.play_sound(sfx_unlock, "UI")
	
	await get_tree().create_timer(4.5).timeout
	
	tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(Color.WHITE, 0.0), 0.6).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	
	return


func lose(hint_text: String = "") -> void:
	var _header_text = "[center]The House always wins[/center]"
	var _sub_text = "[center]%s[/center]" % [hint_text]
	text_no_resize(_header_text)
	_resize_font(header_label)
	unlock_container.visible = false
