extends Node3D
class_name FireHazardArea

@export var damage_per_tick: int = 5
@export var duration: float = 5
@export var size_scale: float = 1

@onready var dot_timer: Timer = $DoTTimer
@onready var life_timer: Timer = $LifeTimer
@onready var raycast: RayCast3D = $RayCast3D
@onready var fire_vfx: GPUParticles3D = $Fire
@onready var smoke_vfx: GPUParticles3D = $Smoke
@onready var puddle_sprite: Sprite3D = $Puddle
@onready var light: OmniLight3D = $OmniLight3D

var bodies_inside = []
var is_active = false

func _ready() -> void:
	is_active = true
	life_timer.start(duration)

func _physics_process(delta: float) -> void:
	if not raycast.is_colliding():
		global_position += Vector3(0, -9.8, 0) * delta


func _on_damage_timer_timeout() -> void:
	if not is_active:
		return
	for body in bodies_inside:
		body.get_node("HealthComponent").damage(damage_per_tick)

func _on_life_timer_timeout() -> void:
	is_active = false
	fire_vfx.emitting = false
	smoke_vfx.emitting = false
	var tween = self.create_tween()
	tween.tween_property(puddle_sprite, "modulate:a", 0, 2.0)
	var tween2 = self.create_tween()
	tween2.tween_property(light, "light_energy", 0, 2.0)
	# Wait until all particles expired
	await get_tree().create_timer(2.0).timeout
	call_deferred("queue_free")


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.get_node("HealthComponent"):
		bodies_inside.append(body)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.get_node("HealthComponent") and body in bodies_inside:
		bodies_inside.erase(body)
