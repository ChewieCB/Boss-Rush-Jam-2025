extends Node3D
class_name ElevatorShockHazard

signal finished

@export var damage_per_tick: float = 5.0
@export var duration: float = 5
@export var slow_perc: float = 0
@export var puddle_decal: Decal

@export var sfx_effect: Array[AudioStream]
@export var sfx_player: AudioStreamPlayer3D

@export var particle_effects: Array[GPUParticles3D] = []
@export var damage_area: Area3D
@export var immune_bodies: Array[Node3D]

@export var pe_expire_time = 2
@onready var light: OmniLight3D = $OmniLight3D
@onready var life_timer: Timer = $LifeTimer


var bodies_inside = []
var is_active = false:
	set(value):
		is_active = value
		self.visible = is_active
var stopped_moving = false

var dash_speed_buff_icon = preload("res://assets/sprite/status_icon/dash_speed_down.png")
var run_speed_buff_icon = preload("res://assets/sprite/status_icon/run_speed_down.png")

func _ready() -> void:
	#is_active = true
	pass
	#if sfx_effect:
		#if sfx_player.playing:
			#await sfx_player.finished
		#sfx_player.stream = sfx_effect.pick_random()
		#sfx_player.play()


func _on_damage_timer_timeout() -> void:
	if not is_active:
		return
	
	trigger_effect()


func trigger_effect() -> void:
	if is_active:
		for body in bodies_inside:
			if body in immune_bodies:
				continue
			if damage_per_tick > 0:
				body.health_component.damage(damage_per_tick)
			
			if body is Player and slow_perc > 0:
				var run_debuff = create_slow_run_debuff(1)
				body.add_status_effect(run_debuff)
				var dash_debuff = create_slow_dash_debuff(1)
				body.add_status_effect(dash_debuff)


func start_hazard() -> void:
	is_active = true
	life_timer.start(duration)
	if sfx_effect:
		sfx_player.stream = sfx_effect.pick_random()
		sfx_player.play()
	trigger_effect()


func clear_hazard():
	if sfx_player:
		sfx_player.stop()
		
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
	
	finished.emit()


func _on_life_timer_timeout() -> void:
	clear_hazard()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.get_node("HealthComponent"):
		bodies_inside.append(body)
		if is_active:
			trigger_effect()


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
