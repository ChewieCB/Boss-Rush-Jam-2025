extends Node3D
class_name Gun

@onready var barrel_container = $Barrel
@onready var loading_label: Label3D = $PlaceholderUI/ReloadLabel

func _ready() -> void:
	loading_label.visible = false

func spin_all_barrels():
	loading_label.visible = true
	for child in barrel_container.get_children():
		child.start_spin()
	await get_tree().create_timer(1).timeout
	loading_label.visible = false
	for child in barrel_container.get_children():
		child.stop_spin()
