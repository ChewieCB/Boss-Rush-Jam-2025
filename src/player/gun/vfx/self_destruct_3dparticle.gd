extends GPUParticles3D

@export var queue_free_on_finished = false

func _on_finished():
	if queue_free_on_finished:
		queue_free()
		return
	
	deactivate()


func activate() -> void:
	self.visible = true
	restart()
	self.process_mode = Node.PROCESS_MODE_INHERIT


func deactivate() -> void:
	emitting = false
	self.visible = false
	self.process_mode = Node.PROCESS_MODE_DISABLED
