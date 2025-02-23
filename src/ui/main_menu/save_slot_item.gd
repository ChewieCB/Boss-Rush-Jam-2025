extends HBoxContainer

@export var slot_id: int = 0

@onready var load_button_label: RichTextLabel = $MarginContainer/MarginContainer/LoadButtonLabel

var save_data = null
var main_menu: MainMenu

func _ready() -> void:
	main_menu = get_parent().get_parent().get_parent()
	if slot_id <= 0:
		push_error("SLOT ID MUST START AT 1")
		load_button_label.text = "[b]Slot {0}[/b] \
			\nCannot load save file".format([slot_id])
		return

	save_data = SaveManager.load_data_only(slot_id)
	if not save_data.is_empty():
		var chips = save_data["player_currency"]
		var barrel_collected = len(save_data["equipped_barrels"]) + len(save_data["inventory_barrels"])
		load_button_label.text = "[b]Slot {0}[/b] \
			\nChips: {1} | Barrels collected: {2} \
			\nPlaytime: 00:00:00 (Not implemented)".format([slot_id, chips, barrel_collected])
	else:
		load_button_label.text = "[b]Slot {0}[/b] \
			\nNew save file".format([slot_id])


func _on_load_button_pressed() -> void:
	GameManager.chosen_slot_id = slot_id
	main_menu.start_game()
