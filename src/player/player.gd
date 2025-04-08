extends CharacterBody3D
class_name Player

@export_category("SFX")
@export var sfx_hurt: Array[AudioStream]
@export var sfx_dead: Array[AudioStream]
@export var sfx_dead_falling: Array[AudioStream]
var movement_sfx_player: AudioStreamPlayer
@export var sfx_movement_loop: AudioStream
@export var sfx_movement_steps: Array[AudioStream]
@export var sfx_crouch: Array[AudioStream]
@export var sfx_stand: Array[AudioStream]
@export var sfx_jump_ground: Array[AudioStream]
@export var sfx_jump_air: Array[AudioStream]
@export var sfx_dash_floor: Array[AudioStream]
@export var sfx_dash_air: Array[AudioStream]

@export_category("Movement")
@export var can_wall_jump: bool
@export var can_wall_cling: bool
@export var max_air_jump = 2
@export var dash_cd: float = 0.5
@export var angular_momentum_multiplier = 0.4
@export var speedline_vfx_prefab: PackedScene

@export_category("Prefabs")
@export var health_component: HealthComponent

@onready var hurt_overlay: Control = $UI/HurtOverlay
@onready var interact_ui: Label = $UI/InteractUI

@onready var player_camera: ShakeCameraWrapper = $Neck/ShakeCameraWrapper
@onready var debug_label: Label = $Neck/ShakeCameraWrapper/DebugLabel
@onready var debug_meshes: Node3D = $DebugMeshes
@onready var dash_duration_timer: Timer = $DashDuration
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var neck: Node3D = $Neck
@onready var state_chart: StateChart = $StateChart
@onready var wall_raycast: RayCast3D = $WallRaycast

@onready var gun_container = $Neck/ShakeCameraWrapper/GunContainer
@onready var aim_ray: AimRay = $Neck/ShakeCameraWrapper/AimRay
@onready var hitmarker: TextureRect = $Neck/ShakeCameraWrapper/HitMarker
@onready var magazine_label: Label = $UI/GunUI/MagazineUI
@onready var all_barrel_effect_ui = $UI/GunUI/AllBarrelEffectUI

@onready var boss_special_dialog = $UI/BossSpecialDialog
@onready var boss_special_dialog_label: Label = $UI/BossSpecialDialog/Label

signal movement_dashed

const MAX_SPEED: float = 8.0
var max_speed: float = MAX_SPEED
const MAX_FALL_SPEED: float = 70.0
const ACCEL_RATE: float = 40.0
const JUMP_FORCE: float = 10
const GRAVITY: float = 30
const FALL_SPEED_TO_SHAKE_CAMERA: float = 15
const HEAVY_FALL_SHAKE_TRAUMA: float = 0.8
const SLIDE_SHAKE_TRAUMA: float = 0.1
const MIN_HEIGHT_TO_SLAM: float = 1.5
const SWAP_GUN_TIME: float = 0.3
const BULLET_SPAWN_POS_VARIATION: float = 10
const INTERACT_DISTANCE = 5

const DASH_SPEED: float = 15
const SLAM_SPEED: float = 25
const CROUCH_SPEED_MODIFIER: float = 0.5

var floor_col_pos = Vector3.ZERO
var jumped: bool = false
var can_coyote_jump: bool = false
var vel_horizontal := Vector2(0, 0)
var vel_vertical: float = 0

var is_dashing: bool = false
var is_crouching: bool = false

var internal_bonus_speed: float = 0

var raw_input_dir := Vector2(0, 0):
	set(value):
		if is_on_floor() and raw_input_dir == Vector2.ZERO and value != Vector2.ZERO:
			movement_sfx_player = SoundManager.play_sound(sfx_movement_loop, "SFX")
		raw_input_dir = value
		if is_instance_valid(movement_sfx_player):
			if raw_input_dir == Vector2.ZERO and movement_sfx_player.playing:
				SoundManager.stop_sound(sfx_movement_loop)
var input_dir := Vector2(0, 0)

var last_dashed_timestamp
var current_air_jump_count: int = 0
var slide_dir := Vector2(0, 0)

var controls_disabled: bool = false
var dash_disabled: bool = false

var gun_container_original_pos: Vector3
var gun_container_original_rot: Vector3
var current_gun_slot = 0
var is_swapping_gun = false
var current_gun: Gun = null

