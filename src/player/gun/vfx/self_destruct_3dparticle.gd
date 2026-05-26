extends GPUParticles3D


func _on_finished():
	deactivate()


func activate() -> void:
	self.visible = true
	restart()
	self.process_mode = Node.PROCESS_MODE_INHERIT


func deactivate() -> void:
	emitting = false
	self.visible = false
	self.process_mode = Node.PROCESS_MODE_DISABLED
