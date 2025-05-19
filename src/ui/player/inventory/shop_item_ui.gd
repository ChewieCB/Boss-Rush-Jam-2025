extends VBoxContainer

#signal select_item(item_ui: ItemUI, data: BarrelDataResource)

@onready var item_ui: ItemUI = $BarrelItemUI
@onready var price_icon: TextureRect = $HBoxContainer/PriceIcon
@onready var price_label: Label = $HBoxContainer/PriceLabel

var button: Button

# var clicked_once: bool = false
# var is_disabled: bool = false:
# 	set(value):
# 		is_disabled = value
# 		if is_disabled:
# 			# Grey out the text and texture, disable the button
# 			item_ui.modulate = Color.DIM_GRAY
# 			price_icon.modulate = Color.DIM_GRAY
# 			price_label.modulate = Color.DIM_GRAY
# 		else:
# 			# Grey out the text and texture, disable the button
# 			item_ui.modulate = Color.WHITE
# 			price_icon.modulate = Color.WHITE
# 			price_label.modulate = Color.WHITE

func _ready() -> void:
	button = item_ui.button

func init(_data: BarrelDataResource, _is_purchased = false):
	item_ui.init(_data, false, _is_purchased)
	price_label.text = str(item_ui.data.barrel_cost)
	if _data.barrel_cost > GameManager.player_currency:
		item_ui.is_disabled = true
	for elem in [price_icon, price_label]:
		elem.modulate = Color.DIM_GRAY if item_ui.is_disabled else Color.WHITE
