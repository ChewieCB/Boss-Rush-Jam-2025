extends Node3D

@onready var elevator_doors: ElevatorDoors = find_children("*", "ElevatorDoors").front()
@export var elevator_buttons: Array[ElevatorButton]
@onready var difficulty_menu: DifficultyMenu = $UI/DifficultyMenu

func _ready() -> void:
	ScreenTransition.transition_in()
	await ScreenTransition.transition_finished

	await get_tree().process_frame
	await get_tree().process_frame

	GameManager.reset_reroll_cost()
	GameManager.is_free_reroll = true
