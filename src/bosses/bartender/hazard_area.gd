extends Node3D
class_name HazardArea

@export var damage_per_tick: int = 5
@export var duration: float = 5
@export var slow_perc: float = 0

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
		if damage_per_tick > 0:
			body.get_node("HealthComponent").damage(damage_per_tick)

		if body is Player and slow_perc > 0:
			var run_debuff = create_slow_run_debuff(1)
			body.add_buff(run_debuff)
			var dash_debuff = create_slow_dash_debuff(1)
			body.add_buff(dash_debuff)


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

func create_slow_run_debuff(debuff_duration: float = 1) -> Buff:
	var slow_debuff = Buff.new()
	slow_debuff.buff_name = "slow_hazard_run_speed"
	slow_debuff.stat_name = "run_speed_modifier"
	slow_debuff.value = -slow_perc
	slow_debuff.buff_type = Buff.BuffType.PERCENTAGE
	slow_debuff.stack_type = Buff.StackType.ADDITIVE
	slow_debuff.duration = debuff_duration
	return slow_debuff

func create_slow_dash_debuff(debuff_duration: float = 1) -> Buff:
	var slow_debuff = Buff.new()
	slow_debuff.buff_name = "slow_hazard_dash_slide_speed"
	slow_debuff.stat_name = "dash_slide_speed_modifier"
	slow_debuff.value = -slow_perc
	slow_debuff.buff_type = Buff.BuffType.PERCENTAGE
	slow_debuff.stack_type = Buff.StackType.ADDITIVE
	slow_debuff.duration = debuff_duration
	return slow_debuff
