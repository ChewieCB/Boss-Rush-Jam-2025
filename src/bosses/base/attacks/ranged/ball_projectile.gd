extends TestProjectile

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _physics_process(delta: float) -> void:
	super(delta)
	mesh.rotation.x += delta
	mesh.rotation.y += delta
	mesh.rotation.z += delta
