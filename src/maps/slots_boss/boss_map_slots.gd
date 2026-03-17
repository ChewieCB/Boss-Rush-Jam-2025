extends BossMap

@export var fan_blades: AnimatableBody3D


func _physics_process(delta: float) -> void:
	fan_blades.rotate_y(delta)