var is_in_inventory = false
var object_to_be_interacted = null

var buffs: Array[Buff] = []
var base_stats = {
	"run_speed_modifier": 1,
	"dash_slide_speed_modifier": 1
}
var current_stats = base_stats.duplicate(true)


func _ready():
	GameManager.player = self
	for mesh in debug_meshes.get_children():
		mesh.visible = false
	player_camera.set_fov(GameManager.camera_fov)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	last_dashed_timestamp = 0
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	gun_container_original_pos = gun_container.position
	gun_container_original_rot = gun_container.rotation
	interact_ui.visible = false
	boss_special_dialog.visible = false
	current_gun = gun_container.get_child(0)
	current_gun.gun_shot.connect(update_hud)
	current_gun.gun_reloaded.connect(update_hud)
	movement_dashed.connect(current_gun.check_barrel_effect_on_dash_movement)


func _input(event):
	if controls_disabled:
		return

	#if event.is_action_pressed("open_inventory"):
		#inventory_ui.toggle()

	if is_in_inventory:
		return

	if event is InputEventMouseMotion:
		rotate_player(event)

	if event.is_action_pressed("spin_reload"):
		spin_reload()
	# TODO - experimental branch separating spin from reload
	#elif event.is_action_pressed("spin_barrels"):
		#current_gun.spin_all_barrels()
	#elif event.is_action_pressed("input_1"):
		#current_gun.spin_single_barrel(0)
	#elif event.is_action_pressed("input_2"):
		#current_gun.spin_single_barrel(1)
	#elif event.is_action_pressed("input_3"):
		#current_gun.spin_single_barrel(2)

	if event.is_action_pressed("dash"):
		if dash_disabled:
			return
		if last_dashed_timestamp + dash_cd * 1000 <= Time.get_ticks_msec():
			last_dashed_timestamp = Time.get_ticks_msec()
			is_dashing = true
			if is_on_floor():
				SoundManager.play_sound_with_pitch(
					sfx_dash_floor.pick_random(), randf_range(0.8, 1.1), "SFX"
				)
			else:
				SoundManager.play_sound_with_pitch(
					sfx_dash_air.pick_random(), randf_range(0.8, 1.1), "SFX"
				)
			vel_vertical = 0
			dash_duration_timer.start()
			movement_dashed.emit()


			var dash_dir = raw_input_dir
			# Swap speedline direction for horizontal dash
			dash_dir.x = - dash_dir.x
			if raw_input_dir.length() == 0:
				dash_dir = Vector2(0, -1)
			var angle_radians = dash_dir.angle()
			var pe: Node3D = speedline_vfx_prefab.instantiate()
			add_child(pe)
			pe.global_position = global_position
			pe.rotate_y(angle_radians)

	if Input.is_action_just_pressed("interact"):
		if object_to_be_interacted:
			object_to_be_interacted.interact()
			get_viewport().set_input_as_handled()

	if Input.is_action_just_pressed("crouch"):
		SoundManager.play_sound(sfx_crouch.pick_random(), "SFX")
	elif Input.is_action_just_released("crouch"):
		SoundManager.play_sound(sfx_stand.pick_random(), "SFX")


func _process(delta):
	hitmarker.modulate.a = clamp(hitmarker.modulate.a - delta * 3, 0, 1)

	for buff in buffs:
		if buff.duration > 0:
			buff.duration -= delta
			if buff.duration <= 0:
				remove_buff(buff)

	if aim_ray.is_colliding():
		var interact_collider = aim_ray.get_collider()
		if interact_collider and \
			interact_collider.has_method("interact") and \
			interact_collider.global_position.distance_to(global_position) <= INTERACT_DISTANCE:
			object_to_be_interacted = interact_collider
			interact_ui.visible = true
		else:
			object_to_be_interacted = null
			interact_ui.visible = false
	else:
		object_to_be_interacted = null
		interact_ui.visible = false


	if controls_disabled or is_in_inventory:
		return

	if Input.is_action_pressed("shoot"):
		# Raycast to target and damage them if hit
		current_gun.pull_trigger()
		current_gun.shoot(aim_ray)

	if Input.is_action_just_released("shoot"):
		current_gun.release_trigger()

