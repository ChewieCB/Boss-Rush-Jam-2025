extends StaticBody3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var timer: Timer = $ResetTimer
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var last_anim_played = ''
var interact_disabled = false

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
	audio_player.play()
	interact_disabled = true
	timer.start()

func get_interact_text() -> String:
	if interact_disabled:
		return "Can't interact"
	return "Kick table"


func _on_reset_timer_timeout() -> void:
	anim_player.play_backwards(last_anim_played)
	interact_disabled = false
