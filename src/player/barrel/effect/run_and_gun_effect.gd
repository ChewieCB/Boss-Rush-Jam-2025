extends BaseBarrelEffect

# Focus goes from -1 (max penalty) to 1 (max bonus).
# Dashing or not looking at an enemy drains focus
# Keep looking at an enemy build focus

# max focus
@export var modify_perc_spread_focused: float
@export var modify_perc_damage_focused: float
# negative focus
@export var modify_perc_spread_unfocused: float
@export var modify_perc_damage_unfocused: float

@export var focus_lost_per_dash: float = 0.3
@export var focus_lost_per_second: float = 0.1
@export var recover_delay_after_dash: float = 0.5
# In second, time from -1 focus to 1 focus
@export var full_focus_charge_time: float = 8.0

@export var focus_audio_buses: Array[StringName] = [&"BGM", &"SFX"]
@export var max_focus_lowpass_cutoff_hz: float = 1200.0
@export var max_focus_distortion_drive: float = 0.5
@export var max_focus_volume_reduction_db: float = 5.0
@export var max_focus_bgm_volume_reduction_db: float = 8.0
# Audio distortion and tunnel vision vignette fade in from this focus to max focus
@export var fx_start_focus: float = 0.6

# Ease the focus change after a dash so it smoother
const FOCUS_DROP_SPEED = 4.0
const AUDIO_FOLLOW_SPEED = 2.0
const NO_FILTER_CUTOFF_HZ = 20000.0

var target_focus = 0.0
var focus = 0.0
var time_since_dash = 0.0

var audio_strength = 0.0
# 0 to 1, audio_strength remapped from fx_start_focus to max focus
var fx_strength = 0.0
# Note: AudioEffectLowPassFilter, AudioEffectDistortion
var bus_audio_effects: Dictionary = {}


func _process(delta: float) -> void:
	if owner_barrel == null:
		return

	if time_since_dash < recover_delay_after_dash:
		time_since_dash += delta

	if not is_looking_at_enemy():
		target_focus = max(target_focus - delta * focus_lost_per_second, -1.0)
	elif time_since_dash >= recover_delay_after_dash and full_focus_charge_time > 0:
		target_focus = min(target_focus + delta * 2.0 / full_focus_charge_time, 1.0)

	if focus > target_focus:
		focus = move_toward(focus, target_focus, delta * FOCUS_DROP_SPEED)
	else:
		focus = target_focus

	update_focus_audio(delta)

func _exit_tree() -> void:
	remove_focus_audio_effects()
	GameManager.set_fmod_bgm_duck_multiplier(1.0)

func is_effect_active() -> bool:
	return owner_barrel.get_active_effect() == self and not owner_barrel.is_spinning

func is_looking_at_enemy() -> bool:
	return GameManager.player.aim_assist_ray_boss_check.is_colliding()

func on_barrel_install():
	super()
	reset_focus()

func on_barrel_remove():
	super()
	reset_focus()
	remove_focus_audio_effects()
	GameManager.set_fmod_bgm_duck_multiplier(1.0)

func on_dash_movement():
	super()
	target_focus = max(target_focus - focus_lost_per_dash, -1.0)
	time_since_dash = 0.0

func reset_focus():
	target_focus = 0.0
	focus = 0.0
	time_since_dash = 0.0

func get_focus_modifier(focused_value: float, unfocused_value: float) -> float:
	if focus >= 0:
		return focused_value * focus
	return unfocused_value * -focus

func on_prepare_to_fire():
	super()
	owner_barrel.owner_gun.modified_spread_angle = preview_spread_angle(owner_barrel.owner_gun.modified_spread_angle)

func preview_spread_angle(spread_angle: float) -> float:
	var modify_perc = get_focus_modifier(modify_perc_spread_focused, modify_perc_spread_unfocused)
	return round(spread_angle * (1 + modify_perc / 100.0))

func on_gun_damage_calculation():
	super()
	var modify_perc = get_focus_modifier(modify_perc_damage_focused, modify_perc_damage_unfocused)
	owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + modify_perc / 100.0))


func update_focus_audio(delta: float):
	var target_strength = max(focus, 0.0) if is_effect_active() else 0.0
	audio_strength = move_toward(audio_strength, target_strength, delta * AUDIO_FOLLOW_SPEED)
	fx_strength = 0.0
	if fx_start_focus < 1.0:
		fx_strength = clamp(inverse_lerp(fx_start_focus, 1.0, audio_strength), 0.0, 1.0)

	update_focus_vignette()
	GameManager.set_fmod_bgm_duck_multiplier(db_to_linear(-max_focus_bgm_volume_reduction_db * fx_strength))

	if fx_strength <= 0.0:
		set_focus_audio_effects_enabled(false)
		return

	if bus_audio_effects.is_empty():
		add_focus_audio_effects()
	set_focus_audio_effects_enabled(true)

	var cutoff = NO_FILTER_CUTOFF_HZ * pow(max_focus_lowpass_cutoff_hz / NO_FILTER_CUTOFF_HZ, fx_strength)
	for bus_name in bus_audio_effects:
		var lowpass: AudioEffectLowPassFilter = bus_audio_effects[bus_name][0]
		var distortion: AudioEffectDistortion = bus_audio_effects[bus_name][1]
		lowpass.cutoff_hz = cutoff
		distortion.drive = max_focus_distortion_drive * fx_strength
		distortion.post_gain = - max_focus_volume_reduction_db * fx_strength

func add_focus_audio_effects():
	for bus_name in focus_audio_buses:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			continue
		var lowpass = AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = NO_FILTER_CUTOFF_HZ
		var distortion = AudioEffectDistortion.new()
		distortion.mode = AudioEffectDistortion.MODE_OVERDRIVE
		distortion.drive = 0.0
		AudioServer.add_bus_effect(bus_idx, lowpass)
		AudioServer.add_bus_effect(bus_idx, distortion)
		bus_audio_effects[bus_name] = [lowpass, distortion]

func remove_focus_audio_effects():
	for bus_name in bus_audio_effects:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			continue
		for i in range(AudioServer.get_bus_effect_count(bus_idx) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus_idx, i) in bus_audio_effects[bus_name]:
				AudioServer.remove_bus_effect(bus_idx, i)
	bus_audio_effects.clear()
	audio_strength = 0.0
	fx_strength = 0.0
	update_focus_vignette()

func set_focus_audio_effects_enabled(enabled: bool):
	for bus_name in bus_audio_effects:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			continue
		for i in AudioServer.get_bus_effect_count(bus_idx):
			if AudioServer.get_bus_effect(bus_idx, i) in bus_audio_effects[bus_name]:
				AudioServer.set_bus_effect_enabled(bus_idx, i, enabled)

func update_focus_vignette():
	if not is_instance_valid(GameManager.player):
		return
	var rect: ColorRect = GameManager.player.focus_vignette
	rect.visible = fx_strength > 0.0
	rect.material.set_shader_parameter("intensity", fx_strength)
