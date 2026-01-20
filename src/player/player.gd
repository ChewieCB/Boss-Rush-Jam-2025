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
@export var sfx_purchase: AudioStream
@export var sfx_too_expensive: AudioStream

@export_category("Movement")
@export var can_wall_jump: bool
@export var can_wall_cling: bool
@export var max_air_jump = 2
@export var dash_cd: float = 1
@export var angular_momentum_multiplier = 0.4
@export var speedline_vfx_prefab: PackedScene

@export_category("Prefabs")
@export var health_component: HealthComponent
@export var luck_component: LuckComponent
@export var freecam_prefab: PackedScene

@export_category("Luck")
@export var luck_redeem_time: float = 2.0
@export var reroll_heal_value: float = 25.0

@onready var hurt_overlay: Control = $UI/HurtOverlay
@onready var interact_ui: InteractUI = $UI/InteractUI

@onready var player_camera: ShakeCameraWrapper = $Neck/ShakeCameraWrapper
@onready var debug_label: Label = $Neck/ShakeCameraWrapper/DebugLabel
@onready var debug_meshes: Node3D = $DebugMeshes
@onready var dash_duration_timer: Timer = $DashDuration
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var neck: Node3D = $Neck
@onready var gun: Node3D = $Neck/ShakeCameraWrapper/GunContainer/BlankGun
@onready var state_chart: StateChart = $StateChart
@onready var wall_raycast: RayCast3D = $WallRaycast
@onready var standing_shape: CollisionShape3D = $CollisionStanding
@onready var crouching_shape: CollisionShape3D = $CollisionCrouching

@onready var gun_container = $Neck/ShakeCameraWrapper/GunContainer
@onready var aim_ray: AimRay = $Neck/ShakeCameraWrapper/Camera3D/AimRay
@onready var laser_guide_ray: RayCast3D = $Neck/ShakeCameraWrapper/Camera3D/LaserGuideRayCast
@onready var aim_assist_ray: RayCast3D = $Neck/ShakeCameraWrapper/AimAssistRaycast
@onready var aim_assist_ray_boss_check: RayCast3D = $Neck/ShakeCameraWrapper/AimAssistRaycastBossCheck
@onready var hitmarker: TextureRect = $Neck/ShakeCameraWrapper/HitMarker

@onready var ui_parent = $UI
@onready var barrel_effect_ui = $UI/GunUI
@onready var barrel_detail_dimmer = $UI/GunUI/DimScreen
@onready var barrel_detail_ui = $UI/GunUI/BarrelEffectsUI
@onready var barrel_ui_tween: Tween = null
var barrel_ui_active: bool = false

@onready var debug_inventory_ui = $UI/DebugInventoryUI

@onready var stat_ui: StatUI = $UI/StatUI
@onready var health_ui = stat_ui.health_ui
@onready var luck_bar_ui = stat_ui.luck_bar_ui
@onready var drunk_ui: Control = $UI/DrunkUI

@onready var boss_special_dialog = $UI/BossSpecialDialog
@onready var boss_special_dialog_label: Label = $UI/BossSpecialDialog/Label
@onready var near_enemy_area: Area3D = $NearEnemyRadius
var enemy_near_counter = 0

@export_group("Status Effects")
@export_subgroup("Drunk")
@onready var drunk_timer: Timer = $StateChart/Root/Status/Drunk/DrunkTimer
@export var drunk_movement_drift: float = 1.0
@export var drunk_movement_drift_change_interval: float = 0.8
var drunk_drift_timer: float = 0.0
var drunk_drift_vector := Vector2.ZERO
var drunk_target_drift_vector := Vector2.ZERO

signal movement_dashed
signal movement_crouched
signal new_status_effect_added(status)
signal status_effect_removed(status_effect_code)

const MAX_SPEED: float = 8.0
const MAX_FALL_SPEED: float = 70.0
const ACCEL_RATE: float = 40.0
const JUMP_FORCE: float = 10
const GRAVITY: float = 30
const FALL_SPEED_TO_SHAKE_CAMERA: float = 15
const HEAVY_FALL_SHAKE_TRAUMA: float = 0.4
const SLIDE_SHAKE_TRAUMA: float = 0.1
const MIN_HEIGHT_TO_SLAM: float = 1.5
const SWAP_GUN_TIME: float = 0.3
const BULLET_SPAWN_POS_VARIATION: float = 10
const INTERACT_DISTANCE = 5

const MOUSE_SENSITIVITY_COEEFICIENT = 10000
const CONTROLLER_SENSITIVITY_COEEFICIENT = 10

