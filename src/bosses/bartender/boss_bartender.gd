extends BossCore

# Antes note:
# Ante 1: (new) Shotgun Volley: Prepare shells and shotgun in 2 to 4 bursts in quick succession, two shot each burst
# Ante 2: (upgrade) Painkilling Alcohol: Drinking will grant DMG reduction.
# Ante 3: (upgrade)
# Ante 4: (upgrade) Premium Bullets: Shotgun projectile bigger, faster and can ricochet
# Ante 5: (new) Sleight of Hand - Can throw cocktails in interval without taking an action/attack

# Upgrade TODO:
# Fire Ring: A fire hazard that slowly expand out ring-shaped (so the inside is empty and player can jump into to stay safe)
# Tar bottle can be ignited into Fire Ring.
#
# New move: Bartender throw out several tar puddle onto the floor, then flick some matchsticks and ignite them. (player also can ignite them first).
#           In phase 3, tar puddle auto ignited due to Floor Fire.
# New move: Slug Shell: Bartender reload a blue shell and take aim, then shoot a hitscan attack.
#
# New move: Dragon Breath Shell: Load an orange Dragon breath shell that has high projectile count and spread.
#
# New move: Duck: Bartender duck behind a cover between attacks, or after take a certain amount of damage.
#
# New move: Dodge: Give bartender a small chance to dodge attack by quickly move sideway. Programming-wise, he can dodge attack
# by reading player input (player press shoot when aim ray intersect with his hitbox).
#
# New move (DONE): Flaming wall: Use several molotovs to create a flaming wall that block LoS (but he can shoot since he an AI and dont have
# such weakness) and prevent movement.
#
# New move: (DONE) Infernal Countertop: Lit the whole counter top on fire, block vision.
#
# New move: Drunken Bullet Dance: Jump to the center and shoot randomly in 360 degree (like Katarina Ultimate)
#
# Modify move: Barrel (which only used in Str buff) should be explosive by default.
#
# Modify move (DONE): Thrown bottle should create small clouds that spread outward, make it bullet hell-ish
#
# Map edit (DONE): Clear out some table in the map, and raise the ceiling. Maybe add 2nd floor balconny for improved phase 3.
#
# Map edit (DONE): Table should be its own scene, not stucked to map. And can be kicked (by pressing Interact probably) to work as cover.
# It will fall back after some time. Use this to counter Shotgun Volley.
#
# New phase: Drinking buff should be its own phase so it can have more different attacks. Jekyll/Hyde style.
#
# Improved phase 3: Bartender moved to second floor balcony and vertical play / shoot from above the player.

# Thoughts:
# Maybe Ante powerup should be mostly enhance skills instead of new skills.
# Some moves should be designed with a counterattack way / knowledge check

# Status:
# Weak to Burning (he's serving alcolhol most of the time), resist to Poisoned (same reason)

signal fire_started

@export_category("Phases")
@export var phase_2_health_percentage_trigger: float = 0.66
@export var phase_3_health_percentage_trigger: float = 0.33

@export_group("Display")
@export var shotgun_sprite: CompressedTexture2D
@export var reload_sprite: CompressedTexture2D
@export var throw_sprite: CompressedTexture2D
@export var brew_sprite: CompressedTexture2D
@export var drink_sprite: CompressedTexture2D

@export var sfx_tape: AudioStream

@export_group("Attacks")
var prev_attack
const BASE_DAMAGE_MODIFIER: float = 1.0
const BASE_RESISTANCE_MODIFIER: float = 1.0
const BASE_SPEED_MODIFIER: float = 1.0
const BASE_DELAY_MODIFIER: float = 1.0
var damage_modifier: float = BASE_DAMAGE_MODIFIER * GameManager.get_risk_dmg_mult()
var speed_modifier: float = BASE_SPEED_MODIFIER
var delay_modifier: float = BASE_DELAY_MODIFIER:
	set(value):
		delay_modifier = value
		# Don't change the speed of the drinking animation
		if anim_player.is_playing():
			await anim_player.animation_finished
		anim_player.speed_scale = 1.0 / (delay_modifier * 1.5)

