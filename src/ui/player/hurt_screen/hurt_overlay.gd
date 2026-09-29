extends Control

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree

@onready var vignette: ColorRect = $LowHealthOverlay/HurtVignette
@onready var stun_shader: ColorRect = $StunShader
@onready var damage_dir_markers: ColorRect = $DamageDirectionMarkers
@onready var dodge_flash: ColorRect = $DodgeFlash
@onready var player: Player = get_parent().get_parent()
const MAX_DAMAGE_MARKERS: int = 16
var active_damage_markers: Array = []
var hit_trackers: Array[Node3D] = []
var marker_generations: Array[int] = []
var oldest_marker_idx: int = 0

@onready var hurt_blood: TextureRect = $HurtFlash/BloodSplatter
@export var hurt_blood_textures: Array[Texture]
@onready var low_health_overlay: Control = $LowHealthOverlay
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var low_health_tween: Tween
var dodge_flash_tween: Tween

const DODGE_FLASH_IN_TIME: float = 0.03
const DODGE_FLASH_OUT_TIME: float = 0.3

@export var sfx_low_health_slow: Array[AudioStream]
@export var sfx_low_health_medium: Array[AudioStream]
@export var sfx_low_health_fast: Array[AudioStream]
var sfx_low_health_arr: Array[AudioStream] = sfx_low_health_slow


