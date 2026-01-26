extends VBoxContainer


@onready var gun_frame_item_ui: GunFrameItemUI = $GunFrameItemUI
@onready var price_icon: TextureRect = $HBoxContainer/PriceIcon
@onready var price_label: Label = $HBoxContainer/PriceLabel

var button: Button

func _ready() -> void:
	button = gun_frame_item_ui.button
	gun_frame_item_ui.is_shop_item_ui = true

func init(_data: GunFrameResource, _is_purchased = false):
	gun_frame_item_ui.init(_data, false, _is_purchased)
	price_label.text = str(_data.frame_cost)
	if _data.frame_cost > GameManager.player_currency:
		gun_frame_item_ui.is_disabled = true
	for elem in [price_icon, price_label]:
		elem.modulate = Color.DIM_GRAY if gun_frame_item_ui.is_disabled else Color.WHITE
