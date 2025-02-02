extends BossCore

@export_category("Phases")
@export var phase_2_health_percentage_trigger: float = 0.66
@export var phase_3_health_percentage_trigger: float = 0.33

@export_group("Display")
@export var base_sprite: CompressedTexture2D
@export var shotgun_sprite: CompressedTexture2D
@export var throw_sprite: CompressedTexture2D
@export var brew_sprite: CompressedTexture2D

@export_group("Attacks")
@export_subgroup("Shotgun")
@export var shotgun_proj_prefab: PackedScene
@export var sfx_shotgun: Array[AudioStream]
@export_subgroup("Bottles")
@export var bottle_damage = 10
@export var empty_bottle_prefab: PackedScene
@export var molotov_prefab: PackedScene
@export var poison_bottle_prefab: PackedScene
@export var slow_bottle_prefab: PackedScene
@export var heal_bottle_prefab: PackedScene
@export var sfx_bottle_throw: Array[AudioStream]
@export_subgroup("Barrel")
@export var beer_barrel_prefab: PackedScene
@export var barrel_damage = 45
@export var sfx_barrel_throw: Array[AudioStream]

@export_subgroup("Floor Fire")
@export var floor_fize_hazard_marker: Marker3D
@export var floor_fire_hazard_prefab: PackedScene
@export var sfx_start_fire: AudioStream
@export var sfx_fire_loop: AudioStream

@export_group("Drinks")
@export var defense_icon: Texture2D
@export var speed_icon: Texture2D
@export var strength_icon: Texture2D
## Received damage will multiply with this value
@export var defense_buff_resistance = 0.5
@export var speed_buff_modifier = 0.5

@export_group("Movement")
@export var base_movespeed = 10
@export var behind_bar_move_points: Array[Marker3D] = []
@export var boss_jump_phase2_marker: Marker3D
@export var boss_jump_phase3_marker: Marker3D
@export_subgroup("SFX")
@export var sfx_jump: Array[AudioStream]

@onready var buff_expire_timer: Timer = $BuffExpireTimer
@onready var proj_spawn_marker = $ProjectileSpawnPos
@onready var status_icon: Sprite3D = $StatusIcon
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer

var previous_attack: String
var player_is_near = false
var current_buff: String = ""
var current_speed_modifier = 1
var current_delay_modifier = 1
var has_strength_buff = false
var floor_fire_hazard: HazardArea = null
var action_used_before_heal = 0
var fire_sfx: AudioStreamPlayer = null

const DIFFICULTY_LV = 1
const MIN_ACTION_BEFORE_HEAL = 8

func _ready() -> void:
	super()
	navigation_component.current_speed = base_movespeed * current_speed_modifier

func _process(delta: float) -> void:
	if target:
		_turn_towards_target(TURN_SPEED_SLOW, delta)

func activate() -> void:
	super()
	change_phase(1)

func change_phase(new_phase: int) -> void:
	# Check if an attack is in progress
	if not $StateChart/Root/Attacking/Idle.active:
		await $StateChart/Root/Attacking/Idle.state_entered

	state_chart.send_event("stop_moving")

	current_phase = new_phase

	if current_phase == 1:
		state_chart.send_event("start_phase_1")
	elif current_phase == 2:
		state_chart.send_event("start_phase_2")
	elif current_phase == 3:
		state_chart.send_event("start_phase_3")


func select_attack() -> void:
	action_used_before_heal += 1
	match current_phase:
		1:
			select_attack_phase_1()
		2:
			select_attack_phase_2()
		3:
			select_attack_phase_1() # Phase 3 is same as phase 1
		_:
			push_error("Invalid phase %s" % current_phase)

func select_attack_phase_1() -> void:
	var possible_attacks = [
		"start_throw_broken_bottle",
		"start_throw_broken_bottle",
		"start_throw_concoction",
		"start_throw_concoction",
		"start_throw_concoction",
	]

	if action_used_before_heal >= MIN_ACTION_BEFORE_HEAL:
		possible_attacks.append("start_throw_heal_bottle")

	# If player is near, more likely to use shotgun blast
	if player_is_near:
		var shotgun_bonus_freq = 4
		for i in range(shotgun_bonus_freq):
			possible_attacks.append("start_shotgun_blast")

	# If dont have buff, more likely to use buff	
	if current_buff == "":
		var brew_drink_bonus_freq = 2
		for i in range(brew_drink_bonus_freq):
			possible_attacks.append("start_brew_drink")

	# More likely to throw bottle / throw barrel when has str buff
	var throw_barrel_bonus_freq = 3
	if has_strength_buff:
		for i in range(throw_barrel_bonus_freq):
			possible_attacks.append("start_throw_broken_bottle")

	# Avoid use same attack twice in a row (except concoction)
	if previous_attack:
		possible_attacks.erase(previous_attack)
	
	var chosen_attack = possible_attacks.pick_random()
	previous_attack = chosen_attack

	state_chart.send_event(chosen_attack)


