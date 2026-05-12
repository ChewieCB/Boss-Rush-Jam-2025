extends ItemUI
class_name BarrelItemUI

@export var spin_value_label: RichTextLabel
@export var locked_panel: Control


func _ready() -> void:
	if data:
		button.text = data.barrel_name
	super()


func empty_slot() -> void:
	data = null
	texture = null
	is_locked = false
	locked_panel.visible = false
	is_equipped = false
	is_purchased = false
	is_empty = true
	# TODO - move this text to on-click?
	button.text = "Equip Roller"
	spin_value_label.text = ""
	spin_value_label.visible = false


func deselect() -> void:
	super()
	button.text = data.barrel_name if data else "Equip Roller"


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
