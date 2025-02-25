extends CanvasLayer

@onready var saving_indicator: Label = $SavingIndicator

func _ready() -> void:
	SaveManager.started_saving.connect(func(): saving_indicator.visible = true)
	SaveManager.finished_saving.connect(hide_saving_indicator)


func hide_saving_indicator():
	await get_tree().create_timer(0.5).timeout
	saving_indicator.visible = false