func select_attack_phase_2() -> void:
	# If dont have buff, ALWAYS use buff	
	if current_buff == "":
		previous_attack = "start_brew_drink"
		state_chart.send_event("start_brew_drink")
		return

	var possible_attacks = [
		"start_throw_broken_bottle",
		"start_shotgun_blast",
		"start_shotgun_blast",
		"start_throw_concoction",
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

	state_chart.send_event(chosen_attack)

func _on_health_changed(new_health: float, prev_health: float) -> void:
	super(new_health, prev_health)
	if new_health < health_component.max_health * phase_3_health_percentage_trigger and current_phase == 2:
		change_phase(3)
	elif new_health < health_component.max_health * phase_2_health_percentage_trigger and current_phase == 1:
		change_phase(2)


func _on_died() -> void:
	super()
	if fire_sfx:
		fire_sfx.stop()
	if floor_fire_hazard:
		floor_fire_hazard.clear_hazard()


### ATTACK PHASES --------------------------------

#### Any Phase

# Shotgun blastaa

func shotgun_blast():
	debug_state_label.text = "Shotgun blast"
	var proj_amount = 8
	var proj_damage = 3
	var proj_speed = 40
	var n_shot_repeat = current_phase
	var spread_angle = 6
	var delay_between_burst = 0.5
	for i in range(n_shot_repeat):
		sfx_player.stream = sfx_shotgun.pick_random()
		sfx_player.play()
		for j in range(proj_amount):
			var aim_direction = proj_spawn_marker.global_position.direction_to(target.global_position)
			var spreaded_direction = GunUtils.get_spread_direction(aim_direction, spread_angle)
			var bullet_inst = shotgun_proj_prefab.instantiate()
			get_parent().add_child(bullet_inst)
			bullet_inst.init(proj_spawn_marker.global_position, spreaded_direction, proj_damage, proj_speed)
		if n_shot_repeat > 1 and i < n_shot_repeat - 1:
			await get_tree().create_timer(delay_between_burst).timeout

func _on_shotgun_blast_state_entered() -> void:
	sprite.texture = shotgun_sprite
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	shotgun_blast()
	state_chart.send_event("attack_end_now")
	state_chart.send_event("return_idle")
	sprite.texture = base_sprite

#### Phase 1

func _on_phase_1_state_entered() -> void:
	GameManager.show_boss_special_dialog("Welcome to MY Bar!", 1.5)

func _on_phase_1_idle_state_entered() -> void:
	debug_state_label.text = "Idle"
	await get_tree().create_timer(0.5).timeout

	var move_point = get_behind_bar_move_point()
	navigation_component.current_speed = base_movespeed * current_speed_modifier
	if move_point:
		navigation_component.target = move_point
		state_chart.send_event("start_moving")
		debug_state_label.text = "Walking"
		await get_tree().create_timer(1).timeout
		state_chart.send_event("stop_moving")

	select_attack()

#### Phase 2

func _on_phase_2_state_entered() -> void:
	await get_tree().create_timer(1.0).timeout
	GameManager.show_boss_special_dialog("PLAYTIME IS OVER!", 1)
	jump_to(boss_jump_phase2_marker.global_position)


func _on_phase_2_idle_state_entered() -> void:
	debug_state_label.text = "Idle"
	await get_tree().create_timer(0.5).timeout

	navigation_component.current_speed = base_movespeed * current_speed_modifier
	navigation_component.target = target
	state_chart.send_event("start_moving")
	debug_state_label.text = "Walking"
	await get_tree().create_timer(2).timeout
	state_chart.send_event("stop_moving")
	
	select_attack()

#### Phase 3
func _on_phase_3_state_entered() -> void:
	await get_tree().create_timer(1.0).timeout
	GameManager.show_boss_special_dialog("DARN IT! \nI WILL JUST LIT THE WHOLE FLOOR ON FIRE THEN!", 2)
	jump_to(boss_jump_phase3_marker.global_position)
	await get_tree().create_timer(6.0).timeout
	fire_sfx = SoundManager.play_ambient_sound(sfx_start_fire, 0.2, "SFX")
	fire_sfx.finished.connect(func():
		SoundManager.play_ambient_sound(sfx_fire_loop, 0.1, "SFX")
	)
	floor_fire_hazard = floor_fire_hazard_prefab.instantiate()
	floor_fize_hazard_marker.add_child(floor_fire_hazard)
	floor_fire_hazard.position = Vector3.ZERO


### Common

## If has str buff, throw barrel instead
func _on_throw_broken_bottle_state_entered() -> void:
	sprite.texture = throw_sprite
	debug_state_label.text = "Throw broken bottle"
	state_chart.send_event("attack_start")
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	if has_strength_buff:
		throw_bottle(beer_barrel_prefab, 1, 1, barrel_damage)
	else:
		var n_bottle = randi_range(2, 4)
		var spread = randf_range(5, 10)
		throw_bottle(empty_bottle_prefab, n_bottle, spread, bottle_damage)
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	state_chart.send_event("attack_end_now")
	state_chart.send_event("return_idle")
	sprite.texture = base_sprite


func _on_throw_concoction_state_entered() -> void:
	sprite.texture = throw_sprite
	debug_state_label.text = "Throw concoction"
	state_chart.send_event("attack_start")
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	# TODO: Change sprite "Throw"
	throw_concoction_bottle()
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	state_chart.send_event("attack_end_now")
	state_chart.send_event("return_idle")
	sprite.texture = base_sprite


func _on_brew_drink_state_entered() -> void:
	sprite.texture = brew_sprite
	debug_state_label.text = "Brew drink"
	state_chart.send_event("attack_start")
	await get_tree().create_timer(2 * current_delay_modifier).timeout
	# TODO: Change sprite "Brew"
	brew_drink()
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	state_chart.send_event("attack_end_now")
	state_chart.send_event("return_idle")
	sprite.texture = base_sprite


func _on_throw_heal_bottle_state_entered() -> void:
	sprite.texture = throw_sprite
	debug_state_label.text = "Throw heal bottle"
	state_chart.send_event("attack_start")
	await get_tree().create_timer(0.25 * current_delay_modifier).timeout
	throw_heal_bottle()
	await get_tree().create_timer(2).timeout
	state_chart.send_event("attack_end_now")
	state_chart.send_event("return_idle")
	sprite.texture = base_sprite


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
		bottle_inst.bartender_owner = self
		var spreaded_direction = GunUtils.get_spread_direction(aim_direction, spread_angle)
		get_parent().add_child(bottle_inst)
		bottle_inst.init(modified_spawn_pos, spreaded_direction, proj_damage, throw_force)
		if bottle_inst is BartenderBarrel:
			sfx_player.stream = sfx_barrel_throw.pick_random()
		else:
			sfx_player.stream = sfx_bottle_throw.pick_random()
		sfx_player.play()

## Throw upward to heal
func throw_heal_bottle():
	action_used_before_heal = 0
	var throw_force = 5
	var bottle_inst = heal_bottle_prefab.instantiate()
	var aim_direction = proj_spawn_marker.global_position.direction_to(target.global_position)
	aim_direction += Vector3(0, 5, 0) # Make it upward a lot
	aim_direction = aim_direction.normalized()
	var modified_spawn_pos = proj_spawn_marker.global_position + aim_direction
	get_parent().add_child(bottle_inst)
	bottle_inst.init(modified_spawn_pos, aim_direction, 0, throw_force)
	bottle_inst.bartender_owner = self


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
			# current_delay_modifier = 1 - speed_buff_modifier
			navigation_component.current_speed = base_movespeed * current_speed_modifier
			buff_expire_timer.start()
		"strength":
			has_strength_buff = true
			status_icon.texture = strength_icon
			buff_expire_timer.start()

### Others

func _on_shotgun_trigger_area_body_entered(body: Node3D) -> void:
	if body is Player:
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

func jump_to(target_position: Vector3, jump_height: float = 5, jump_time: float = 1):
	var tween = get_tree().create_tween()
	var tween2 = get_tree().create_tween()

	# Step 1: Tween XZ movement (horizontal movement)
	var start_position = global_position
	var end_position = target_position
	start_position.y = 0
	end_position.y = 0
	sfx_player.stream = sfx_jump.pick_random()
	sfx_player.play()
	tween.tween_property(self, "global_position", end_position, jump_time).set_trans(Tween.TRANS_LINEAR)

	# Step 2: Animate Y movement with a parabola
	var mid_time = jump_time / 2 # Midpoint of the jump
	var peak_height = global_position.y + jump_height # Peak height

	tween2.tween_property(self, "position:y", peak_height, mid_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween2.tween_property(self, "position:y", target_position.y, mid_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished
