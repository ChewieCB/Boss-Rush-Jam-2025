extends TextureRect
class_name ItemUI

signal select_item(item_ui: ItemUI, data: BarrelDataResource)
signal interact_item(item_ui: ItemUI, data: BarrelDataResource)
signal show_warning(warning_text: String)

@onready var button: Button = $Button
@onready var border_selected = $BorderSelected

@export var sfx_click: AudioStream
@export var sfx_barrel_equip: AudioStream

var data: BarrelDataResource
var clicked_once = false

var is_equipped = false
var is_purchased: bool = false:
	set(value):
		is_purchased = value
var is_disabled: bool = false:
	set(value):
		is_disabled = value
		self.modulate = Color.DIM_GRAY if is_disabled else Color.WHITE
var warning_text = ""


func init(_data: BarrelDataResource, _is_equipped: bool = false, _is_purchased: bool = false):
	data = _data
	is_equipped = _is_equipped
	is_purchased = _is_purchased
	texture = data.barrel_image


func _ready() -> void:
	if data:
		button.text = data.barrel_name


func _on_button_pressed() -> void:
	if not clicked_once:
		select_item.emit(self, data)
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
		interact_item.emit(self, data)


func unselected():
	clicked_once = false
	border_selected.visible = false
	button.text = data.barrel_name
