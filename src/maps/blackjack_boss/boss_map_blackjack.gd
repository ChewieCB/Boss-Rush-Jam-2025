extends BossMap


@export var flying_navmesh: Node3D


func _ready() -> void:
	var flying_nav_points = flying_navmesh.get_points()
	boss.flyable_points = flying_nav_points
	super()