const DASH_SPEED: float = 15
const SLAM_SPEED: float = 25
const CROUCH_SPEED_MODIFIER: float = 0.5

const AIM_ASSIST_STRENGTH_COEFFICIENT = 4 # Higher = stronger auto rotate to target. 1-10
const AIM_ASSIST_CAMERA_REDUCTION_COEFFICIENT = 0.8 # Higher = stronger stickiness when near target. 0-1
const AIM_ASSIST_MAX_RANGE = 50

var max_speed: float = MAX_SPEED
var floor_col_pos = Vector3.ZERO
var jumped: bool = false
var can_coyote_jump: bool = false
var vel_horizontal := Vector2(0, 0)
var vel_vertical: float = 0

var is_dashing: bool = false
var is_crouching: bool = false:
	set(value):
		if value != is_crouching:
			movement_crouched.emit()
		is_crouching = value
		standing_shape.disabled = is_crouching
		crouching_shape.disabled = not is_crouching

var uncrouch_collision_check_count = 0

var internal_bonus_speed: float = 0

var raw_input_dir = Vector2(0, 0):
	set(value):
		if is_on_floor() and raw_input_dir == Vector2.ZERO and value != Vector2.ZERO:
			movement_sfx_player = SoundManager.play_sound(sfx_movement_loop, "SFX")
		raw_input_dir = value
		if is_instance_valid(movement_sfx_player):
			if raw_input_dir == Vector2.ZERO and movement_sfx_player.playing:
				SoundManager.stop_sound(sfx_movement_loop)
var input_dir = Vector2(0, 0)

var last_dashed_timestamp
var current_air_jump_count: int = 0
var slide_dir = Vector2(0, 0)

var controls_disabled: bool = true
var dash_disabled: bool = false

var gun_container_original_pos: Vector3
var gun_container_original_rot: Vector3
var current_gun_slot = 0
var is_swapping_gun = false
var current_gun: Gun = null

# Hide most HUD and stop player control
var is_in_menu = false:
	set(value):
		is_in_menu = value
		if is_in_menu:
			stat_ui.hide_all_ui()
		else:
			stat_ui.show_all_ui()
var object_to_be_interacted = null

var status_effect_list: Array[StatusEffect] = []
var base_stats = {
	StatusEffect.PlayerStatEnum.RUN_SPEED_MODIFIER: 1,
	StatusEffect.PlayerStatEnum.DASH_SPEED_MODIFIER: 1,
	StatusEffect.PlayerStatEnum.IS_INVINVIBLE: false,
	StatusEffect.PlayerStatEnum.DAMAGE_REDUCTION: 0,
	StatusEffect.PlayerStatEnum.JUMP_HEIGHT: 1,
	StatusEffect.PlayerStatEnum.DASH_IFRAME_DURATION: 0.2,
	StatusEffect.PlayerStatEnum.DASH_DURATION: 0.2,
	StatusEffect.PlayerStatEnum.CHIP_DROPRATE_MULTIPLIER: 1,
	StatusEffect.PlayerStatEnum.MIN_DAMAGE_VARIANCE: 0.8, # In decimal, so 0.8 = 80%
	StatusEffect.PlayerStatEnum.MAX_DAMAGE_VARIANCE: 1.2, # 1.2 = 120%
	StatusEffect.PlayerStatEnum.CRITICAL_HIT_CHANCE: 0, # In decimal, so 0.5 = 50%
	StatusEffect.PlayerStatEnum.CRITICAL_HIT_DAMAGE_MULTIPLIER: 2.0, # In decimal
	StatusEffect.PlayerStatEnum.DODGE_CHANCE: 0, # In decimal
	StatusEffect.PlayerStatEnum.FLOOR_FRICTION_MODIFIER: 1.0,
}
var current_stats = base_stats.duplicate(true)

var dash_iframe_icon = preload("res://assets/sprite/status_icon/invincible.png")
var cheat_death_icon = preload("res://assets/sprite/skilltree_icon/cheat_death.png")
var double_down_icon = preload("res://assets/sprite/skilltree_icon/double_down.png")

var aim_assist_target: Node3D = null
var cheat_death_triggered = false

var freecam: FreeCam


