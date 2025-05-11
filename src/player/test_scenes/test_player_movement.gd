extends Node3D


func _ready() -> void:
	ScreenTransition.transition_in()
	await ScreenTransition.transition_finished

	await get_tree().process_frame
	await get_tree().process_frame

	GameManager.reset_reroll_cost()
	GameManager.is_free_reroll = true