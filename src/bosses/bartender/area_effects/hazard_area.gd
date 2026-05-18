extends Node3D
class_name HazardArea

@export var damage_per_tick: int = 5
@export var duration: float = 5
@export var slow_perc: float = 0
@export var puddle_decal: Decal

@export var sfx_break: Array[AudioStream]
@export var sfx_effect: Array[AudioStream]
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer

@export var particle_effects: Array[GPUParticles3D] = []

@export var pe_expire_time = 2

@onready var dot_timer: Timer = $DoTTimer
@onready var life_timer: Timer = $LifeTimer
@onready var raycast: RayCast3D = $RayCast3D
@onready var light: OmniLight3D = $OmniLight3D

var bodies_inside = []
var is_active = false
var stopped_moving = false

var dash_speed_buff_icon = preload("res://assets/sprite/status_icon/dash_speed_down.png")
var run_speed_buff_icon = preload("res://assets/sprite/status_icon/run_speed_down.png")

func _ready() -> void:
	pass


func start_hazard() -> void:
	is_active = true
	if sfx_break:
		sfx_player.stream = sfx_break.pick_random()
		sfx_player.play()
	life_timer.start(duration)
	if sfx_effect:
		if sfx_player.playing:
			await sfx_player.finished
		sfx_player.stream = sfx_effect.pick_random()
		sfx_player.play()


func set_duration_and_restart_timer(new_duration: float):
	duration = new_duration
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
			body.add_status_effect(run_debuff)
			var dash_debuff = create_slow_dash_debuff(1)
			body.add_status_effect(dash_debuff)


func clear_hazard():
	is_active = false
	for pe in particle_effects:
		pe.emitting = false
	if puddle_decal:
		var tween = self.create_tween()
		tween.tween_property(puddle_decal, "modulate:a", 0, 2.0)
	var tween2 = self.create_tween()
	tween2.tween_property(light, "light_energy", 0, 2.0)
	# Wait until all particles expired
	await get_tree().create_timer(pe_expire_time).timeout
	#call_deferred("queue_free")


func _on_life_timer_timeout() -> void:
	clear_hazard()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.get_node("HealthComponent"):
		bodies_inside.append(body)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.get_node("HealthComponent") and body in bodies_inside:
		bodies_inside.erase(body)

func create_slow_run_debuff(debuff_duration: float = 1) -> StatusEffect:
	var slow_run_debuff = StatusEffect.new()
	slow_run_debuff.display_name = "Run speed down"
	slow_run_debuff.status_code = "slow_hazard_run_speed"
	slow_run_debuff.modified_stat = StatusEffect.PlayerStatEnum.RUN_SPEED_MODIFIER
	slow_run_debuff.value = - slow_perc
	slow_run_debuff.modify_type = StatusEffect.ModifyType.PERCENTAGE
	slow_run_debuff.duration = debuff_duration
	slow_run_debuff.is_bad_effect = true
	slow_run_debuff.status_icon = run_speed_buff_icon
	return slow_run_debuff

func create_slow_dash_debuff(debuff_duration: float = 1) -> StatusEffect:
	var slow_dash_debuff = StatusEffect.new()
	slow_dash_debuff.display_name = "Dash speed down"
	slow_dash_debuff.status_code = "slow_hazard_dash_slide_speed"
	slow_dash_debuff.modified_stat = StatusEffect.PlayerStatEnum.DASH_SPEED_MODIFIER
	slow_dash_debuff.value = - slow_perc
	slow_dash_debuff.modify_type = StatusEffect.ModifyType.PERCENTAGE
	slow_dash_debuff.duration = debuff_duration
	slow_dash_debuff.is_bad_effect = true
	slow_dash_debuff.status_icon = dash_speed_buff_icon
	return slow_dash_debuff
