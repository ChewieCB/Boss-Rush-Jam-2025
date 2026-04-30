extends TextureRect
class_name ItemUI

signal select_item(item_ui: ItemUI, data: BarrelDataResource)
signal interact_item(item_ui: ItemUI, data: BarrelDataResource)
signal show_warning(warning_text: String)

@export var button: Button
@export var border_selected: NinePatchRect
@export var spin_value_label: RichTextLabel
@export var locked_panel: Control

var parent_inventory_ui: Control

var data: BarrelDataResource
var clicked_once = false
var scale_factor = 1.1
var is_shop_item_ui = false

var is_equipped = false
var is_active_equip: bool = false
var is_purchased: bool = false:
	set(value):
		is_purchased = value
var is_disabled: bool = false:
	set(value):
		is_disabled = value
		self.modulate = Color.DIM_GRAY if is_disabled else Color.WHITE
var is_locked: bool = false
var is_empty: bool = true
var warning_text = ""


func _ready() -> void:
	if data:
		button.text = data.barrel_name
	button.mouse_entered.connect(play_button_hover_sfx)
	button.mouse_entered.connect(expand_button_size)
	button.mouse_exited.connect(return_button_size)


func init(_parent_ui: Control) -> void:
	parent_inventory_ui = _parent_ui


func empty_slot() -> void:
	data = null
	texture = null
	button.text = "Equip Roller"
	spin_value_label.text = ""
	spin_value_label.visible = false
	
	is_locked = false
	locked_panel.visible = false
	is_equipped = false
	is_purchased = false
	is_empty = true


func set_barrel_data(_data: BarrelDataResource, _is_equipped: bool = false, _is_purchased: bool = false) -> void:
	data = _data
	texture = data.barrel_image
	button.text = data.barrel_name
	if data.reloads_before_spin > 0:
		spin_value_label.text = "[center][b](%s)[/b][/center]" % [data.reloads_before_spin]
		spin_value_label.visible = true
	else:
		spin_value_label.visible = false
	
	is_locked = data.locked_for_demo
	locked_panel.visible = data.locked_for_demo
	is_equipped = _is_equipped
	is_purchased = _is_purchased
	is_empty = false


func deselect():
	clicked_once = false
	border_selected.visible = false
	button.text = data.barrel_name if data else "Equip Roller"


#### Audio/Visual polish helpers

func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()


func expand_button_size():
	if button.disabled:
		return
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self , "scale", Vector2(scale_factor, scale_factor), 0.1)


func return_button_size():
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self , "scale", Vector2(1, 1), 0.1)


func _on_button_focus_entered() -> void:
	play_button_hover_sfx()
	expand_button_size()
	# We do this for shop item UI so it can show the price at the bottom
	if parent_inventory_ui:
		if is_shop_item_ui:
			if parent_inventory_ui.visible:
				parent_inventory_ui.scroll_container.ensure_control_visible(get_parent())
			else:
				grab_focus()  # This wont show the chip cost, but at least it wont crash
		else:
			if parent_inventory_ui.visible:
				parent_inventory_ui.scroll_container.ensure_control_visible(self)


func _on_button_focus_exited() -> void:
	if not is_active_equip:
		return_button_size()


func _on_button_pressed() -> void:
	if is_empty:
		interact_item.emit(self, data)
		return
	
	if not clicked_once:
		select_item.emit(self, data)
		if is_locked:
			pass
		elif not is_purchased:
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
		interact_item.emit(self, data)
