extends VBoxContainer

@onready var item_ui: ItemUI = $BarrelItemUI
@onready var price_icon: TextureRect = $HBoxContainer/PriceIcon
@onready var price_label: Label = $HBoxContainer/PriceLabel

var button: Button

# FIXME - what is this class for that barrel_item_ui.gd doesn't cover?


func _ready() -> void:
	button = item_ui.button
	item_ui.is_shop_item_ui = true


func init(_data: BarrelDataResource, _parent_ui: InventoryUI, _is_purchased = false):
	item_ui.init(_parent_ui)
	item_ui.set_barrel_data(_data, false, _is_purchased)
	price_label.text = str(_data.barrel_cost)
	if _data.barrel_cost > GameManager.player_currency:
		item_ui.is_disabled = true
	for elem in [price_icon, price_label]:
		elem.modulate = Color.DIM_GRAY if item_ui.is_disabled else Color.WHITE