func _ready():
	GameManager.player = self
	for mesh in debug_meshes.get_children():
		mesh.visible = false
	player_camera.set_fov(GameManager.camera_fov)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	last_dashed_timestamp = 0

	stat_ui.health_component = health_component
	stat_ui.luck_component = luck_component

	health_component.show_damage_text = false
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	health_component.is_owned_by_player = true

	gun_container_original_pos = gun_container.position
	gun_container_original_rot = gun_container.rotation

	interact_ui.visible = false
	boss_special_dialog.visible = false

	standing_shape.disabled = false
	crouching_shape.disabled = true

	current_gun = gun_container.get_child(0)
	current_gun.gun_shot.connect(update_ammo_counter_ui)
	current_gun.full_clip_reload_started.connect(full_reload_ammo_counter_ui)
	current_gun.gun_reloaded.connect(update_ammo_counter_ui)
	current_gun.barrel_spin_stopped.connect(update_barrel_effect_ui.unbind(2))
	current_gun.barrel_spin_stopped.connect(update_ammo_counter_ui.unbind(2))
	current_gun.barrel_equipped.connect(update_barrel_effect_ui.unbind(2))
	current_gun.barrel_unequipped.connect(update_barrel_effect_ui.unbind(2))
	current_gun.barrel_effect_set.connect(update_barrel_effect_ui.unbind(2))
	current_gun.barrel_effect_set.connect(update_ammo_counter_ui.unbind(2))
	update_barrel_effect_ui()
	movement_dashed.connect(current_gun.check_barrel_effect_on_dash_movement)
	health_component.hurt.connect(current_gun.check_barrel_effect_on_player_damaged)
	update_ammo_counter_ui()

	await get_tree().process_frame
	await get_tree().process_frame

	check_permanent_buffs()
	luck_component.check_for_high_luck_buffs()

	# CHEATS
	if GameManager.CHEAT_godmode:
		health_component.is_invincible = true

	#debug_inventory_ui.has_custom_inventory = true
	#debug_inventory_ui.current_inventory = GameManager.debug_barrel_database


func _unhandled_input(event):
	if controls_disabled:
		return

	#if event.is_action_pressed("open_inventory"):
		#inventory_ui.toggle()

	if is_in_menu:
		return

	if event is InputEventMouseMotion:
		# If we have a controller connected, ignore mouse events
		# (this prevents the PS4 trackpad from triggering aim)
		# if Input.get_connected_joypads():
		# 	return
		rotate_player(event.relative.x, event.relative.y)
	elif event is InputEventJoypadMotion:
		if not InputHelper.get_label_for_input(event).to_lower().contains("trigger"):
			# Disable joystick support to prevent PS4 touchpad triggering aim events
			# Has to check Trigger buttons first, since they are also InputEventJoypadMotion
			return

	if event.is_action_pressed("spin_reload"):
		no_spin_reload()
	elif event.is_action_pressed("spin_barrels"):
		if GameManager.CHEAT_spin_mode != GameManager.DebugSpinMode.ON_RELOAD:
			spin_barrels()
	# DEBUG
	#elif event.is_aend_event("add_status_drunk")
		#current_gun.spin_single_barrel(0)
	elif event.is_action_pressed("input_1"):
		LuckHandler.increase_luck(20.0)
		#state_chart.send_event("remove_status_drunk")
		#current_gun.spin_single_barrel(1)
	#elif event.is_action_pressed("input_3"):
		#health_component.damage(20)

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
			dash_duration_timer.start(current_stats[StatusEffect.PlayerStatEnum.DASH_DURATION])
			movement_dashed.emit()
			add_iframe_on_dash()

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
		elif GameManager.CHEAT_always_inventory:
			debug_inventory_ui.toggle()
			GameManager.player.input_dir = Vector2.ZERO
			GameManager.player.vel_horizontal = Vector2.ZERO
			GameManager.player.velocity = Vector3.ZERO

	if Input.is_action_just_pressed("crouch"):
		SoundManager.play_sound(sfx_crouch.pick_random(), "SFX")
	elif Input.is_action_just_released("crouch"):
		SoundManager.play_sound(sfx_stand.pick_random(), "SFX")

	if Input.is_action_just_pressed("show_detail"):
		show_barrel_effect_ui()
	elif Input.is_action_just_released("show_detail"):
		hide_barrel_effect_ui()


