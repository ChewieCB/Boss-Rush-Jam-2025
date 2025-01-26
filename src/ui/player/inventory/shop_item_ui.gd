extends VBoxContainer

@export var barrel_ui: TextureRect
@export var button: Button
@export var border_selected: NinePatchRect
@export var price_icon: TextureRect
@export var price_label: Label

var data: BarrelDataResource
var clicked_once: bool = false
var is_disabled: bool = false:
	set(value):
		is_disabled = value
		if is_disabled:
			# Grey out the text and texture, disable the button
			barrel_ui.modulate = Color.DIM_GRAY
			price_icon.modulate = Color.DIM_GRAY
			price_label.modulate = Color.DIM_GRAY
			#button.disabled = true
		else:
			# Grey out the text and texture, disable the button
			barrel_ui.modulate = Color.WHITE
			price_icon.modulate = Color.WHITE
			price_label.modulate = Color.WHITE
			#button.disabled = false
var is_purchased: bool = false:
	set(value):
		is_purchased = value
		if is_purchased:
			button.disabled = true
			button.text = "Bought"


func init(_data: BarrelDataResource, _is_purchased):
	data = _data
	is_purchased = _is_purchased
	barrel_ui.texture = data.barrel_image
	price_label.text = str(data.barrel_cost)


func _on_button_pressed() -> void:
	if not clicked_once:
		if (GameManager.player.inventory_ui.current_selected_item_ui != null):
			GameManager.player.inventory_ui.current_selected_item_ui.unselected()
		GameManager.player.inventory_ui.current_selected_item_ui = self
		GameManager.player.inventory_ui.update_description(data.barrel_desc)
		if not is_purchased:
			if is_disabled:
				button.text = "Not enough\nchips!"
			else:
				button.text = "Purchase?"
		clicked_once = true
		border_selected.visible = true
	else:
		is_purchased = GameManager.purchase_barrel(data)


func unselected() -> void:
	clicked_once = false
	border_selected.visible = false
	button.text = ""
