extends BossCore

@export_category("Phases")
@export var phase_2_health_percentage_trigger: float = 0.66
@export var phase_3_health_percentage_trigger: float = 0.33

@export_category("Attacks")
@export var shotgun_proj_prefab: PackedScene
@export var empty_bottle_prefab: PackedScene
@export var molotov_prefab: PackedScene
@export var poison_bottle_prefab: PackedScene
@export var slow_bottle_prefab: PackedScene
@export var heal_bottle_prefab: PackedScene
@export var beer_barrel_prefab: PackedScene
@export var bottle_damage = 10
@export var barrel_damage = 45

@export_category("Drinks")
@export var defense_icon: Texture2D
@export var speed_icon: Texture2D
@export var strength_icon: Texture2D

## Received damage will multiply with this value
@export var defense_buff_resistance = 0.5
@export var speed_buff_modifier = 0.5

@export_category("Movement")
@export var base_movespeed = 10
@export var behind_bar_move_points: Array[Marker3D] = []

@onready var buff_expire_timer: Timer = $BuffExpireTimer
@onready var proj_spawn_marker = $ProjectileSpawnPos
@onready var status_icon: Sprite3D = $StatusIcon

var previous_attack: String
var player_is_near = false
var current_buff: String = ""
var current_speed_modifier = 1
var current_delay_modifier = 1
var has_strength_buff = false

const DIFFICULTY_LV = 1

func _ready() -> void:
	super()
	navigation_component.current_speed = base_movespeed * current_speed_modifier


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
	# If player is near, more likely to use shotgun blast
	if player_is_near:
		var roll = randi_range(0, 100)
		if roll <= 75:
			state_chart.send_event("start_shotgun_blast")
			previous_attack = "start_shotgun_blast"
			return

	var possible_attacks = [
		"start_throw_broken_bottle",
		"start_throw_concoction",
		"start_throw_concoction",
		"start_brew_drink",
		"start_shotgun_blast",
		"start_throw_heal_bottle"
	]

	# More likely to throw bottle / throw barrel when has str buff
	var throw_barrel_bonus_freq = 5
	if has_strength_buff:
		for i in range(throw_barrel_bonus_freq):
			possible_attacks.append("start_throw_broken_bottle")

	# Avoid use same attack twice in a row (except concoction)
	if previous_attack:
		possible_attacks.erase(previous_attack)
	
	var chosen_attack = possible_attacks.pick_random()
	previous_attack = chosen_attack

	var move_point = get_behind_bar_move_point()
	navigation_component.current_speed = base_movespeed * current_speed_modifier
	if move_point:
		navigation_component.target = move_point
		state_chart.send_event("start_moving")
		debug_state_label.text = "Walking"
		await navigation_component.nav_agent.navigation_finished
		state_chart.send_event("stop_moving")

	state_chart.send_event(chosen_attack)


func _on_died() -> void:
	super()


### ATTACK PHASES --------------------------------

#### Any Phase

# Shotgun blast

func shotgun_blast():
	debug_state_label.text = "Shotgun blast"
	var proj_amount = 8
	var proj_damage = 3
	var proj_speed = 40
	var n_shot_repeat = current_phase
	if player_is_near:
		n_shot_repeat += 1
	var spread_angle = 6
	var delay_between_burst = 0.5
	state_chart.send_event("attack_telegraph")
	# TODO: Change sprite "Ready gun"
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	for i in range(n_shot_repeat):
		for j in range(proj_amount):
			var aim_direction = proj_spawn_marker.global_position.direction_to(target.global_position)
			var spreaded_direction = GunUtils.get_spread_direction(aim_direction, spread_angle)
			var bullet_inst = shotgun_proj_prefab.instantiate()
			get_parent().add_child(bullet_inst)
			bullet_inst.init(proj_spawn_marker.global_position, spreaded_direction, proj_damage, proj_speed)
		if n_shot_repeat > 1 and i < n_shot_repeat - 1:
			await get_tree().create_timer(delay_between_burst).timeout
	state_chart.send_event("attack_end_now")
	state_chart.send_event("return_idle")

func _on_shotgun_blast_state_entered() -> void:
	shotgun_blast()

#### Phase 1

func _on_phase_1_idle_state_entered() -> void:
	debug_state_label.text = "Idle"
	await get_tree().create_timer(1).timeout
	select_attack()

func throw_bottle(prefab: PackedScene, n_bottle_repeat = 1, spread_angle = 0, proj_damage = 10):
	var throw_force = proj_spawn_marker.global_position.distance_to(target.global_position)
	# Magic number that make bartender throw better
	if throw_force >= 30:
		throw_force *= 0.8
	var aim_direction = proj_spawn_marker.global_position.direction_to(target.global_position)
	if has_strength_buff:
		throw_force *= 2
	else:
		aim_direction += Vector3(0, 0.2, 0) # Make it upward a bit
	aim_direction = aim_direction.normalized()
	var modified_spawn_pos = proj_spawn_marker.global_position + aim_direction # Avoid stuck inside boss body
	for i in range(n_bottle_repeat):
		var bottle_inst = prefab.instantiate()
		var spreaded_direction = GunUtils.get_spread_direction(aim_direction, spread_angle)
		get_parent().add_child(bottle_inst)
		bottle_inst.init(modified_spawn_pos, spreaded_direction, proj_damage, throw_force)

