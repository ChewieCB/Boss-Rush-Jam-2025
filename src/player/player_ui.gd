extends CanvasLayer

@onready var saving_indicator: Label = $SavingIndicator
@onready var pause_ui: PauseUI = $PauseUI

@onready var health_ui = $HealthUI
@onready var interact_ui = $InteractUI
@onready var gun_ui = $GunUI
@onready var currency_ui = $CurrencyUI

func _ready() -> void:
	SaveManager.started_saving.connect(func(): saving_indicator.visible = true)
	SaveManager.finished_saving.connect(hide_saving_indicator)
	pause_ui.setting_ui.setting_changed.connect(refresh_after_setting_changed)
	refresh_after_setting_changed()


func hide_saving_indicator():
	await get_tree().create_timer(0.5).timeout
	saving_indicator.visible = false

func refresh_after_setting_changed():
	health_ui.visible = not GameManager.hide_ui
	interact_ui.visible = not GameManager.hide_ui
	gun_ui.visible = not GameManager.hide_ui
	currency_ui.visible = not GameManager.hide_ui