@export_subgroup("Shotgun")
@export var shotgun_proj_amount: int = 8
@export var shotgun_proj_damage: int = 4
@export var shotgun_proj_speed: float = 40 # Based on ante 4
@export var shotgun_spread_angle: float = 6
var shotgun_ricochet_count = 0 # Based on ante 4
@export var shotgun_proj_prefab: PackedScene
@export var enhanced_shotgun_proj_prefab: PackedScene # Based on ante 4
var chosen_shotgun_proj_prefab: PackedScene
@export var sfx_shotgun: Array[AudioStream]
@onready var shotgun_timer: Timer = $ShotgunTimer
@onready var shotgun_spawn_pos: Marker3D = $Sprite3D/ShotgunSpawnPos
var shots_to_fire: int = 1
var shots_fired: int = 0
const SHOTGUN_SHOTS_TO_FIRE_PHASE_2 = 2
const SHOTGUN_SHOTS_TO_FIRE_PHASE_3 = 2

@export_subgroup("Shotgun Volley")
@export var min_shotgun_volley_burst: int = 2
@export var max_shotgun_volley_burst: int = 4
@export var time_between_shotgun_burst: float = 0.1
@onready var shotgun_volley_timer: Timer = $ShotgunVolleyTimer
const SHOT_PER_BURST = 2
var shotgun_volley_enabled = false
var burst_to_fire = 0
var burst_fired = 0

@export_subgroup("Shotgun Hitscan")
@export var shotgun_hitscan_damage: int = 25
@export var shotgun_hitscan_prefab: PackedScene
const HITSCAN_MAX_RANGE = 500

@export_subgroup("Countertop Flame")
@export var countertop_flame_duration = 10
@export var countertop_flame_cd = 30
@onready var countertop_flame_cd_timer: Timer = $CountertopFlameTimer
@export_subgroup("Throw Drink")
@export var bottle_damage = 10
enum BottleAttack {
	EMPTY,
	FIRE,
	POISON,
	SLOW,
	# HEAL,
	BARREL
}
var current_bottle_type: BottleAttack
var last_bottle_attack: BottleAttack
var special_bottle_enabled = true
@export var min_n_bottle_per_attack: int = 1
@export var max_n_bottle_per_attack: int = 2
@export var min_bottles_spread: float = 30
@export var max_bottles_spread: float = 60
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
@export_subgroup("Brewing")
enum BrewType {
	# DEFENSE,
	SPEED,
	STRENGTH
}
var current_brew_type: BrewType
var last_brew_type: BrewType
@onready var buff_expire_timer: Timer = $BuffExpireTimer
@onready var brew_cooldown_timer: Timer = $BrewCooldownTimer
@export var buff_duration: float = 10.0
@export var buff_cooldown: float = 21.0
@export var defense_icon: Texture2D
@export var speed_icon: Texture2D
@export var strength_icon: Texture2D
@export var defense_buff_modifier = 0.5
@export var speed_buff_modifier = 0.5
@export var strength_buff_modifier = 1.5
@export var sfx_brew: Array[AudioStream]
@export var sfx_strength: AudioStream
@export var sfx_speed: AudioStream
@export var sfx_defense: AudioStream

@export_subgroup("Floor Fire")
@export var floor_fize_hazard_marker: Marker3D
@export var floor_fire_hazard_prefab: PackedScene
@export var sfx_fire_started: AudioStream
@export var sfx_fire_loop: AudioStream
var floor_fire_enabled = true

@export_group("Movement")
@export var base_movespeed = 10
@export var behind_bar_move_points: Array[Marker3D] = []
@export var boss_jump_phase2_marker: Marker3D
@export var boss_jump_phase3_marker: Marker3D
@export_subgroup("SFX")
@export var sfx_jump: Array[AudioStream]

@export_group("Passive")
@export_subgroup("Sleight of Hand")
var sleight_of_hand_enabled = false
@export var sleight_of_hand_interval: float = 5
@onready var sleight_of_hand_timer: Timer = $SleightOfHandTimer

# Other stuff
@onready var proj_spawn_marker = $Sprite3D/ThrowableSprite/ProjectileSpawnPos
@onready var status_icon: Sprite3D = $StatusIcon
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer

var previous_attack: String
var player_is_near = false
var current_buff: String = ""
var has_strength_buff = false
var floor_fire_hazard: HazardArea = null
var action_used_before_heal = 0
var fire_sfx: AudioStreamPlayer = null

const MIN_ACTION_BEFORE_HEAL = 8

var boss_map_bartender: BossMapBartender


func _ready() -> void:
	super ()
	chosen_shotgun_proj_prefab = shotgun_proj_prefab
	navigation_component.current_speed = base_movespeed * speed_modifier
	brew_cooldown_timer.stop()
	if GameManager.boss_ante >= 1:
		pass
	if GameManager.boss_ante >= 2:
		pass
	if GameManager.boss_ante >= 3:
		pass
	if GameManager.boss_ante >= 4:
		shotgun_ricochet_count = 3
		shotgun_proj_speed = 60
		chosen_shotgun_proj_prefab = enhanced_shotgun_proj_prefab
	if GameManager.boss_ante >= 5:
		sleight_of_hand_enabled = true
		sleight_of_hand_timer.start(sleight_of_hand_interval)