func _physics_process(delta):
	if controls_disabled:
		input_dir = Vector2.ZERO
		velocity = Vector3(0, -GRAVITY, 0)
		move_and_slide()
		return

	if is_dashing:
		if raw_input_dir == Vector2.ZERO:
			raw_input_dir = Vector2(0, -1)
			input_dir = raw_input_dir.rotated(-rotation.y)

	if not is_dashing and not is_in_inventory:
		raw_input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		input_dir = raw_input_dir.rotated(-rotation.y)

	# If the next line is for grounded only, we will have bunnyhop tech
	# If not move, gradually reduce movespeed to 0 (speed decay)
	vel_horizontal -= vel_horizontal.normalized() * (ACCEL_RATE / 2) * delta
	# Stand still
	if vel_horizontal.length_squared() < 1.0 and input_dir.length_squared() < 0.01:
		vel_horizontal = Vector2.ZERO

	if is_on_floor():
		state_chart.send_event("grounded")
		current_air_jump_count = 0
		if vel_vertical < 0:
			if vel_vertical < -FALL_SPEED_TO_SHAKE_CAMERA:
				player_camera.add_trauma(HEAVY_FALL_SHAKE_TRAUMA)
			jumped = false
			vel_vertical = 0
	else:
		state_chart.send_event("airborne")

	# Use the next line will make player move faster when strafing + rotate camera
	# var current_speed = vel_horizontal.dot(input_dir)
	var current_speed = vel_horizontal.length()
	if is_crouching:
		max_speed = MAX_SPEED * CROUCH_SPEED_MODIFIER
	else:
		max_speed = MAX_SPEED
	var add_speed = clamp(max_speed - current_speed, 0.0, ACCEL_RATE * delta)

	if is_dashing:
		vel_horizontal = input_dir * max_speed
	elif is_crouching:
		vel_horizontal += input_dir * add_speed
	else:
		vel_horizontal += input_dir * add_speed

	velocity = Vector3(vel_horizontal.x, vel_vertical, vel_horizontal.y) * current_stats["run_speed_modifier"]

	# Bonus speed
	if is_dashing:
		internal_bonus_speed = DASH_SPEED
	else:
		if is_on_floor():
			internal_bonus_speed = lerpf(internal_bonus_speed, 0, delta * 9)
		else:
			internal_bonus_speed = lerpf(internal_bonus_speed, 0, delta * 3)

	var velocity_dir = velocity.normalized()
	velocity += Vector3(velocity_dir.x, 0, velocity_dir.z) * internal_bonus_speed * current_stats["dash_slide_speed_modifier"]

	# Let the player ignore the wheelspin if they are moving
	var floor_velocity = get_platform_velocity()
	if floor_velocity and input_dir != Vector2.ZERO:
		var dir_weight = input_dir.dot(Vector2(
			floor_velocity.normalized().x,
			floor_velocity.normalized().z,
		))
		velocity += floor_velocity * dir_weight

	move_and_slide()

	#show_debug_label()
	var gun_sway_velocity = velocity * transform.basis
	if not is_swapping_gun:
		gun_container.position = lerp(gun_container.position, gun_container_original_pos - (gun_sway_velocity / 500), delta * 10)
		if is_dashing:
			gun_container.rotation.z = lerp(gun_container.rotation.z, gun_container_original_rot.z - (gun_sway_velocity.x / 250), delta * 10)
		else:
			gun_container.rotation.z = lerp(gun_container.rotation.z, gun_container_original_rot.z, delta * 10)
	camera_control(delta)

func update_hud():
	magazine_label.text = "{0}/{1}".format([current_gun.magazine_ammo_left, current_gun.modified_magazine_size])
	for i in range(current_gun.max_barrels):
		var effect_ui = all_barrel_effect_ui.get_child(i)
		if current_gun.barrel_container.get_child_count() > i:
			var barrel: SpinBarrel = current_gun.barrel_container.get_child(i)
			if barrel:
				effect_ui.get_node("Title").text = barrel.get_active_effect().display_text_title
				effect_ui.get_node("Tag").text = barrel.get_active_effect().display_text_tag
				effect_ui.get_node("Desc").text = barrel.get_active_effect().display_text_desc
			else:
				effect_ui.get_node("Title").text = ""
				effect_ui.get_node("Tag").text = ""
				effect_ui.get_node("Desc").text = ""
		else:
			effect_ui.get_node("Title").text = ""
			effect_ui.get_node("Tag").text = ""
			effect_ui.get_node("Desc").text = ""