func _ready() -> void:
	dodge_flash.hide()
	_set_dodge_flash_intensity(0.0)

	for i in range(MAX_DAMAGE_MARKERS):
		active_damage_markers.append(null)
		marker_generations.append(0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i in range(MAX_DAMAGE_MARKERS):
		var _tracker := Node3D.new()
		damage_dir_markers.add_child(_tracker)
		hit_trackers.append(_tracker)


func _physics_process(delta: float) -> void:
	update_damage_dir_markers(delta)


func hurt(damage_pos: Vector3 = Vector3.INF) -> void:
	if GameManager.hide_hurt_overlay:
		return

	hurt_blood.texture = hurt_blood_textures.pick_random()
	anim_tree["parameters/hurt_shot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

	if damage_pos != Vector3.INF:
		add_damage_dir_marker(damage_pos)


# Active the dodge shader effect
func dodge() -> void:
	if dodge_flash_tween:
		dodge_flash_tween.kill()

	dodge_flash.show()
	dodge_flash_tween = create_tween().set_speed_scale(1 / Engine.time_scale)
	dodge_flash_tween.tween_method(_set_dodge_flash_intensity, 0.0, 1.0, DODGE_FLASH_IN_TIME)
	dodge_flash_tween.tween_method(_set_dodge_flash_intensity, 1.0, 0.0, DODGE_FLASH_OUT_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	dodge_flash_tween.tween_callback(dodge_flash.hide)


func _set_dodge_flash_intensity(value: float) -> void:
	dodge_flash.material.set_shader_parameter("intensity", value)


func update_low_health_anim(base_alpha: float, speed: float = 1.0) -> void:
	anim_tree["parameters/low_health_blend/blend_amount"] = base_alpha
	
	# Speed ranges from 1.0 -> 1.8
	var _sfx_idx: int = int(roundf(remap(speed, 1.0, 1.8, 1, 3)))
	match _sfx_idx:
		1:
			sfx_low_health_arr = sfx_low_health_slow
		2:
			sfx_low_health_arr = sfx_low_health_medium
		3:
			sfx_low_health_arr = sfx_low_health_fast
	sfx_player.volume_db = remap(speed, 1.0, 1.6, -20.0, 0.0)

	if base_alpha == 0.0:
		return

	# Opacity
	# Transparency should go LOW -> HIGH -> LOW
	var low_alpha: float = 0.545
	var high_alpha: float = 1.0
	var low_health_anim: Animation = anim_player.get_animation("low_health_throb")
	low_health_anim.track_set_key_value(0, 0, Color(1, 1, 1, low_alpha * base_alpha))
	low_health_anim.track_set_key_value(0, 1, Color(1, 1, 1, high_alpha * base_alpha))
	low_health_anim.track_set_key_value(0, 2, Color(1, 1, 1, low_alpha * base_alpha))
	anim_tree["parameters/low_health_speed/scale"] = speed


func _heartbeat_sfx() -> void:
	sfx_player.stream = sfx_low_health_arr.pick_random()
	sfx_player.play()


func get_marker_dir(source_pos: Vector3) -> float:
	var player_forward: Vector3 = - player.global_transform.basis.z
	var to_source: Vector3 = player.global_position.direction_to(source_pos)
	var forward_2d := Vector2(player_forward.x, player_forward.z)
	var source_2d := Vector2(to_source.x, to_source.z)

	# 0 = source directly ahead, +90 = right, 180 = behind, -90 = left
	var ui_angle: float = forward_2d.angle_to(source_2d)

	# Convert to the shader's angle convention
	var shader_angle: float = ui_angle - (PI / 2.0)
	if shader_angle < 0.0:
		shader_angle += 2.0 * PI

	return shader_angle


func add_damage_dir_marker(damage_pos: Vector3) -> void:
	if hit_trackers.size() < MAX_DAMAGE_MARKERS:
		return # Trackers not created yet

	var arc_alphas = damage_dir_markers.material.get_shader_parameter("arc_alpha")

	# Use the first free slot, or recycle the oldest marker if all are in use
	var new_idx: int = active_damage_markers.find(null)
	if new_idx == -1:
		new_idx = oldest_marker_idx
		oldest_marker_idx = (oldest_marker_idx + 1) % MAX_DAMAGE_MARKERS
	marker_generations[new_idx] += 1

	var damage_source: Node3D = hit_trackers[new_idx]
	damage_source.global_position = damage_pos
	active_damage_markers[new_idx] = damage_source
	arc_alphas[new_idx] = 1.0

	damage_dir_markers.material.set_shader_parameter("active_arcs_count", _count_active_markers())
	damage_dir_markers.material.set_shader_parameter("arc_alpha", arc_alphas)

	get_tree().create_timer(1.0, false).timeout.connect(
		remove_damage_dir_marker.bind(new_idx, marker_generations[new_idx])
	)


func update_damage_dir_markers(delta: float) -> void:
	var active_arcs: int = damage_dir_markers.material.get_shader_parameter("active_arcs_count")
	var start_angles = damage_dir_markers.material.get_shader_parameter("start_angles_degrees")
	var arc_spans = damage_dir_markers.material.get_shader_parameter("arc_spans_degrees")
	var arc_alphas = damage_dir_markers.material.get_shader_parameter("arc_alpha")

	# Update params
	for idx in active_damage_markers.size():
		var source = active_damage_markers[idx]
		if source:
			var _new_angle = get_marker_dir(source.global_position)
			start_angles[idx] = rad_to_deg(_new_angle)
			arc_spans[idx] = 8.0
			arc_alphas[idx] = lerp(arc_alphas[idx], 0.0, delta * 3.0)
		else:
			start_angles[idx] = 0.0
			arc_spans[idx] = 0.0
			arc_alphas[idx] = 0.0

	damage_dir_markers.material.set_shader_parameter("active_arcs_count", active_arcs)
	damage_dir_markers.material.set_shader_parameter("start_angles_degrees", start_angles)
	damage_dir_markers.material.set_shader_parameter("arc_spans_degrees", arc_spans)
	damage_dir_markers.material.set_shader_parameter("arc_alpha", arc_alphas)


func remove_damage_dir_marker(idx: int, generation: int) -> void:
	# Slot was reused by a newer marker since this timer was created
	if marker_generations[idx] != generation:
		return

	active_damage_markers[idx] = null
	damage_dir_markers.material.set_shader_parameter("active_arcs_count", _count_active_markers())


func _count_active_markers() -> int:
	return active_damage_markers.size() - active_damage_markers.count(null)


func stun(stun_time: float) -> void:
	if GameManager.hide_hurt_overlay:
		return
	var tween = get_tree().create_tween()
	vignette.modulate.a = 0
	stun_shader.modulate.a = 0
	tween.tween_property(vignette, "modulate:a", 255.0 / 4.0, 0.2)
	tween.parallel().tween_property(stun_shader, "modulate:a", 255.0 / 4.0, 0.2)
	await get_tree().create_timer(stun_time).timeout
	tween = get_tree().create_tween()
	tween.tween_property(vignette, "modulate:a", 0, 0.2)
	tween.parallel().tween_property(stun_shader, "modulate:a", 0, 0.2)


func dead() -> void:
	if GameManager.hide_hurt_overlay:
		return

	hurt_blood.texture = hurt_blood_textures.pick_random()
	anim_tree["parameters/death_transition/transition_request"] = "dead"
	anim_tree["parameters/low_health_blend/blend_amount"] = 1.0
	anim_tree["parameters/low_health_seek/seek_request"] = 0.5
	anim_tree["parameters/low_health_speed/scale"] = 0.0


func revive() -> void:
	if GameManager.hide_hurt_overlay:
		return

	anim_tree["parameters/death_transition/transition_request"] = "revive"
	anim_tree["parameters/low_health_blend/blend_amount"] = 0.0
	anim_tree["parameters/low_health_seek/seek_request"] = 0.0
	anim_tree["parameters/low_health_speed/scale"] = 0.0
