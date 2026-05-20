extends CanvasLayer
class_name PlayerUI

@onready var saving_indicator: Label = $SavingIndicator
@onready var pause_ui: PauseUI = $PauseUI

@onready var stat_ui: StatUI = $StatUI
@onready var interact_ui = $InteractUI
@onready var gun_ui = $GunUI
@onready var reticle_ui_1 = $GunUI/AimRecticle
@onready var reticle_ui_2 = $GunUI/AimRecticle2
@onready var heal_flash_overlay: ColorRect = $StatusOverlay/HealFlash

func _ready() -> void:
	SaveManager.started_saving.connect(func(): saving_indicator.visible = true)
	SaveManager.finished_saving.connect(hide_saving_indicator)
	pause_ui.setting_ui.setting_changed.connect(refresh_after_setting_changed)
	refresh_after_setting_changed()


#func update_luck_modifier_text(text: String, is_gain: bool) -> void:
	#luck_modifier_text.text = text
	#luck_modifier_text.visible = true
	## TODO - add configurable timing and animation
	#await get_tree().create_timer(1.0, false).timeout
	#luck_modifier_text.text = ""
	#luck_modifier_text.visible = false


func toggle_aim_reticle(_visible: bool) -> void:
	for ui in [reticle_ui_1, reticle_ui_2]:
		ui.visible = _visible


func hide_saving_indicator():
	await get_tree().create_timer(0.5).timeout
	saving_indicator.visible = false


func refresh_after_setting_changed():
	stat_ui.visible = not GameManager.hide_ui
	interact_ui.visible = not GameManager.hide_ui
	# NOTE: Currently GunUI only show barrels info when user press "tab" so no need to hide it
	# However, if there is more elements are added in the future then it will need modification.
	# gun_ui.visible = not GameManager.hide_ui

func start_heal_flash() -> void:
	const DURATION = 1
	var start_color = Color(0.47, 0.82, 0, 0.4) # GREEN
	heal_flash_overlay.color = start_color
	var tween = create_tween()
	tween.tween_property(heal_flash_overlay, "color:a", 0.0, DURATION)