func show_debug_label():
	var h_speed = snapped(Vector3(velocity.x, 0, velocity.z).length(), 0.1)
	var v_speed = snapped(vel_vertical, 0.1)
	var snapped_height = snapped(global_position.y, 0.1)
	Engine.get_frames_per_second()
	debug_label.text = ""
	debug_label.text += "FPS: {0}".format([Engine.get_frames_per_second()])
	debug_label.text += "\nHSpeed: {0} u/s\nVSpeed: {1} u/s".format([h_speed, v_speed])
	debug_label.text += "\nHeight from ground: {0}".format([snapped_height - 1.5])
	debug_label.text += "\nOn ground: {0} | wall-cling: {1}".format([is_on_floor(), moving_toward_wall()])
	debug_label.text += "\nIs dashing: {0} | Is sliding: {1}".format([is_dashing, is_crouching])
	debug_label.text += "\nAir jumps move_left: {0}".format([max_air_jump - current_air_jump_count])
	debug_label.text += "\nCoyote jump: {0}".format([can_coyote_jump])
	#debug_label.text += "\nUsing gun: {0}".format([gun_container.get_child(current_gun_slot).data.name])


func jump(multiplier = 1.0):
	vel_vertical = JUMP_FORCE * multiplier

	jumped = true
	state_chart.send_event("jump")
	is_dashing = false
	is_crouching = false

	if is_on_floor():
		SoundManager.play_sound_with_pitch(
			sfx_jump_ground.pick_random(), randf_range(0.8, 1.1), "SFX"
		)
	else:
		SoundManager.play_sound_with_pitch(
			sfx_jump_air.pick_random(), randf_range(0.8, 1.1), "SFX"
		)


func stun(time: float) -> void:
	max_speed = MAX_SPEED / 4
	dash_disabled = true
	hurt_overlay.stun(time)
	await get_tree().create_timer(time).timeout
	max_speed = MAX_SPEED
	dash_disabled = false


func spin_reload() -> void:
	current_gun.spin_all_barrels()


func no_spin_reload() -> void:
	current_gun.reload()


func rotate_player(event):
	rotate(Vector3(0, -1, 0), event.relative.x * (GameManager.mouse_sensitivity / 10000))
	player_camera.rotate_x(-event.relative.y * (GameManager.mouse_sensitivity / 10000))
	player_camera.rotation.y = 0
	player_camera.rotation.z = 0
	player_camera.rotation.x = clamp(player_camera.global_rotation.x, deg_to_rad(-89), deg_to_rad(89))

func camera_control(delta):
	# Tilt camera
	if GameManager.camera_tilt:
		if raw_input_dir.x < 0:
			neck.rotation.z = lerp(neck.rotation.z, deg_to_rad(3.0), delta * 5)
		elif raw_input_dir.x > 0:
			neck.rotation.z = lerp(neck.rotation.z, deg_to_rad(-3.0), delta * 5)
		else:
			neck.rotation.z = lerp(neck.rotation.z, deg_to_rad(0), delta * 5)

	# Lower camera
	if is_crouching:
		neck.position.y = lerp(neck.position.y, -1.0, delta * 5)
	else:
		neck.position.y = lerp(neck.position.y, 0.0, delta * 5)


func ground_slam():
	var test_motion = Vector3(0, -MIN_HEIGHT_TO_SLAM, 0)
	if move_and_collide(test_motion, true):
		return
	vel_horizontal = Vector2.ZERO
	vel_vertical -= SLAM_SPEED


func apply_impulse_to_player(impulse_force: Vector3):
	vel_vertical = impulse_force.y
	vel_horizontal = Vector2(impulse_force.x, impulse_force.z)

func _on_dash_duration_timeout() -> void:
	is_dashing = false


func _on_grounded_state_input(event: InputEvent):
	if event.is_action_pressed("jump"):
		jump()

func _on_grounded_state_physics_processing(_delta: float):
		if Input.is_action_pressed("crouch"):
			is_crouching = true
		else:
			is_crouching = false


func _on_airborne_state_input(event: InputEvent):
	if event.is_action_pressed("jump"):
		if can_coyote_jump and not jumped:
			jump()
		elif current_air_jump_count < max_air_jump:
			current_air_jump_count += 1
			jump()


func _on_airborne_state_entered() -> void:
	is_crouching = false
	if not jumped:
		coyote_timer.start()
		can_coyote_jump = true


func _on_airborne_state_physics_processing(delta: float) -> void:
	if not is_dashing:
		vel_vertical -= GRAVITY * delta
	vel_vertical = clamp(vel_vertical, -MAX_FALL_SPEED, 10000)
	if Input.is_action_just_pressed("crouch"):
		ground_slam()
	if moving_toward_wall() and can_wall_cling:
		state_chart.send_event("wallcling")


func moving_toward_wall() -> bool:
	wall_raycast.target_position = Vector3(raw_input_dir.x, 0, raw_input_dir.y)
	if is_on_wall_only() and wall_raycast.is_colliding():
		return true
	return false


func flash_hitmarker(color: Color = Color.YELLOW):
	hitmarker.modulate = color
	hitmarker.modulate.a = 1


func _on_coyote_timer_timeout():
	can_coyote_jump = false


func _on_wallcling_state_entered() -> void:
	jumped = false


func _on_wallcling_state_physics_processing(delta: float) -> void:
	if raw_input_dir.y == 0 or not is_on_wall_only():
		state_chart.send_event("stop_wallcling")
	vel_vertical -= GRAVITY * delta
	vel_vertical = clampf(vel_vertical, -1, 10000)


func _on_wallcling_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		if can_wall_jump:
			var wall_normal = get_wall_normal()
			# Jump away from wall
			vel_horizontal += Vector2(wall_normal.x, wall_normal.z) * 16
			jump(0.8)


func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		state_chart.send_event("start_damage")
		SoundManager.play_sound(sfx_hurt.pick_random())
		if new_health > 0:
			state_chart.send_event("end_damage")


func _on_died() -> void:
	state_chart.send_event("death")
	SoundManager.play_sound(sfx_dead.pick_random())


func fall_death() -> void:
	health_component.current_health = 0
	state_chart.send_event("death")
	SoundManager.play_sound(sfx_dead_falling.pick_random(), "SFX")


func _on_health_hurt_state_entered() -> void:
	hurt_overlay.hurt()


func _on_health_dead_state_entered() -> void:
	controls_disabled = true
	hurt_overlay.dead()

func _on_health_dead_state_physics_processing(delta: float) -> void:
	neck.rotation.z = lerp(neck.rotation.z, deg_to_rad(-3.0), delta * 5)
	neck.position.y = lerp(neck.position.y, -1.0, delta * 5)

func add_buff(new_buff: Buff):
	# Check if already exist, then extend it instead of add new
	for buff in buffs:
		if buff.buff_name == new_buff.buff_name:
			buff.duration = max(buff.duration, new_buff.duration)
			return
	buffs.append(new_buff)
	apply_buffs()


func remove_buff(buff: Buff):
	buffs.erase(buff)
	apply_buffs()

func remove_buff_by_name(find_name: String):
	var found_buff = null
	for buff in buffs:
		if buff.buff_name == find_name:
			found_buff = buff
			break
	if found_buff:
		remove_buff(found_buff)

func apply_buffs():
	# Reset current stats to base stats.
	current_stats = base_stats.duplicate(true)

	# Temporary storage for stacking.
	var flat_bonuses = {}
	var percentage_bonuses = {}

	for buff in buffs:
		if buff.buff_type == Buff.BuffType.FLAT:
			flat_bonuses[buff.stat_name] = flat_bonuses.get(buff.stat_name, 0) + buff.value
		elif buff.buff_type == Buff.BuffType.PERCENTAGE:
			percentage_bonuses[buff.stat_name] = percentage_bonuses.get(buff.stat_name, 0) + buff.value

	# Apply flat bonuses (additive).
	for stat in flat_bonuses.keys():
		current_stats[stat] += flat_bonuses[stat]

	# Apply percentage bonuses (multiplicative).
	for stat in percentage_bonuses.keys():
		current_stats[stat] *= (1 + percentage_bonuses[stat] / 100.0)