func _process(delta):
	handle_controller_look(delta)

	hitmarker.modulate.a = clamp(hitmarker.modulate.a - delta * 3, 0, 1)

	for status in status_effect_list:
		if status.duration > 0 and status.duration < StatusEffect.INFINITE_DURATION:
			status.duration -= delta
			if status.duration <= 0:
				remove_status_effect(status)

	if aim_ray.is_colliding() and not is_in_menu:
		var interact_collider = aim_ray.get_collider()
		if interact_collider and \
			interact_collider.has_method("interact") and \
			interact_collider.global_position.distance_to(global_position) <= INTERACT_DISTANCE:
			object_to_be_interacted = interact_collider
			interact_ui.visible = true
			if interact_collider.has_method("get_interact_text"):
				interact_ui.show_custom_text(interact_collider.get_interact_text())
			else:
				interact_ui.show_default_text()
		else:
			object_to_be_interacted = null
			interact_ui.visible = false
	else:
		object_to_be_interacted = null
		interact_ui.visible = false


	if controls_disabled or is_in_menu:
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

	if not is_dashing and not is_in_menu:
		raw_input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		input_dir = raw_input_dir.rotated(-rotation.y)

	# Let the player ignore the wheelspin if they are moving
	var floor_velocity = get_platform_velocity()
	if floor_velocity: # and input_dir != Vector2.ZERO:
		var dir_weight = input_dir.dot(Vector2(
			floor_velocity.normalized().x,
			floor_velocity.normalized().z,
		))
		velocity += floor_velocity * dir_weight

	# If the next line is for grounded only, we will have bunnyhop tech
	# If not move, gradually reduce movespeed to 0 (speed decay)
	vel_horizontal -= vel_horizontal.normalized() * (ACCEL_RATE / 2) * delta * current_stats[StatusEffect.PlayerStatEnum.FLOOR_FRICTION_MODIFIER]
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

	velocity = Vector3(vel_horizontal.x, vel_vertical, vel_horizontal.y) * current_stats[StatusEffect.PlayerStatEnum.RUN_SPEED_MODIFIER]

	# Bonus speed
	if is_dashing:
		internal_bonus_speed = DASH_SPEED
	else:
		if is_on_floor():
			internal_bonus_speed = lerpf(internal_bonus_speed, 0, delta * 9)
		else:
			internal_bonus_speed = lerpf(internal_bonus_speed, 0, delta * 3)

	var velocity_dir = velocity.normalized()
	velocity += Vector3(velocity_dir.x, 0, velocity_dir.z) * internal_bonus_speed * current_stats[StatusEffect.PlayerStatEnum.DASH_SPEED_MODIFIER]

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
	if GameManager.is_controller_connected:
		aim_assist(delta)


func update_ammo_counter_ui() -> void:
	stat_ui.radial_ui_center_node.update(current_gun.magazine_ammo_left, current_gun.modified_magazine_size)
	#stat_ui.radial_ui_center_node.max_radial_segment_count = current_gun.modified_magazine_size
	#stat_ui.radial_ui_center_node.active_radial_segment_count = current_gun.magazine_ammo_left


func full_reload_ammo_counter_ui() -> void:
	stat_ui.radial_ui_center_node.animate_full_reload(current_gun.current_reload_anim_time)


func show_barrel_effect_ui() -> void:
	if barrel_ui_active:
		return

	if current_gun.max_barrels == 0:
		return

	barrel_ui_active = true

	if barrel_ui_tween:
		if barrel_ui_tween.is_running():
			barrel_ui_tween.pause()

	barrel_ui_tween = get_tree().create_tween()
	barrel_ui_tween.tween_property(barrel_detail_dimmer, "color:a", 0.65, 0.1)
	for i in range(current_gun.max_barrels):
		var effect_ui_idx: int = i
		var effect_ui = barrel_detail_ui.effect_boxes[effect_ui_idx]
		if i < current_gun.barrel_container.get_child_count():
			barrel_ui_tween.chain().tween_property(effect_ui, "modulate:a", 1.0, 0.05)
	await barrel_ui_tween.finished

	Engine.time_scale = 0.1


func hide_barrel_effect_ui() -> void:
	if not barrel_ui_active:
		return

	if barrel_ui_tween:
		if barrel_ui_tween.is_running():
			barrel_ui_tween.pause()

	barrel_ui_tween = get_tree().create_tween()

	Engine.time_scale = 1.0

	barrel_ui_tween.tween_property(barrel_detail_dimmer, "color:a", 0.0, 0.1)
	for i in range(current_gun.max_barrels):
		var effect_ui_idx: int = i
		var effect_ui = barrel_detail_ui.effect_boxes[effect_ui_idx]
		if i < current_gun.barrel_container.get_child_count():
			barrel_ui_tween.parallel().tween_property(effect_ui, "modulate:a", 0.0, 0.1)
	barrel_ui_tween.tween_callback(func(): barrel_ui_active = false)
	await barrel_ui_tween.finished


