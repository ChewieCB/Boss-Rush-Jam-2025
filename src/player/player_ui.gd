extends CanvasLayer
class_name PlayerUI

@onready var saving_indicator: Label = $SavingIndicator
@onready var pause_ui: PauseUI = $PauseUI
@onready var stat_ui: StatUI = $StatUI
@onready var interact_ui = $InteractUI
@onready var gun_ui = $GunUI

@onready var parry_flash: ColorRect = $OtherEffectUI/ParryFlash
@onready var parry_flash_cd_timer: Timer = $OtherEffectUI/ParryFlashCDTimer

var parry_sfx = preload("res://src/maps/bartender_boss/bar_table/446128__justinvoke__metal-clank-4.wav")

func _ready() -> void:
	GameManager.player_ui = self
	SaveManager.started_saving.connect(func(): saving_indicator.visible = true)
	SaveManager.finished_saving.connect(hide_saving_indicator)
	pause_ui.setting_ui.setting_changed.connect(refresh_after_setting_changed)
	refresh_after_setting_changed()


func hide_saving_indicator() -> void:
	await get_tree().create_timer(0.5).timeout
	saving_indicator.visible = false


func refresh_after_setting_changed() -> void:
	stat_ui.visible = not GameManager.hide_ui
	interact_ui.visible = not GameManager.hide_ui
	# NOTE: Currently GunUI only show barrels info when user press "tab" so no need to hide it
	# However, if there is more elements are added in the future then it will need modification.
	# gun_ui.visible = not GameManager.hide_ui

func play_parried_effect(timestop_duration: float = 0.1) -> void:
	if not parry_flash_cd_timer.is_stopped():
		return
	parry_flash_cd_timer.start()
	SoundManager.play_sound(parry_sfx, "SFX")
	parry_flash.visible = true
	var original_time_scale = Engine.time_scale
	Engine.time_scale = 0.01
	await get_tree().create_timer(timestop_duration, false, false, true).timeout
	Engine.time_scale = original_time_scale
	parry_flash.visible = false
	parry_flash_cd_timer.start()
