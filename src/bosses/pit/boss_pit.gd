extends BossCore
class_name BossPit


func _ready() -> void:
	super()
	await get_tree().physics_frame
	state_chart.send_event("start_moving")
