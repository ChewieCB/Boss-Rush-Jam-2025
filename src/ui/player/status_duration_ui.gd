extends TextureProgressBar

@export var good_effect_color: Color
@export var bad_effect_color: Color
@export var default_status_down: Texture2D
@export var default_status_up: Texture2D

@onready var timer: Timer = $Timer
@onready var label: Label = $Label

var status_effect: StatusEffect
var max_time: float


func _process(_delta: float) -> void:
	if status_effect == null:
		return
	# Status_effect timetracking is handled in Player.gd, and since it's a
	# referenced object, it duration value (aka duration left) will change here too
	value = int((status_effect.duration / max_time) * 100)
	if status_effect.duration <= 0:
		call_deferred("queue_free")


func init(_status_effect: StatusEffect) -> void:
	status_effect = _status_effect
	# Set icon
	if status_effect.status_icon != null:
		texture_under = status_effect.status_icon
		texture_progress = status_effect.status_icon
	else:
		if status_effect.is_bad_effect:
			texture_under = default_status_down
			texture_progress = default_status_down
		else:
			texture_under = default_status_up
			texture_progress = default_status_up
	# Set color
	if status_effect.is_bad_effect:
		tint_progress = bad_effect_color
	else:
		tint_progress = good_effect_color
	# Start timer
	max_time = status_effect.duration
	timer.start(status_effect.duration)

	if status_effect.show_value_on_ui:
		label.text = str(int(status_effect.value))
	else:
		label.text = ""

func refresh(updated_status: StatusEffect):
	status_effect = updated_status
	max_time = status_effect.duration
	timer.start(status_effect.duration)
	if status_effect.show_value_on_ui:
		label.text = str(int(status_effect.value))
	else:
		label.text = ""

func remove():
	call_deferred("queue_free")
