extends Label3D

func _ready() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0, 2.5)
	tween.parallel().tween_property(self, "position:y", 6, 2.5)
	tween.tween_callback(self.queue_free)