## Throw upward to heal
func throw_heal_bottle():
	var throw_force = 5
	var bottle_inst = heal_bottle_prefab.instantiate()
	var aim_direction = proj_spawn_marker.global_position.direction_to(target.global_position)
	aim_direction += Vector3(0, 5, 0) # Make it upward a lot
	aim_direction = aim_direction.normalized()
	var modified_spawn_pos = proj_spawn_marker.global_position + aim_direction
	get_parent().add_child(bottle_inst)
	bottle_inst.init(modified_spawn_pos, aim_direction, 0, throw_force)

## Choose a random bottle then throw
func throw_concoction_bottle():
	var possible_bottle_prefab = [
		molotov_prefab,
		poison_bottle_prefab,
		slow_bottle_prefab,
	]
	var chosen_prefab = possible_bottle_prefab.pick_random()
	var n_bottle = 1
	if current_phase > 1:
		n_bottle += 1
	if has_strength_buff:
		n_bottle += 1
	var spread_angle = (n_bottle - 1) * 20
	throw_bottle(chosen_prefab, n_bottle, spread_angle)

## Choose a random drink to brew and buff
func brew_drink():
	var possible_drink = [
		"defense",
		"speed",
		"strength",
	]
	var chosen_drink = possible_drink.pick_random()
	# I want boss to stack buffs, but due to time constraint (and possible bugs)
	# boss can only just have 1 buff ongoing for now
	reset_buff()
	current_buff = chosen_drink
	match chosen_drink:
		"defense":
			status_icon.texture = defense_icon
			health_component.modified_resistance = defense_buff_resistance
			buff_expire_timer.start()
		"speed":
			status_icon.texture = speed_icon
			current_speed_modifier = 1 + speed_buff_modifier
			current_delay_modifier = 1 - speed_buff_modifier
			navigation_component.current_speed = base_movespeed * current_speed_modifier
			buff_expire_timer.start()
		"strength":
			has_strength_buff = true
			status_icon.texture = strength_icon
			buff_expire_timer.start()

## If has str buff, throw barrel instead
func _on_throw_broken_bottle_state_entered() -> void:
	debug_state_label.text = "Throw broken bottle"
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	# TODO: Change sprite "Throw"
	if has_strength_buff:
		throw_bottle(beer_barrel_prefab, 1, 1, barrel_damage)
	else:
		var n_bottle = randi_range(2, 4)
		var spread = randf_range(5, 10)
		throw_bottle(empty_bottle_prefab, n_bottle, spread, bottle_damage)
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	state_chart.send_event("return_idle")


func _on_throw_concoction_state_entered() -> void:
	debug_state_label.text = "Throw concoction"
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	# TODO: Change sprite "Throw"
	throw_concoction_bottle()
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	state_chart.send_event("return_idle")


func _on_brew_drink_state_entered() -> void:
	debug_state_label.text = "Brew drink"
	await get_tree().create_timer(1 * current_delay_modifier).timeout
	# TODO: Change sprite "Brew"
	brew_drink()
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	state_chart.send_event("return_idle")


func _on_throw_heal_bottle_state_entered() -> void:
	debug_state_label.text = "Throw heal bottle"
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	throw_heal_bottle()
	await get_tree().create_timer(1.5).timeout
	state_chart.send_event("return_idle")

### Others

func _on_shotgun_trigger_area_body_entered(body: Node3D) -> void:
	if body is Player:
		state_chart.send_event("stop_moving")
		state_chart.send_event("start_shotgun_blast")
		player_is_near = true

func _on_shotgun_trigger_area_body_exited(body: Node3D) -> void:
	if body is Player:
		player_is_near = false

func reset_buff():
	current_buff = ""
	status_icon.texture = null
	health_component.modified_resistance = 1
	current_speed_modifier = 1
	current_delay_modifier = 1
	has_strength_buff = false


func _on_buff_expire_timer_timeout() -> void:
	reset_buff()

## Get a random point (exclude the closest point)
func get_behind_bar_move_point():
	var valid_move_points = behind_bar_move_points.duplicate()
	valid_move_points.sort_custom(
		func(a, b):
			var a_dist: float = self.global_position.distance_to(a.global_position)
			var b_dist: float = self.global_position.distance_to(b.global_position)
			if a_dist < b_dist:
				return true
			return false
	)
	valid_move_points.pop_front()
	return valid_move_points.pick_random()