func _process(delta: float) -> void:
	if target:
		_turn_towards_target(TURN_SPEED_SLOW, delta)

func activate() -> void:
	super ()
	boss_map_bartender = boss_map as BossMapBartender
	boss_map_bartender.toggle_spotlight(true)
	await get_tree().create_timer(0.5).timeout
	GameManager.show_boss_special_dialog("Welcome to MY Bar!", 1.5)
	boss_map_bartender.toggle_light(true)
	boss_map_bartender.toggle_spotlight(false)
	sprite.shaded = false
	change_phase(1)


func change_phase(new_phase: int) -> void:
	# Check if an attack is in progress
	#if not $StateChart/Root/Attacking/Idle.active:
		#await $StateChart/Root/Attacking/Idle.state_entered
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
			select_attack_phase_3()
		_:
			push_error("Invalid phase %s" % current_phase)

#region SELECT ATTACK
func select_attack_phase_1() -> void:
	# Weighted random chance attacks
	#
	var attack_str: String = ""
	var attack_roll: int = randi_range(0, 99)

	if player_is_near:
		# Close range:
		if attack_roll < 25:
			attack_str = "start_throw_broken_bottle"
		elif attack_roll < 50:
			attack_str = "start_shotgun_volley"
		elif attack_roll < 75:
			if countertop_flame_cd_timer.is_stopped():
				attack_str = "start_countertop_flame"
			else:
				attack_str = "start_shotgun_blast"
		else:
			attack_str = "start_shotgun_blast"
	else:
		# Mid/Far range:
		if attack_roll < 15:
			attack_str = "start_throw_broken_bottle"
		elif attack_roll < 45:
			attack_str = "start_throw_drink"
		elif attack_roll < 60:
			if countertop_flame_cd_timer.is_stopped():
				attack_str = "start_countertop_flame"
			else:
				attack_str = "start_shotgun_blast"
		elif attack_roll < 75:
			attack_str = "start_shotgun_volley"
		else:
			attack_str = "start_shotgun_hitscan"

	state_chart.send_event(attack_str)


func select_attack_phase_2() -> void:
	# Weighted random chance attacks
	#
	var attack_str: String = ""
	var attack_roll: int = randi_range(0, 99)

	if attack_roll < 20:
		attack_str = "start_shotgun_blast"
	if attack_roll < 30:
		attack_str = "start_shotgun_volley"
	elif attack_roll < 40:
		attack_str = "start_throw_broken_bottle"
	else:
		attack_str = "start_throw_drink"

	state_chart.send_event(attack_str)


func select_attack_phase_3() -> void:
	# Weighted random chance attacks
	#
	var attack_str: String = ""
	var attack_roll: int = randi_range(0, 99)

	if attack_roll < 25:
		attack_str = "start_shotgun_volley"
	elif attack_roll < 40 and countertop_flame_cd_timer.is_stopped():
		attack_str = "start_countertop_flame"
	else:
		attack_str = "start_throw_drink"

	state_chart.send_event(attack_str)

#endregion


func _on_health_changed(new_health: float, prev_health: float) -> void:
	super (new_health, prev_health)

	if new_health < health_component.max_health * phase_3_health_percentage_trigger and current_phase == 2:
		change_phase(3)
	elif new_health < health_component.max_health * phase_2_health_percentage_trigger and current_phase == 1:
		change_phase(2)


func _on_died() -> void:
	super ()
	if fire_sfx:
		fire_sfx.stop()
	if floor_fire_hazard:
		floor_fire_hazard.clear_hazard()


### ATTACK PHASES --------------------------------

func _on_attack_telegraph_state_entered() -> void:
	pass


#### Phase 1

func _on_phase_1_state_entered() -> void:
	anim_player.play("RESET")
	#SoundManager.play_sound(sfx_tape, "SFX")
	shots_to_fire = 1
	#SoundManager.stop_sound(sfx_tape)


func _on_phase_1_idle_state_entered() -> void:
	debug_state_label.text = "Idle | "
	await get_tree().create_timer(0.1 * delay_modifier, false).timeout

	# FIXME - re-implement the movement after each attack into part of the select attack
	var move_point = get_behind_bar_move_point()
	navigation_component.current_speed = base_movespeed * speed_modifier
	if move_point:
		print("New nav target: %s" % navigation_component.target.name)
		state_chart.send_event("start_moving")
		navigation_component.target = move_point
		await get_tree().create_timer(0.4 * delay_modifier, false).timeout
		state_chart.send_event("stop_moving")
		select_attack()

#### Phase 2

func _on_phase_2_state_entered() -> void:
	anim_player.play("RESET")
	#SoundManager.play_sound(sfx_tape, "SFX")
	shots_to_fire = SHOTGUN_SHOTS_TO_FIRE_PHASE_2
	#GameManager.show_boss_special_dialog("Playtime is OVER!", 1)
	#await get_tree().create_timer(1, false).timeout
	#SoundManager.stop_sound(sfx_tape)
	jump_to(boss_jump_phase2_marker.global_position)
	state_chart.send_event("start_bullet_dance")


func _on_phase_2_idle_state_entered() -> void:
	debug_state_label.text = "Idle | "
	#await get_tree().create_timer(0.5, false).timeout

	navigation_component.current_speed = base_movespeed * speed_modifier
	navigation_component.target = target
	state_chart.send_event("start_moving")
	debug_state_label.text = "Idle | Walking"
	await get_tree().create_timer(0.8, false).timeout
	state_chart.send_event("stop_moving")
	select_attack()

#### Phase 3
func _on_phase_3_state_entered() -> void:
	anim_player.play("RESET")
	#SoundManager.play_sound(sfx_tape, "SFX")
	shots_to_fire = SHOTGUN_SHOTS_TO_FIRE_PHASE_3
	buff_duration *= 1.5
	buff_cooldown /= 2
	#GameManager.show_boss_special_dialog("You better hot foot it out of here while you still can!", 1.5)
	#await get_tree().create_timer(1.5, false).timeout
	#SoundManager.stop_sound(sfx_tape)

	jump_to(boss_jump_phase3_marker.global_position)

	await get_tree().create_timer(2.0, false).timeout

	if floor_fire_enabled:
		fire_started.emit()
		# TODO - move this to the map script
		floor_fire_hazard = floor_fire_hazard_prefab.instantiate()
		floor_fize_hazard_marker.add_child(floor_fire_hazard)
		floor_fire_hazard.position = Vector3.ZERO


## Choose a random drink to brew and buff.
## Used in animation event.
func brew_drink():
	var buff_event_str: String = BrewType.keys()[current_brew_type].to_lower()
	state_chart.send_event("apply_%s_buff" % buff_event_str)

	buff_expire_timer.start(buff_duration)
	brew_cooldown_timer.start(buff_cooldown)

### Others

func _on_shotgun_trigger_area_body_entered(body: Node3D) -> void:
	if body is Player:
		player_is_near = true

