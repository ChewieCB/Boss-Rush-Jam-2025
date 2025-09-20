extends CanvasLayer
class_name PlayerUI

@onready var saving_indicator: Label = $SavingIndicator
@onready var pause_ui: PauseUI = $PauseUI

@onready var stat_ui: StatUI = $StatUI
@onready var interact_ui = $InteractUI
@onready var gun_ui = $GunUI

func _ready() -> void:
	SaveManager.started_saving.connect(func(): saving_indicator.visible = true)
	SaveManager.finished_saving.connect(hide_saving_indicator)
	pause_ui.setting_ui.setting_changed.connect(refresh_after_setting_changed)
	refresh_after_setting_changed()


func hide_saving_indicator():
	await get_tree().create_timer(0.5).timeout
	saving_indicator.visible = false


func refresh_after_setting_changed():
	stat_ui.visible = not GameManager.hide_ui
	interact_ui.visible = not GameManager.hide_ui
	# NOTE: Currently GunUI only show barrels info when user press "tab" so no need to hide it
	# However, if there is more elements are added in the future then it will need modification.
	# gun_ui.visible = not GameManager.hide_ui
