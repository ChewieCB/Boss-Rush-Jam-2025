extends TextureRect
class_name GunFrameItemUI

signal select_gun_frame(item_ui: GunFrameItemUI, data: GunFrameResource)
signal interact_gun_frame(item_ui: GunFrameItemUI, data: GunFrameResource)

@onready var button: Button = $Button
@onready var border_selected = $BorderSelected

var data: GunFrameResource
var clicked_once = false
var scale_factor = 1.1
var is_shop_item_ui = false

var is_equipped = false
var is_purchased: bool = false:
	set(value):
		is_purchased = value
var is_disabled: bool = false:
	set(value):
		is_disabled = value
		self.modulate = Color.DIM_GRAY if is_disabled else Color.WHITE
var warning_text = ""

func init(_data: GunFrameResource, _is_equipped: bool = false, _is_purchased: bool = false):
	data = _data
	is_equipped = _is_equipped
	is_purchased = _is_purchased
	if data:
		texture = data.shop_ui_sprite
		button.text = data.frame_name


func _ready() -> void:
	if data:
		button.text = data.frame_name
	button.mouse_entered.connect(play_button_hover_sfx)
	button.mouse_entered.connect(expand_button_size)
	button.mouse_exited.connect(return_button_size)


func _on_button_pressed() -> void:
	if not clicked_once:
		select_gun_frame.emit(self, data)
		if not is_purchased:
			if is_disabled:
				button.text = "Not enough\nchips!"
			else:
				button.text = "Purchase?"
		elif is_equipped:
			button.text = "Remove?"
		else:
			button.text = "Equip?"
		clicked_once = true
		border_selected.visible = true
	else:
		interact_gun_frame.emit(self, data)


func unselected():
	clicked_once = false
	border_selected.visible = false
	button.text = data.frame_name

func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()

func expand_button_size():
	pivot_offset = size / 2
	if button.disabled:
		return
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(scale_factor, scale_factor), 0.1)

func return_button_size():
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1)


func _on_button_focus_entered() -> void:
	play_button_hover_sfx()
	expand_button_size()
	# We do this for shop item UI so it can show the price at the bottom
	if is_shop_item_ui:
		if GameManager.gun_customize_ui:
			GameManager.gun_customize_ui.get_current_scroll_container().ensure_control_visible(get_parent())
		else:
			grab_focus() # This wont show the chip cost, but at least it wont crash
	else:
		grab_focus()

func _on_button_focus_exited() -> void:
	return_button_size()