func update_barrel_effect_ui() -> void:
	for i in range(current_gun.max_barrels):
		var effect_ui_idx: int = i
		var effect_ui = barrel_detail_ui.effect_boxes[effect_ui_idx]
		if i < current_gun.barrel_container.get_child_count():
			#effect_ui.modulate.a = 1.0
		#if current_gun.barrel_container.get_child_count() > 0:
			var barrel: SpinBarrel = current_gun.barrel_container.get_child(i)
			var _effect: BaseBarrelEffect = barrel.get_active_effect()
			
			if _effect.icon_id != -1:
				effect_ui.icon_rect.texture = load("res://assets/sprite/effect_icons/%s.png" % _effect.icon_id)
			else:
				effect_ui.icon_rect.texture = load("res://assets/sprite/effect_icons/tmp-barrel-icon.png")
			effect_ui.name_label.text = _effect.display_text_title
			effect_ui.desc_label.text = _effect.display_text_tag

			for container in effect_ui.positives_container.get_children():
				container.queue_free()
			for container in effect_ui.negatives_container.get_children():
				container.queue_free()

			for text in _effect.positive_desc:
				effect_ui.add_positive(text)
			for text in _effect.negative_desc:
				effect_ui.add_negative(text)

		else:
			effect_ui.modulate.a = 0.0
			effect_ui.name_label.text = ""
			effect_ui.desc_label.text = ""


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


func jump(local_multiplier = 1.0):
	if is_in_menu or controls_disabled:
		return

	vel_vertical = JUMP_FORCE * current_stats[StatusEffect.PlayerStatEnum.JUMP_HEIGHT] * local_multiplier

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
	if not current_gun.is_reloading and not current_gun.is_spinning:
		current_gun.spin_all_barrels()


func no_spin_reload() -> void:
	current_gun.reload()


func handle_controller_look(_delta):
	var look_x = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_y = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")

	if abs(look_x) > 0.01 or abs(look_y) > 0.01:
		var sensitivity = GameManager.mouse_sensitivity / CONTROLLER_SENSITIVITY_COEEFICIENT
		if aim_assist_target:
			var modifier = AIM_ASSIST_CAMERA_REDUCTION_COEFFICIENT * GameManager.aim_assist_strength
			sensitivity = sensitivity * (1 - modifier)
		rotate_player(look_x * sensitivity, look_y * sensitivity)


func _reset_camera_look() -> void:
	player_camera.rotation = Vector3.ZERO
	neck.rotation = Vector3.ZERO


func rotate_player(x: float, y: float):
	if controls_disabled:
		return
	rotate(Vector3(0, -1, 0), x * (GameManager.mouse_sensitivity / MOUSE_SENSITIVITY_COEEFICIENT))
	player_camera.rotate_x(-y * (GameManager.mouse_sensitivity / MOUSE_SENSITIVITY_COEEFICIENT))
	player_camera.rotation.y = 0
	player_camera.rotation.z = 0
	player_camera.rotation.x = clamp(player_camera.global_rotation.x, deg_to_rad(-89), deg_to_rad(89))


func camera_control(delta):
	if controls_disabled:
		return
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
		# Allows us to disable jumping
		if max_air_jump < 1:
			return
		jump()

func _on_grounded_state_physics_processing(_delta: float):
		if Input.is_action_pressed("crouch"):
			is_crouching = true
		else:
			if uncrouch_collision_check_count == 0 and is_crouching:
				is_crouching = false


func _on_airborne_state_input(event: InputEvent):
	if event.is_action_pressed("jump"):
		# Allows us to disable jumping
		if max_air_jump < 1:
			return
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
		InputHelper.rumble_large()
		SoundManager.play_sound(sfx_hurt.pick_random())
		if new_health > 0:
			state_chart.send_event("end_damage")
			if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.DOUBLE_DOWN):
				var buff_value = 0
				var buff_time = 0
				match int(GameManager.player_skill_dict[SkillItemUI.SkillIdEnum.DOUBLE_DOWN]):
					1:
						buff_value = 0.15
						buff_time = 2
					2:
						buff_value = 0.15
						buff_time = 3
					3:
						buff_value = 0.3
						buff_time = 3
					4:
						buff_value = 0.3
						buff_time = 5
				# Only need 1 to display duration
				GameManager.create_and_add_status_effect("Double Down (Min damage)", "double_down_min_buff",
					StatusEffect.PlayerStatEnum.MIN_DAMAGE_VARIANCE, buff_value, StatusEffect.ModifyType.FLAT, buff_time, false, true, double_down_icon)
				GameManager.create_and_add_status_effect("Double Down (Max damage)", "double_down_max_buff",
					StatusEffect.PlayerStatEnum.MAX_DAMAGE_VARIANCE, buff_value, StatusEffect.ModifyType.FLAT, buff_time)


func _on_died() -> void:
	state_chart.send_event("death")
	SoundManager.play_sound(sfx_dead.pick_random())


func fall_death() -> void:
	health_component.current_health = 0
	state_chart.send_event("death")
	SoundManager.play_sound(sfx_dead_falling.pick_random(), "SFX")


func _on_health_hurt_state_entered() -> void:
	LuckHandler.time_since_last_hurt = 0.0
	LuckHandler.last_hurt_mult = 0
	hurt_overlay.hurt()


func _on_health_dead_state_entered() -> void:
	controls_disabled = true
	hurt_overlay.dead()
	stat_ui.hide_all_ui()

func _on_health_dead_state_physics_processing(delta: float) -> void:
	neck.rotation.z = lerp(neck.rotation.z, deg_to_rad(-3.0), delta * 5)
	neck.position.y = lerp(neck.position.y, -1.0, delta * 5)

func add_status_effect(new_status: StatusEffect):
	# Check if already exist, then refresh it instead of add new
	for status in status_effect_list:
		if status.status_code == new_status.status_code:
			status.duration = max(status.duration, new_status.duration)
			status.value = new_status.value
			new_status_effect_added.emit(status)
			return
	status_effect_list.append(new_status)
	new_status_effect_added.emit(new_status)
	apply_status_effects()


func remove_status_effect(status: StatusEffect):
	status_effect_list.erase(status)
	status_effect_removed.emit(status)
	apply_status_effects()


func remove_status_effect_by_name(find_name: String):
	var found = null
	for status in status_effect_list:
		if status.status_code == find_name:
			found = status
			break
	if found:
		remove_status_effect(found)


func check_if_has_status_effect_by_name(find_name: String):
	var found = false
	for status in status_effect_list:
		if status.status_code == find_name:
			found = true
			break
	return found

func apply_status_effects():
	# Reset current stats to base stats.
	current_stats = base_stats.duplicate(true)

	# Temporary storage for stacking.
	var flat_modifiers = {}
	var percentage_modifiers = {}

	for status in status_effect_list:
		if not current_stats.has(status.modified_stat):
			continue
		if status.modify_type == StatusEffect.ModifyType.FLAT:
			flat_modifiers[status.modified_stat] = flat_modifiers.get(status.modified_stat, 0) + status.value
		elif status.modify_type == StatusEffect.ModifyType.PERCENTAGE:
			percentage_modifiers[status.modified_stat] = percentage_modifiers.get(status.modified_stat, 0) + status.value
		elif status.modify_type == StatusEffect.ModifyType.BOOL:
			if status.value == 1:
				current_stats[status.modified_stat] = true
			else:
				current_stats[status.modified_stat] = false

	# Apply flat bonuses.
	for stat in flat_modifiers.keys():
		current_stats[stat] += flat_modifiers[stat]

	# Apply percentage bonuses.
	for stat in percentage_modifiers.keys():
		current_stats[stat] = current_stats[stat] * (1 + (percentage_modifiers[stat] / 100.0))

	# Other
	health_component.received_dmg_multiplier = 1 - (current_stats[StatusEffect.PlayerStatEnum.DAMAGE_REDUCTION] / 100.0)
	if health_component.received_dmg_multiplier < 0:
		health_component.received_dmg_multiplier = 0
	health_component.is_invincible = current_stats[StatusEffect.PlayerStatEnum.IS_INVINVIBLE]


func aim_assist(delta: float):
	if aim_assist_ray.is_colliding():
		var dist = global_position.distance_to(aim_assist_ray.get_collision_point())
		if dist <= AIM_ASSIST_MAX_RANGE:
			aim_assist_target = aim_assist_ray.get_collider()
		else:
			aim_assist_target = null
	else:
		aim_assist_target = null

	if aim_assist_target != null:
		get_assist_rotation_velocity(delta)


