extends HBoxContainer

@export var slot_id: int = 0

@onready var load_button_label: RichTextLabel = $MarginContainer/MarginContainer/LoadButtonLabel
@onready var delete_button: Button = $DeleteButton

var save_data = null
var main_menu: MainMenu
var confirm_delete = false

func _ready() -> void:
	confirm_delete = false
	main_menu = get_parent().get_parent().get_parent()
	if slot_id <= 0:
		push_error("SLOT ID MUST START AT 1")
		load_button_label.text = "[b][color=gold]Slot {0}[/color][/b] \
			\nCannot load save file".format([slot_id])
		delete_button.disabled = true
		delete_button.visible = false
		return

	save_data = SaveManager.load_data_only(slot_id)
	if not save_data.is_empty():
		var chips = save_data.get("player_currency", 0)
		var barrel_collected = len(save_data.get("equipped_barrels", [])) + len(save_data.get("inventory_barrels", []))
		var playtime = save_data.get("total_playtime", 0)
		load_button_label.text = "[b][color=gold]Slot {0}[/color][/b] \
			\nChips: {1} | Barrels collected: {2} \
			\nPlaytime: {3}".format([slot_id, chips, barrel_collected, format_time(playtime)])
		delete_button.disabled = false
	else:
		load_button_label.text = "[b][color=gold]Slot {0}[/color][/b] \
			\nNew save file".format([slot_id])
		delete_button.disabled = true
		delete_button.visible = false


func _on_load_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	GameManager.chosen_slot_id = slot_id
	load_button_label.text = "[b][color=gold]Slot {0}[/color][/b] \
		\nLoading...".format([slot_id])
	main_menu.start_game()

func _on_delete_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	if not confirm_delete:
		confirm_delete = true
		delete_button.text = "Confirm?"
	else:
		SaveManager.delete_save_file(slot_id)
		save_data = null
		delete_button.text = "Delete"
		delete_button.disabled = true
		delete_button.visible = false
		confirm_delete = false
		load_button_label.text = "[b][color=gold]Slot {0}[/color][/b] \
			\nNew save file".format([slot_id])


func format_time(msec: int) -> String:
	var seconds: int = round(msec / 1000.0)
	var hours: int = round(seconds / 3600.0)
	var minutes: int = round((seconds % 3600) / 60.0)
	var secs = seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]

func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()