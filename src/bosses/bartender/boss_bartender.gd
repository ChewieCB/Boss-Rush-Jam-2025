extends BossCore

@export_category("Phases")
@export var phase_2_health_percentage_trigger: float = 0.66
@export var phase_3_health_percentage_trigger: float = 0.33

@export_category("Attacks")
@export var shotgun_proj_prefab: PackedScene
@export var molotov_prefab: PackedScene
@export var poison_smoke_prefab: PackedScene
@export var slow_smoke_prefab: PackedScene

@onready var proj_spawn_marker = $ProjectileSpawnPos

var previous_attack: String
var force_shotgun_knockback = false
var proj_spawn_pos

const DIFFICULTY_LV = 1

func _ready() -> void:
	super()
	proj_spawn_pos = proj_spawn_marker.global_position


func _process(delta: float) -> void:
	if target:
		_turn_towards_target(TURN_SPEED_SLOW, delta)

func activate() -> void:
	super()
	change_phase(current_phase)

func change_phase(new_phase: int) -> void:
	# Check if an attack is in progress
	if not $StateChart/Root/Attacking/Idle.active:
		await $StateChart/Root/Attacking/Idle.state_entered
	# TODO - anims/effects/sound for phase change
	#
	# Change phase
	var phase_event: String
	match new_phase:
		1:
			phase_event = "start_phase_1"
		2:
			phase_event = "start_phase_2"
		3:
			phase_event = "start_phase_3"
	
	state_chart.send_event(phase_event)


func select_attack() -> void:
	match current_phase:
		1:
			select_attack_phase_1()
		# 2:
		# 	select_attack_phase_2()
		# 3:
		# 	select_attack_phase_3()
		_:
			push_error("Invalid phase %s" % current_phase)

func select_attack_phase_1() -> void:
	if force_shotgun_knockback:
		state_chart.send_event("start_shotgun_blast")
		force_shotgun_knockback = false
		previous_attack = "start_shotgun_blast"
		return

	var possible_attacks = [
		"start_throw_broken_bottle",
		"start_throw_concoction",
		"start_brew_drink",
		"start_shotgun_blast"
	]

	# Avoid use same attack twice in a row
	if previous_attack:
		possible_attacks.erase(previous_attack)
	
	var chosen_attack = possible_attacks.pick_random()
	previous_attack = chosen_attack
	state_chart.send_event(chosen_attack)


func _on_died() -> void:
	super()


### ATTACK PHASES --------------------------------

#### Any Phase

func _on_idle_state_entered() -> void:
	select_attack()

# Shotgun blast

func shotgun_blast():
	debug_state_label.text = "Shotgun blast"
	var proj_amount = 6
	var proj_damage = 2
	var proj_speed = 40
	var n_shot_repeat = 1
	var spread_angle = 4
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	for i in range(n_shot_repeat):
		for j in range(proj_amount):
			var aim_direction = proj_spawn_pos.direction_to(target.global_position)
			var spreaded_direction = GunUtils.get_spread_direction(aim_direction, spread_angle)
			var bullet_inst = shotgun_proj_prefab.instantiate()
			get_parent().add_child(bullet_inst)
			bullet_inst.init(proj_spawn_pos, spreaded_direction, proj_damage, proj_speed)
	state_chart.send_event("attack_end")
	state_chart.send_event("return_idle")

func _on_shotgun_blast_state_entered() -> void:
	shotgun_blast()

#### Phase 1

func _on_throw_broken_bottle_state_entered() -> void:
	debug_state_label.text = "Throw borken bottle"
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	
	# Do sth here
	await get_tree().create_timer(0.5).timeout
	state_chart.send_event("attack_end")
	state_chart.send_event("return_idle")


func _on_throw_concoction_state_entered() -> void:
	debug_state_label.text = "Throw concoction"
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")

	# Do sth here
	await get_tree().create_timer(0.5).timeout
	state_chart.send_event("attack_end")
	state_chart.send_event("return_idle")


func _on_brew_drink_state_entered() -> void:
	debug_state_label.text = "Brew drink"
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")

	# Do sth here
	await get_tree().create_timer(0.5).timeout
	state_chart.send_event("attack_end")
	state_chart.send_event("return_idle")


### Others

func _on_shotgun_trigger_area_body_entered(body:Node3D) -> void:
	if body is Player:
		force_shotgun_knockback = true


