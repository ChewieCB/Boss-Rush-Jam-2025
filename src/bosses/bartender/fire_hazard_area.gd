extends Node3D
class_name FireHazardArea

@export var damage_per_tick: int = 5
@export var duration: float = 5

@onready var dot_timer: Timer = $DoTTimer
@onready var life_timer: Timer = $LifeTimer
@onready var raycast: RayCast3D = $RayCast3D

var bodies_inside = []

func _ready() -> void:
	life_timer.start(duration)

func set_stat(_duration: float, _damage: int):
	damage_per_tick = _damage
	duration = _duration
	life_timer.start(duration)

func _physics_process(delta: float) -> void:
	if not raycast.is_colliding():
		global_position += Vector3(0, -9.8, 0) * delta


func _on_damage_timer_timeout() -> void:
	for body in bodies_inside:
		body.get_node("HealthComponent").damage(damage_per_tick)

func _on_life_timer_timeout() -> void:
	queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.get_node("HealthComponent"):
		bodies_inside.append(body)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.get_node("HealthComponent") and body in bodies_inside:
		bodies_inside.erase(body)
