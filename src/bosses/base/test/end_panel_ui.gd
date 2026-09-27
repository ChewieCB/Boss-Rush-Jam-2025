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


func anim_fade_in(time: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(Color.WHITE, 1.0), time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	return


func anim_fade_out(time: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(Color.WHITE, 0.0), time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	
	return


func win(barrel_data: BarrelDataResource) -> void:
	unlock_icon.texture = barrel_data.barrel_image
	var unlock_string: String = ""
	if GameManager.boss_barrels_unlocked[barrel_data.boss_id] == 0:
		unlock_string = "[i]Unlocked [wave amp=30.0 freq=3.0 connected=0][color=green][font_size=64]%s[/font_size][/color][/wave][/i]" % barrel_data.barrel_name
		unlock_icon.modulate = Color.WHITE
	else:
		unlock_string = "[i][color=gray][font_size=64]Already unlocked![/font_size][/color]" 
		unlock_icon.modulate = Color.DARK_GRAY
	
	unlock_label.text = unlock_string
	unlock_container.visible = true
	
	await anim_fade_in(0.6)
	
	if unlock_container.visible:
		particles.restart()
		SoundManager.play_sound(sfx_unlock, "UI")
	
	await get_tree().create_timer(4.5).timeout
	await anim_fade_out(0.6)
	
	return


func lose(hint_text: String = "") -> void:
	var _header_text = "[center]The House always wins[/center]"
	header_label.text = _header_text
	unlock_container.visible = false
	
	await anim_fade_in(0.6)
	await get_tree().create_timer(2.0).timeout
	await anim_fade_out(0.6)
	
	return
