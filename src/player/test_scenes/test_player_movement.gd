extends Node3D


func _ready() -> void:
	ScreenTransition.transition_in()
	await ScreenTransition.transition_finished