func get_assist_rotation_velocity(delta: float):
	# Player aim already on boss, no need to rotate camera anymore
	# Essentially this make the player only auto-aim to the edge of enemy hitbox
	if aim_assist_ray_boss_check.is_colliding():
		return

	var cam = player_camera
	var aim_target_pos: Vector3 = aim_assist_target.global_position
	if aim_assist_target.get_node("Marker3D") != null:
		aim_target_pos = aim_assist_target.get_node("Marker3D").global_position

	# Direction to target (world space)
	var to_target = (aim_target_pos - cam.global_position).normalized()
	var cam_forward = - cam.global_transform.basis.z

	# Get yaw (left/right) angle difference
	var cam_yaw = atan2(cam_forward.x, cam_forward.z)
	var target_yaw = atan2(to_target.x, to_target.z)
	var yaw_diff = wrapf(target_yaw - cam_yaw, -PI, PI)

	# Get pitch (up/down) angle difference
	var cam_pitch = asin(cam_forward.y)
	var target_pitch = asin(to_target.y)
	var pitch_diff = target_pitch - cam_pitch

	# yaw = horizontal / pitch = vertical
	var yaw_velocity = yaw_diff * GameManager.aim_assist_strength * AIM_ASSIST_STRENGTH_COEFFICIENT
	var pitch_velocity = pitch_diff * GameManager.aim_assist_strength * AIM_ASSIST_STRENGTH_COEFFICIENT

	# Reduce pitch strength during weapon recoil
	if player_camera.check_if_has_recoil():
		pitch_velocity = pitch_velocity * 0.1

	rotate(Vector3(0, -1, 0), -yaw_velocity * delta)
	player_camera.rotate_x(pitch_velocity * delta)
	player_camera.rotation.y = 0
	player_camera.rotation.z = 0
	player_camera.rotation.x = clamp(player_camera.global_rotation.x, deg_to_rad(-89), deg_to_rad(89))


func get_barrel_sprite_screen_positions() -> Array[Vector2]:
	var sprite_positions: Array[Vector2] = []

	for sprite in gun.barrel_sprites:
		var pos_marker: Marker3D = sprite.get_node("Marker3D")
		var _pos: Vector2 = player_camera.camera.unproject_position(pos_marker.global_position)
		sprite_positions.append(_pos)

	return sprite_positions


func spin_barrels() -> void:
	if current_gun.installed_barrels.size() == 0 or current_gun.is_reloading or current_gun.is_spinning:
		return
	# Check if we have enough chips
	if GameManager.purchase_reroll():
		cash_in_luck()
		current_gun.spin_all_barrels()
		# Provide small health buff (?)
		var modified_reroll_heal_value = reroll_heal_value
		if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.HIGH_ROLLER):
			modified_reroll_heal_value += int(GameManager.HIGH_ROLLER_BONUS_HEAL_PER_REROLL_TIME) * GameManager.reroll_time
		health_component.heal(modified_reroll_heal_value)
		SoundManager.play_sound(sfx_purchase)

	# Spin with IOU skill
	elif GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.IOU):
		var hp_cost = 0
		match int(GameManager.player_skill_dict[SkillItemUI.SkillIdEnum.IOU]):
			1:
				hp_cost = 25
			2:
				hp_cost = 20
			3:
				hp_cost = 15
			4:
				hp_cost = 10
		if health_component.current_health > hp_cost and GameManager.reroll_time < GameManager.get_risk_limit_spin_amount():
			cash_in_luck()
			GameManager.reroll_time += 1
			current_gun.spin_all_barrels()
			health_component.damage(hp_cost)
			SoundManager.play_sound(sfx_purchase)
		else:
			SoundManager.play_sound(sfx_too_expensive)
	else:
		SoundManager.play_sound(sfx_too_expensive)


func cash_in_luck() -> void:
	LuckHandler.enabled = false
	luck_bar_ui.cash_in_luck()
	# Animate the luck bar draining
	luck_component.disable()
	var tween = get_tree().create_tween()
	tween.tween_property(
		luck_bar_ui.luck_bar, "value", 0, luck_redeem_time
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	tween.parallel().tween_property(
		luck_bar_ui.luck_gain_bar, "value", 0, luck_redeem_time
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)

	await tween.finished

	luck_component.enable()
	LuckHandler.enabled = true
	luck_component.current_luck = 0.0


func add_iframe_on_dash():
	var iframe_duration = current_stats[StatusEffect.PlayerStatEnum.DASH_IFRAME_DURATION]
	var iframe_dash_buff = StatusEffect.new()
	iframe_dash_buff.display_name = "Dodging"
	iframe_dash_buff.status_code = "iframe_on_dash"
	iframe_dash_buff.modified_stat = StatusEffect.PlayerStatEnum.IS_INVINVIBLE
	iframe_dash_buff.value = 1 # Doesnt matter
	iframe_dash_buff.modify_type = StatusEffect.ModifyType.BOOL
	iframe_dash_buff.duration = iframe_duration
	iframe_dash_buff.status_icon = dash_iframe_icon
	add_status_effect(iframe_dash_buff)


# Check buff from some non-high luck skills. Only do this once at scene start
func check_permanent_buffs():
	remove_status_effect_by_name("lucky_crit_buff")
	remove_status_effect_by_name("cheat_death_buff")
	if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.LUCKY_CRIT):
		GameManager.create_and_add_status_effect("Lucky Crit", "lucky_crit_buff",
		StatusEffect.PlayerStatEnum.CRITICAL_HIT_DAMAGE_MULTIPLIER, 0.5, StatusEffect.ModifyType.FLAT)
	# Only show this to let player know if they still have Cheat Death
	if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.CHEAT_DEATH) and not cheat_death_triggered:
		GameManager.create_and_add_status_effect("Cheat Death", "cheat_death_buff",
		StatusEffect.PlayerStatEnum.NONE, 0, StatusEffect.ModifyType.FLAT, StatusEffect.INFINITE_DURATION, false, true, cheat_death_icon)

