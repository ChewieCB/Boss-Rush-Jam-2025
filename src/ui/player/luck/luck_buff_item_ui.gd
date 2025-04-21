extends MarginContainer

@export var hover_prefab: PackedScene

@export var hover_time: float = 0.3
@onready var hover_timer: Timer = $HoverTimer

var hover: Control


func _on_texture_rect_mouse_entered() -> void:
	if not get_tree().paused or hover:
		return
	hover_timer.start(hover_time)


func _on_texture_rect_mouse_exited() -> void:
	if hover and hover_timer.is_stopped():
		hover.queue_free()
		remove_child(hover)
		hover = null
	if not get_tree().paused:
		return
	hover_timer.stop()


func _on_hover_timer_timeout() -> void:
	# Show hover UI
	hover = hover_prefab.instantiate()
	add_child(hover)
