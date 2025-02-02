extends Node3D  # Parent node

@export var radius: float = 2.0
@export var rotation_speed: float = 1.0  # Radians per second

var shields = []
var shield_count = 0

func _ready():
	shields = get_children()
	shield_count = len(shields)

func _process(_delta: float):
	for i in range(shield_count):
		var angle = (i / float(shield_count)) * TAU + rotation_speed * Time.get_ticks_msec() / 1000.0
		var x = cos(angle) * radius
		var z = sin(angle) * radius
		shields[i].global_transform.origin = global_transform.origin + Vector3(x, 0, z)
		
		# Make the shield face outward
		shields[i].look_at(global_transform.origin, Vector3.UP)