func apply_drunk_status(duration: float) -> void:
	state_chart.send_event("add_status_drunk")
	drunk_timer.start(duration)


func _on_status_drunk_active_state_entered() -> void:
	drunk_ui.start_drunk()
	player_camera.target_drunk_intensity = 4.0

func _on_status_drunk_active_state_exited() -> void:
	drunk_ui.end_drunk()
	player_camera.target_drunk_intensity = 0.0
	drunk_timer.stop()

func _on_status_drunk_active_state_physics_processing(delta: float) -> void:
	# Don't move the player when they're standing still
	if raw_input_dir == Vector2.ZERO:
		return

	# Drunk movement drift
	drunk_drift_timer += delta
	if drunk_drift_timer >= drunk_movement_drift_change_interval:
		drunk_drift_timer = 0.0
		# Random unit vector with small magnitude
		drunk_target_drift_vector = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * drunk_movement_drift
	# Smoothly lerp toward the target
	drunk_drift_vector = drunk_drift_vector.lerp(drunk_target_drift_vector, delta * 5.0)
	# Add to input direction
	velocity = Vector3(drunk_drift_vector.x, 0, drunk_drift_vector.y)
	move_and_slide()

func _on_drunk_timer_timeout() -> void:
	state_chart.send_event("remove_status_drunk")


func _on_check_standing_collision_body_exited(_body: Node3D) -> void:
	uncrouch_collision_check_count -= 1

func _on_check_standing_collision_body_entered(_body: Node3D) -> void:
	uncrouch_collision_check_count += 1


func _enable_freecam() -> void:
	controls_disabled = true
	player_camera.camera.current = false
	gun_container.visible = false

	# Spawn freecam
	freecam = freecam_prefab.instantiate()
	get_parent().add_child(freecam)
	freecam.global_position = self.global_position
	freecam.global_rotation = neck.global_rotation
	freecam.camera.global_rotation = player_camera.global_rotation
	freecam.camera.current = true

	Engine.time_scale = 0.0


func _disable_freecam() -> void:
	controls_disabled = false
	gun_container.visible = true
	player_camera.camera.current = true

	freecam.queue_free()
	freecam = null

	Engine.time_scale = 1.0


func _enable_cutscene_cam() -> void:
	controls_disabled = true
	player_camera.camera.current = false
	gun_container.visible = false


func _disable_cutscene_cam(lerp_to_player_cam: bool = false) -> void:
	controls_disabled = false
	
	if lerp_to_player_cam:
		var active_camera: Camera3D = get_viewport().get_camera_3d()
		var camera_tween := get_tree().create_tween()
		camera_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CIRC)
		camera_tween.set_parallel(true)
		camera_tween.tween_property(
			active_camera,
			"global_rotation",
			player_camera.global_rotation,
			0.8
		)
		camera_tween.tween_property(
			active_camera,
			"global_position",
			self.global_position,
			0.8
		)
		await camera_tween.finished
	
	player_camera.camera.current = true
	gun_container.visible = true


func change_near_enemy_radius(new_radius: float) -> void:
	var coll_shape: CollisionShape3D = near_enemy_area.get_node("CollisionShape3D")
	coll_shape.shape.radius = new_radius


func _on_near_enemy_radius_body_entered(_body: Node3D) -> void:
	enemy_near_counter += 1

func _on_near_enemy_radius_body_exited(_body: Node3D) -> void:
	enemy_near_counter -= 1
