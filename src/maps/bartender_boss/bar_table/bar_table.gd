extends StaticBody3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var timer: Timer = $ResetTimer
@onready var kick_table_sfx: AudioStreamPlayer3D = $KickTableSFX
@onready var parry_light: OmniLight3D = $ParryArea/ParryLight

var last_anim_played = ''
var interact_disabled = false
var is_parrying = false

const TABLE_PARRY_TIMESTOP_DURATION = 0.2

func _ready() -> void:
	parry_light.light_energy = 0

func interact():
	if interact_disabled:
		return

	var dir_to_table = (global_position - GameManager.player.global_position).normalized()
	var table_forward = - global_transform.basis.z.normalized()
	var dot = dir_to_table.dot(table_forward)
	if dot > 0:
		last_anim_played = 'flip_front'
	else:
		last_anim_played = 'flip_back'

	anim_player.play(last_anim_played)
	kick_table_sfx.play()
	interact_disabled = true
	timer.start()

func set_parrying_state(value: bool) -> void:
	is_parrying = value

func get_interact_text() -> String:
	if interact_disabled:
		return "Can't interact"
	return "Kick table"


func _on_reset_timer_timeout() -> void:
	anim_player.play_backwards(last_anim_played)
	interact_disabled = false


func play_table_parry_effect():
	parry_light.light_energy = 5
	GameManager.player_ui.play_parried_effect(TABLE_PARRY_TIMESTOP_DURATION)
	parry_light.light_energy = 0

func _on_parry_area_area_entered(area: Area3D) -> void:
	if not is_parrying:
		return
	if area.has_method("parried"):
		area.parried()
		play_table_parry_effect()
		return
	elif area.get_parent() and area.get_parent().has_method("parried"):
		area.get_parent().parried()
		play_table_parry_effect()

func _on_parry_area_body_entered(body: Node3D) -> void:
	if not is_parrying:
		return
	if body.has_method("parried"):
		body.parried()
		play_table_parry_effect()
		return
	elif body.get_parent() and body.get_parent().has_method("parried"):
		body.get_parent().parried()
		play_table_parry_effect()
