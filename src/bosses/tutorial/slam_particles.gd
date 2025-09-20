extends GPUParticles3D

@onready var floor_ray: RayCast3D = $RayCast3D

var is_on_floor: bool = false


func _physics_process(delta: float) -> void:
	if is_on_floor:
		if floor_ray.is_colliding():
			var floor_y = floor_ray.get_collision_point().y
			self.global_position.y = floor_y