func _on_shotgun_trigger_area_body_exited(body: Node3D) -> void:
	if body is Player:
		player_is_near = false


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
	tween.tween_property(self , "global_position", end_position, jump_time).set_trans(Tween.TRANS_LINEAR)

	# Step 2: Animate Y movement with a parabola
	var mid_time = jump_time / 2 # Midpoint of the jump
	var peak_height = global_position.y + jump_height # Peak height

	tween2.tween_property(self , "position:y", peak_height, mid_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween2.tween_property(self , "position:y", target_position.y, mid_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished

#region Shotgun blast
func _on_shotgun_targeting_state_entered() -> void:
	debug_state_label.text = "Shotgun Blast | Targeting"
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_telegraph")
	anim_player.play("shotgun_telegraph")
	await anim_player.animation_finished
	shotgun_timer.start(telegraph_time)


func _on_shotgun_shooting_state_entered() -> void:
	debug_state_label.text = "Shotgun Blast | Shooting"
	state_chart.send_event("attack_start")
	anim_player.play("shotgun_fire")
	await anim_player.animation_finished
	if shots_to_fire > 1:
		if shots_fired < shots_to_fire - 1:
			shots_fired += 1
			state_chart.send_event("next_shot")
			return
	state_chart.send_event("end_shooting")


func _on_shotgun_recover_state_entered() -> void:
	debug_state_label.text = "Shotgun Blast | Recovering"
	shots_fired = 0
	anim_player.play("RESET")
	await get_tree().create_timer(attack_recovery_time, false).timeout
	state_chart.send_event("reposition")


func _on_shotgun_blast_state_exited() -> void:
	shotgun_timer.stop()


func _on_shotgun_timer_timeout() -> void:
	state_chart.send_event("start_shooting")

func fire_shotgun():
	var proj_damage = shotgun_proj_damage * damage_modifier
	# var delay_between_burst = 0.5 * delay_modifier
	# TODO - this needs to be cancellable for when the boss dies mid attack
	# Make this function shoot once and then we can call it 3 times and allow
	# an interrupt for death after each shot.
	sfx_player.stream = sfx_shotgun.pick_random()
	sfx_player.play()
	var aim_direction = shotgun_spawn_pos.global_position.direction_to(target.global_position)
	for j in range(shotgun_proj_amount):
		var spreaded_direction = GunUtils.get_spread_direction(aim_direction, shotgun_spread_angle)
		var bullet_inst: BartenderShotgunProjectile = chosen_shotgun_proj_prefab.instantiate()
		get_parent().add_child(bullet_inst)
		bullet_inst.init(shotgun_spawn_pos.global_position, spreaded_direction, proj_damage, shotgun_ricochet_count, shotgun_proj_speed)

#endregion

#region Shotgun hitscan
func fire_shotgun_hitscan():
	var hitscan_damage = shotgun_hitscan_damage * damage_modifier
	sfx_player.stream = sfx_shotgun.pick_random()
	sfx_player.play()
	var aim_direction = shotgun_spawn_pos.global_position.direction_to(target.global_position)
	var hitscan_inst: BartenderShotgunHitscan = shotgun_hitscan_prefab.instantiate()
	get_parent().add_child(hitscan_inst)
	hitscan_inst.init(shotgun_spawn_pos.global_position, aim_direction, hitscan_damage, shotgun_ricochet_count, shotgun_proj_speed, HITSCAN_MAX_RANGE)


func _on_shotgun_hitscan_targeting_state_entered() -> void:
	debug_state_label.text = "Shotgun Hitscan | Targeting"
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_telegraph")
	anim_player.play("shotgun_telegraph")
	await anim_player.animation_finished
	shotgun_timer.start(telegraph_time)


func _on_shotgun_hitscan_shooting_state_entered() -> void:
	debug_state_label.text = "Shotgun Hitscan | Shooting"
	state_chart.send_event("attack_start")
	anim_player.play("shotgun_fire_hitscan")
	await anim_player.animation_finished
	state_chart.send_event("end_shooting")


func _on_shotgun_hitscan_recover_state_entered() -> void:
	debug_state_label.text = "Shotgun Hitscan | Recovering"
	anim_player.play("RESET")
	await get_tree().create_timer(attack_recovery_time, false).timeout
	state_chart.send_event("reposition")


func _on_shotgun_hitscan_state_exited() -> void:
	shotgun_timer.stop()

#endregion


#region Shotgun volley
func _on_shotgun_volley_targeting_state_entered() -> void:
	debug_state_label.text = "Shotgun Volley | Targeting"
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_telegraph")
	anim_player.play("shotgun_telegraph") # Also delay between burst
	await anim_player.animation_finished
	shotgun_volley_timer.start(time_between_shotgun_burst)
	burst_to_fire = randi_range(2, 4)

func _on_shotgun_volley_bursting_state_entered() -> void:
	state_chart.send_event("attack_start")
	anim_player.play("shotgun_burst")
	await anim_player.animation_finished
	if burst_fired < burst_to_fire - 1:
		burst_fired += 1
		state_chart.send_event("next_burst")
		return
	state_chart.send_event("end_bursting")


func _on_shotgun_volley_recover_state_entered() -> void:
	burst_fired = 0
	anim_player.play("RESET")
	await get_tree().create_timer(attack_recovery_time, false).timeout
	state_chart.send_event("reposition")

func _on_shotgun_volley_state_exited() -> void:
	shotgun_volley_timer.stop()

func _on_shotgun_volley_timer_timeout() -> void:
	state_chart.send_event("start_bursting")

#endregion

#region Bullet dance

func _on_bullet_dance_targeting_state_entered() -> void:
	debug_state_label.text = "Bullet Dancing | Targeting"
	boss_map_bartender.toggle_light(false)
	boss_map_bartender.toggle_spotlight(true)
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_telegraph")
	anim_player.play("shotgun_telegraph")
	await anim_player.animation_finished
	state_chart.send_event("start_dancing")

func _on_bullet_dance_dancing_state_entered() -> void:
	debug_state_label.text = "Bullet Dancing | Targeting"
	const BULLET_DANCE_SHOT_COUNT = 10
	for i in range(BULLET_DANCE_SHOT_COUNT):
		anim_player.play("bullet_dance")
		await anim_player.animation_finished
	state_chart.send_event("end_dancing")


func _on_bullet_dance_recover_state_entered() -> void:
	anim_player.play("RESET")
	await get_tree().create_timer(attack_recovery_time, false).timeout
	state_chart.send_event("reposition")


func _on_bullet_dance_state_exited() -> void:
	boss_map_bartender.toggle_light(true)
	boss_map_bartender.toggle_spotlight(false)


func fire_shotgun_randomly():
	var proj_damage = shotgun_proj_damage * damage_modifier
	sfx_player.stream = sfx_shotgun.pick_random()
	sfx_player.play()

	var max_pitch_deg := 20.0
	var yaw = randf_range(0.0, TAU)
	var pitch = deg_to_rad(randf_range(-max_pitch_deg, max_pitch_deg))
	var aim_direction = Vector3.FORWARD
	aim_direction = aim_direction.rotated(Vector3.UP, yaw)
	# get proper right axis for pitch
	var right_axis = aim_direction.cross(Vector3.UP).normalized()
	aim_direction = aim_direction.rotated(right_axis, pitch)
	aim_direction = aim_direction.normalized()

	for j in range(shotgun_proj_amount):
		var spreaded_direction = GunUtils.get_spread_direction(aim_direction, shotgun_spread_angle)
		var bullet_inst: BartenderShotgunProjectile = chosen_shotgun_proj_prefab.instantiate()
		get_parent().add_child(bullet_inst)
		bullet_inst.init(shotgun_spawn_pos.global_position, spreaded_direction, proj_damage, shotgun_ricochet_count, shotgun_proj_speed)

#endregion

#region Throw broken bottle
func _on_throw_broken_bottle_targeting_state_entered() -> void:
	debug_state_label.text = "Throw Broken Bottle | Targeting"
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_telegraph")
	current_bottle_type = BottleAttack.EMPTY
	anim_player.play("bottle_telegraph")
	await anim_player.animation_finished
	state_chart.send_event("start_throw")


func _on_throw_broken_bottle_throwing_state_entered() -> void:
	debug_state_label.text = "Throw Broken Bottle | Throwing"

	state_chart.send_event("attack_start")
	anim_player.play("bottle_throw")
	await anim_player.animation_finished
	state_chart.send_event("end_throw")


func _on_throw_broken_bottle_recover_state_entered() -> void:
	debug_state_label.text = "Throw Broken Bottle | Recovering"
	state_chart.send_event("attack_end")
	anim_player.play("RESET")
	await get_tree().create_timer(attack_recovery_time * delay_modifier, false).timeout
	state_chart.send_event("reposition")


func throw_projectile(throw_barrel: bool = false) -> void:
	if throw_barrel:
		current_bottle_type = BottleAttack.BARREL
		_throw_bottle(current_bottle_type, 1, 1, barrel_damage)
	else:
		var n_bottle = randi_range(min_n_bottle_per_attack, max_n_bottle_per_attack)
		var spread = randf_range(min_bottles_spread, max_bottles_spread)
		_throw_bottle(current_bottle_type, n_bottle, spread, bottle_damage)


func _throw_bottle(bottle_type: BottleAttack, n_bottle_repeat = 1, _spread_angle = 0, proj_damage = 10) -> void:
	const BOTTLE_PEAK_HEIGHT = 5

	proj_damage *= damage_modifier
	var prefab: PackedScene
	match bottle_type:
		BottleAttack.EMPTY:
			prefab = empty_bottle_prefab
		BottleAttack.FIRE:
			prefab = molotov_prefab
		BottleAttack.POISON:
			prefab = poison_bottle_prefab
		BottleAttack.SLOW:
			prefab = slow_bottle_prefab
		# BottleAttack.HEAL:
		# 	prefab = empty_bottle_prefab
		BottleAttack.BARREL:
			prefab = beer_barrel_prefab
		_:
			return

	var aim_direction = proj_spawn_marker.global_position.direction_to(target.global_position)
	var throw_force = proj_spawn_marker.global_position.distance_to(target.global_position)
	# Magic number that make bartender throw better
	if throw_force >= 30:
		throw_force *= 0.5
	if $StateChart/Root/Status/BrewBuffs/StrengthBuff.active:
		throw_force *= 2
	else:
		aim_direction += Vector3(0, 0.3, 0) # Make it arc upwards a bit
	aim_direction = aim_direction.normalized()

	var modified_spawn_pos = proj_spawn_marker.global_position + aim_direction # Avoid stuck inside boss body

	for i in range(n_bottle_repeat):
		var bottle_inst: BartenderBottle = prefab.instantiate()
		bottle_inst.bartender_owner = self
		get_parent().add_child(bottle_inst)
		var end_pos = GameManager.player.global_position
		bottle_inst.init_tween(modified_spawn_pos, end_pos, proj_damage, BOTTLE_PEAK_HEIGHT)
		if bottle_inst is BartenderBarrel:
			sfx_player.stream = sfx_barrel_throw.pick_random()
		else:
			sfx_player.stream = sfx_bottle_throw.pick_random()
		sfx_player.play()
		await get_tree().create_timer(0.5, false).timeout

#endregion


#region Throw concoction
func _on_throw_drink_targeting_state_entered() -> void:
	debug_state_label.text = "Brew Drink | Targeting"
	#anim_player.speed_scale *= 1.5
	state_chart.send_event("start_targeting")
	# Only throw the barrel if we have the strength buff
	if $StateChart/Root/Status/BrewBuffs/StrengthBuff.active:
		current_bottle_type = BottleAttack.BARREL
	else:
		var bottle_types_no_barrel = BottleAttack.keys().duplicate()
		bottle_types_no_barrel.remove_at(BottleAttack.BARREL)
		if special_bottle_enabled:
			current_bottle_type = get_random_enum_key(bottle_types_no_barrel, last_bottle_attack) as BottleAttack
		else:
			current_bottle_type = BottleAttack.EMPTY
	await get_tree().create_timer(0.2 * delay_modifier, false).timeout
	state_chart.send_event("telegraph_throw")


func _on_throw_drink_flourish_state_entered() -> void:
	debug_state_label.text = "Throw Drink | Flourish"
	state_chart.send_event("attack_telegraph")
	# Get specific anim for type of attack
	var flourish_anim: String
	match current_bottle_type:
		BottleAttack.FIRE:
			flourish_anim = "drink_flourish_fire"
		BottleAttack.POISON:
			flourish_anim = "drink_flourish_poison"
		BottleAttack.SLOW:
			flourish_anim = "drink_flourish_tar"
		BottleAttack.BARREL:
			flourish_anim = "drink_flourish_barrel"
		_:
			state_chart.send_event("reposition")
	anim_player.play(flourish_anim)
	await anim_player.animation_finished
	state_chart.send_event("start_throw")


func _on_throw_drink_throwing_state_entered() -> void:
	debug_state_label.text = "Brew Drink | Drinking"
	# Get specific anim for type of attack
	var throw_anim: String
	match current_bottle_type:
		BottleAttack.FIRE:
			throw_anim = "bottle_throw_fire"
		BottleAttack.POISON:
			throw_anim = "bottle_throw_poison"
		BottleAttack.SLOW:
			throw_anim = "bottle_throw_tar"
		BottleAttack.BARREL:
			throw_anim = "bottle_throw_barrel"
	anim_player.play(throw_anim)
	await anim_player.animation_finished
	state_chart.send_event("end_throw")


func _on_throw_drink_recover_state_entered() -> void:
	debug_state_label.text = "Throw Drink | Recovering"
	state_chart.send_event("attack_end")
	last_bottle_attack = current_bottle_type
	anim_player.play("RESET")
	#anim_player.speed_scale /= 1.5
	await get_tree().create_timer(attack_recovery_time * delay_modifier, false).timeout
	state_chart.send_event("reposition")

#endregion


#region Brew drink
func _on_brew_drink_targeting_state_entered() -> void:
	debug_state_label.text = "Brew Drink | Targeting"
	if not brew_cooldown_timer.is_stopped():
		state_chart.send_event("reposition")
		return
	state_chart.send_event("start_targeting")
	current_brew_type = get_random_enum_key(BrewType.keys(), last_brew_type) as BrewType
	await get_tree().create_timer(0.2 * delay_modifier, false).timeout
	state_chart.send_event("start_brew")


func _on_brew_drink_brewing_state_entered() -> void:
	debug_state_label.text = "Brew Drink | Brewing"
	state_chart.send_event("attack_buildup")
	anim_player.play("drink_brew")
	# TODO - loop anim for a period, then break the loop
	await anim_player.animation_finished
	state_chart.send_event("finish_brew")


func _on_brew_drink_flourish_state_entered() -> void:
	debug_state_label.text = "Brew Drink | Flourish"
	state_chart.send_event("attack_telegraph")
	anim_player.play("drink_flourish")
	await anim_player.animation_finished
	state_chart.send_event("start_drink")


func _on_brew_drink_drinking_state_entered() -> void:
	debug_state_label.text = "Brew Drink | Drinking"
	anim_player.play("drink_consume")
	# TODO - loop anim for a period, then break the loop
	await anim_player.animation_finished
	state_chart.send_event("end_drink")


func _on_brew_drink_recover_state_entered() -> void:
	debug_state_label.text = "Brew Drink | Recovering"
	state_chart.send_event("attack_end")
	anim_player.play("RESET")
	await get_tree().create_timer(attack_recovery_time * delay_modifier, false).timeout
	state_chart.send_event("reposition")

#endregion


#region Countertop Flame
func _on_countertop_flame_moving_state_entered() -> void:
	debug_state_label.text = "Countertop Flame | Moving"
	set_countertop_on_fire()
	state_chart.send_event("to_recover")


func _on_countertop_flame_recover_state_entered() -> void:
	debug_state_label.text = "Countertop Flame | Recover"
	anim_player.play("RESET")
	await get_tree().create_timer(attack_recovery_time * delay_modifier, false).timeout
	state_chart.send_event("reposition")


func set_countertop_on_fire():
	anim_player.play("lit_match")
	await anim_player.animation_finished
	anim_player.play("RESET")
	if countertop_flame_cd_timer.is_stopped():
		boss_map_bartender.create_countertop_flame_wall(countertop_flame_duration)
		countertop_flame_cd_timer.start(countertop_flame_cd)

#endregion

# TODO - should probably be a global utility function
func get_random_enum_key(enum_keys: Array, previous_key: int = -1) -> int:
	var possible_types := enum_keys.duplicate()
	if previous_key != -1 and previous_key < possible_types.size():
		possible_types.remove_at(previous_key)
	var rand_key: String = possible_types.pick_random()
	var type_idx: int = enum_keys.find(rand_key)
	return type_idx


#region BUFF STATE
func _on_no_buff_state_entered() -> void:
	last_brew_type = current_brew_type
	status_icon.texture = null
	health_component.received_dmg_multiplier = BASE_RESISTANCE_MODIFIER
	damage_modifier = BASE_DAMAGE_MODIFIER * GameManager.get_risk_dmg_mult()
	speed_modifier = BASE_SPEED_MODIFIER
	#
	delay_modifier = 1


func _on_strength_buff_state_entered() -> void:
	# STRENGTH:
	#  - damage resistance DECREASED
	#  - damage output INCREASED
	#  - movement speed UNAFFECTED
	health_component.received_dmg_multiplier = strength_buff_modifier
	damage_modifier = strength_buff_modifier * GameManager.get_risk_dmg_mult()
	speed_modifier = BASE_SPEED_MODIFIER
	delay_modifier = BASE_DELAY_MODIFIER

	status_icon.texture = strength_icon


func _on_defence_buff_state_entered() -> void:
	# DEFENCE:
	#  - damage resistance INCREASED
	#  - damage output UNAFFECTED
	#  - movement speed DECREASED
	health_component.received_dmg_multiplier = defense_buff_modifier
	damage_modifier = BASE_DAMAGE_MODIFIER * GameManager.get_risk_dmg_mult()
	speed_modifier = 1 - defense_buff_modifier
	delay_modifier = 1 + speed_buff_modifier

	status_icon.texture = defense_icon
	sfx_player.stream = sfx_defense


func _on_speed_buff_state_entered() -> void:
	# SPEED:
	#  - damage resistance UNAFFECTED
	#  - damage output DECREASED
	#  - movement speed INCREASED
	health_component.received_dmg_multiplier = BASE_RESISTANCE_MODIFIER
	damage_modifier = BASE_DAMAGE_MODIFIER * GameManager.get_risk_dmg_mult()
	speed_modifier = 1 + speed_buff_modifier
	delay_modifier = 1 - speed_buff_modifier

	navigation_component.current_speed = base_movespeed * speed_modifier

	status_icon.texture = speed_icon
	sfx_player.stream = sfx_speed


func _on_buff_expire_timer_timeout() -> void:
	state_chart.send_event("remove_buff")

#endregion


func _on_sleight_of_hand_timer_timeout() -> void:
	var n_bottle = randi_range(min_n_bottle_per_attack, max_n_bottle_per_attack)
	var spread = randf_range(min_bottles_spread, max_bottles_spread)
	var bottle_types_no_barrel = BottleAttack.keys().duplicate()
	bottle_types_no_barrel.remove_at(BottleAttack.BARREL)
	var sleight_bottle_type = BottleAttack.EMPTY
	if special_bottle_enabled:
		sleight_bottle_type = get_random_enum_key(bottle_types_no_barrel) as BottleAttack
	_throw_bottle(sleight_bottle_type, n_bottle, spread, bottle_damage)
