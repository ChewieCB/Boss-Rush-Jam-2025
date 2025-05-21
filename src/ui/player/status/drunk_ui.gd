extends Control


@onready var rect: ColorRect = $ColorRect
var drunk_tween: Tween
@export var lower_blur: float = 0.015
@export var upper_blur: float = 0.03

@onready var bgm_bus_lowpass := AudioServer.get_bus_effect(1, 1) as AudioEffectLowPassFilter
@onready var sfx_bus_lowpass := AudioServer.get_bus_effect(2, 0) as AudioEffectLowPassFilter


func _ready() -> void:
	GameManager.setting_changed.connect(_on_setting_changed)


func _on_setting_changed() -> void:
	if GameManager.drunk_blur_disabled:
		rect.color.a = 0.0
	else:
		rect.color.a = 1.0


func start_drunk() -> void:
	if GameManager.drunk_blur_disabled:
		return
	# Toggle low pass filter for BGM
	# FIXME
	#AudioServer.set_bus_effect_enabled(1, 1, true)
	#AudioServer.set_bus_effect_enabled(2, 0, true)
	
	# Setup tween
	drunk_tween = create_tween()
	drunk_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Tween into drunk effect
	drunk_tween.tween_method(
		_set_blur_amount, 0.0, lower_blur, 0.6
	).set_ease(Tween.EASE_IN)
	drunk_tween.parallel().tween_property(
		rect, "color:a", 1.0, 0.6
	).set_ease(Tween.EASE_IN)
	# FIXME - rework this low pass to be less aggressive
	#drunk_tween.parallel().tween_property(
		#bgm_bus_lowpass, "cutoff_hz", 1400, 0.6
	#).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	#drunk_tween.parallel().tween_property(
		#sfx_bus_lowpass, "cutoff_hz", 1400, 0.6
	#).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	#drunk_tween.parallel().tween_property(
		#bgm_bus_lowpass, "resonance", 0.8, 0.6
	#).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	#drunk_tween.parallel().tween_property(
		#sfx_bus_lowpass, "resonance", 0.8, 0.6
	#).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	await drunk_tween.finished
	
	# Cycle between blurs
	drunk_tween = create_tween()
	drunk_tween.chain().tween_method(
		_set_blur_amount, lower_blur, upper_blur, 0.8
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	drunk_tween.chain().tween_method(
		_set_blur_amount, upper_blur, lower_blur, 0.8
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	drunk_tween.set_loops()


func end_drunk() -> void:
	if drunk_tween:
		drunk_tween.kill()
	drunk_tween = create_tween()
	
	var current_blur = rect.material.get("shader_parameter/blur_power")
	drunk_tween.tween_method(
		_set_blur_amount, current_blur, 0.0, 0.3
	).set_ease(Tween.EASE_OUT)
	drunk_tween.parallel().tween_property(
		rect, "color:a", 0.0, 0.6
	).set_ease(Tween.EASE_OUT)
	# FIXME - rework this low pass to be less aggressive
	#drunk_tween.parallel().tween_property(
		#bgm_bus_lowpass, "cutoff_hz", 2000, 0.6
	#).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	#drunk_tween.parallel().tween_property(
		#sfx_bus_lowpass, "cutoff_hz", 2000, 0.6
	#).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	#drunk_tween.parallel().tween_property(
		#bgm_bus_lowpass, "resonance", 0.0, 0.6
	#).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	#drunk_tween.parallel().tween_property(
		#sfx_bus_lowpass, "resonance", 0.0, 0.6
	#).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	#
	## Toggle low pass filter for BGM
	#AudioServer.set_bus_effect_enabled(1, 1, false)
	#AudioServer.set_bus_effect_enabled(2, 0, false)


func _set_blur_amount(amount: float) -> void:
	rect.material.set("shader_parameter/blur_power", amount)
