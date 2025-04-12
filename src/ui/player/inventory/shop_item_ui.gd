extends VBoxContainer

#signal select_item(item_ui: ItemUI, data: BarrelDataResource)

@export var item_ui: ItemUI
@export var price_icon: TextureRect
@export var price_label: Label

@onready var button: Button = $BarrelItemUI/Button

var clicked_once: bool = false
var is_disabled: bool = false:
	set(value):
		is_disabled = value
		if is_disabled:
			# Grey out the text and texture, disable the button
			item_ui.modulate = Color.DIM_GRAY
			price_icon.modulate = Color.DIM_GRAY
			price_label.modulate = Color.DIM_GRAY
			#item_ui.button.disabled = true
		else:
			# Grey out the text and texture, disable the button
			item_ui.modulate = Color.WHITE
			price_icon.modulate = Color.WHITE
			price_label.modulate = Color.WHITE
			#item_ui.button.disabled = false


func init(_data: BarrelDataResource, _is_purchased):
	item_ui.data = _data
	item_ui.is_purchased = _is_purchased
	item_ui.texture = item_ui.data.barrel_image
	price_label.text = str(item_ui.data.barrel_cost)
