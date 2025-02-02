extends TextureRect

@onready var button: Button = $Button
@onready var border_selected = $BorderSelected

@export var sfx_click: AudioStream

var data: BarrelDataResource
var clicked_once = false
var is_equipped = false
var warning_text = ""

func init(_data: BarrelDataResource, _is_equipped):
	data = _data
	is_equipped = _is_equipped
	texture = data.barrel_image


func _on_button_pressed() -> void:
	SoundManager.play_ui_sound(sfx_click, "UI")
	if not clicked_once:
		if (GameManager.player.inventory_ui.current_selected_item_ui != null):
			GameManager.player.inventory_ui.current_selected_item_ui.unselected()
		GameManager.player.inventory_ui.current_selected_item_ui = self
		GameManager.player.inventory_ui.update_description(data.barrel_desc)
		if is_equipped:
			button.text = "Remove?"
		else:
			button.text = "Equip?"
		clicked_once = true
		border_selected.visible = true
	else:
		if is_equipped:
			warning_text = GameManager.remove_barrel(data.barrel_id)
			GameManager.player.inventory_ui.show_warning(warning_text)
		else:
			warning_text = GameManager.equip_barrel(data.barrel_id)
			GameManager.player.inventory_ui.show_warning(warning_text)


func unselected():
	clicked_once = false
	border_selected.visible = false
	button.text = ""
