extends ItemUI
class_name GunFrameItemUI


func init(_parent_ui: Control, _data: BaseDataResource, _is_equipped: bool = false, _is_purchased: bool = false):
	super(_parent_ui, _data, _is_equipped, _is_purchased)
	is_equipped = _is_equipped
	is_purchased = _is_purchased
	is_empty = false
	data = _data
	if data:
		texture = data.shop_ui_sprite
		button.text = data.frame_name


func deselect():
	super()
	button.text = data.frame_name
