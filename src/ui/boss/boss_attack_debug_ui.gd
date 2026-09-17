extends Control

@onready var vbox: VBoxContainer = $VBoxContainer
@export var debug_attack_input_ui: PackedScene

func _ready() -> void:
	for i in range(5):
		var ui = debug_attack_input_ui.instantiate()
		ui.visible = false
		vbox.add_child(ui)


func add_attack_ui(input_action: String, attack_name: String) -> void:
	for ui in vbox.get_children():
		if ui.visible:
			continue
		ui.input_prompt.assigned_action = input_action
		ui.label.text = attack_name
		ui.visible = true
		break


func highlight_attack_ui(idx: int) -> void:
	for i in vbox.get_child_count():
		var _highlight_visible = i == idx
		vbox.get_child(i).highlight.visible = _highlight_visible


func clear_attack_ui() -> void:
	for ui in vbox.get_children():
		ui.highlight.visible = false
		ui.visible = false
		ui.label.text = ""
