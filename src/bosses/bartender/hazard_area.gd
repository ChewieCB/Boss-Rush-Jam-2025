extends Node3D
class_name HazardArea

@export var damage_per_tick: int = 5
@export var duration: float = 5
@export var particle_effects: Array[GPUParticles3D] = []
@export var pe_expire_time = 2


@onready var dot_timer: Timer = $DoTTimer
@onready var life_timer: Timer = $LifeTimer
@onready var raycast: RayCast3D = $RayCast3D
@onready var puddle_sprite: Sprite3D = $Puddle
@onready var light: OmniLight3D = $OmniLight3D

var bodies_inside = []
var is_active = false
var stopped_moving = false

func _ready() -> void:
	is_active = true
	life_timer.start(duration)

func _physics_process(delta: float) -> void:
	if stopped_moving:
		return

	if not raycast.is_colliding():
		global_position += Vector3(0, -9.8, 0) * delta
	else:
		stopped_moving = true
		var col_point = raycast.get_collision_point()
		global_position.y = col_point.y


func _on_damage_timer_timeout() -> void:
	if not is_active:
		return
	for body in bodies_inside:
		body.get_node("HealthComponent").damage(damage_per_tick)

func _on_life_timer_timeout() -> void:
	is_active = false
	for pe in particle_effects:
		pe.emitting = false
	var tween = self.create_tween()
	tween.tween_property(puddle_sprite, "modulate:a", 0, 2.0)
	var tween2 = self.create_tween()
	tween2.tween_property(light, "light_energy", 0, 2.0)
	# Wait until all particles expired
	await get_tree().create_timer(pe_expire_time).timeout
	call_deferred("queue_free")


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.get_node("HealthComponent"):
		bodies_inside.append(body)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.get_node("HealthComponent") and body in bodies_inside:
		bodies_inside.erase(body)
