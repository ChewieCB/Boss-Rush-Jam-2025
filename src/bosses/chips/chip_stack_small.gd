extends BossCore
class_name ChipBossSubStack

signal substack_charge_set(pos: Vector3)
signal substack_dive_finished(stack: ChipBossSubStack)
signal substack_idle(stack: ChipBossSubStack)

@export var spark_scene: PackedScene

@export_group("Movement")
#@export var MOVE_SPEED: float = 10.0
#@onready var move_speed: float = MOVE_SPEED:
	#set(value):
		#move_speed = value
		#navigation_component.current_speed = move_speed
@export var wave_amplitude: float = 7.0
@export var wave_frequency: float = 5.0
@export var time_elapsed: float = 0.0
@export var idle_radius := 1.5
var idle_time := 0.0
var center_pos: Vector3

@export_group("Attacks")
@export_subgroup("Small Blind Burst")
@export var chip_projectile: PackedScene
@export var chip_shots_per_burst: int = 4
@export var num_bursts: int = 1
@export var delay_between_burst: float = 0.6
# SFX
@export var sfx_shoot_telegraph: Array[AudioStream]
@export var sfx_shoot: Array[AudioStream]
#
@export_subgroup("Arc Wave Swipe")
@export var swipe_prefab: PackedScene
@export var num_swipes: int = 2
@export var delay_between_swipe: float = 0.4
@export var swipe_damage: float = 4.0
@export var swipe_range: float = 25.0
@export var swipe_radius: float = 8.0
@export var swipe_height_scale: float = 0.12
@export var swipe_speed: float = 15.0
@export var swipe_targeting_timeout: float = 2.0
@onready var swipe_targeting_timer: Timer = $MeleeTargetingTimer
var active_arc_projectiles: Array = []
# SFX
@export var sfx_swipe: Array[AudioStream]
#
@export_subgroup("Chargeback")
@export var chargeback_targeting_time: float = 1.8
@export var chargeback_damage: float = 6.0
var chargeback_leap_height: float = 8.0
var chargeback_return_pos: Vector3
# SFX
@export var sfx_charge_telegraph: Array[AudioStream]
@export var sfx_charge: Array[AudioStream]
#
@export var sfx_chip_shot: Array[AudioStream]
@export_subgroup("Split Rush")
@export var explosion_scene: PackedScene
@export var arena_radius: float = 19.5
@export var split_rush_targeting_time: float = 5.0
@export var charge_speed: float = 40.0
var charge_target_pos: Vector3
@onready var reform_charge_timer: Timer = $StateChart/Root/Phase/SplitRush/ReformChargeTimer
# SFX
@export var sfx_merge_telegraph: Array[AudioStream]
#
@export_subgroup("Place Your Bets")
@onready var aoe_markers: Array[Node]
@export var marker_target_idx: int
@export var jump_height: float = 9.0
@export var jump_time: float = 0.8
@export var jump_hang_time: float = 1.2
@export var drop_time: float = 0.3
# SFX
@export var sfx_jump: Array[AudioStream]
@export var sfx_slam: Array[AudioStream]
@export var sfx_dive_telegraph: Array[AudioStream]
#

@onready var face_sprite: Sprite3D = $Sprite3D/FaceSprite
@onready var projectile_marker_pivot: Node3D = $MarkerPivot
@onready var spark_spawn_marker_l: Marker3D = $MarkerPivot/SparkMarkerL
@onready var spark_spawn_marker_r: Marker3D = $MarkerPivot/SparkMarkerR
@onready var projectile_spawn_marker: Marker3D = $MarkerPivot/ProjectileSpawnMarker
@onready var sfx_player: AudioStreamPlayer3D = $StackSFXPlayer

var group_size: int = 1
var group_idx: int = 0

var nav_map_rid: RID
var nav_agent_rid: RID


func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)
	
	nav_map_rid = get_world_3d().get_navigation_map()
	nav_agent_rid = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_map(nav_agent_rid, nav_map_rid)
	
	debug_trajectory_mesh = MeshInstance3D.new()
	debug_trajectory_mesh.mesh = ImmediateMesh.new()
	get_tree().get_root().add_child.call_deferred(debug_trajectory_mesh)


func _physics_process(_delta: float) -> void:
	return


## MOVEMENT BEHAVIOURS
#
func orbit_target_in_group(delta: float) -> void:
	orbit_angle += angle_speed * delta
	# Modify the orbit angle based on how many enemies are orbiting in the group
	# so we have evenly spaced enemy orbits
	var angle_offset = (2 * PI) / group_size * (group_idx + 1)
	var current_angle = orbit_angle + angle_offset
	# offset in XZ-plane
	var offset_x = cos(current_angle) * desired_distance
	var offset_z = sin(current_angle) * desired_distance
	var orbit_pos = target.global_position + Vector3(offset_x, 0, offset_z)
	# Pathfind to orbit_pos
	navigation_component.set_nav_target_position(orbit_pos)


func melee_approach(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	time_elapsed += delta
	var chase_direction: Vector3 = self.global_position.direction_to(target.global_position)
	var perpendicular: Vector3 = chase_direction.rotated(Vector3.UP, PI / 2)
	var wave_offset = perpendicular * sin(time_elapsed * wave_frequency) * wave_amplitude
	#var desired_position = target.global_position + wave_offset
	#navigation_component.set_nav_target_position(desired_position)
	velocity += wave_offset
	move_and_slide()


func platform_idle(delta) -> void:
	idle_time += delta
	var offset_x: float = sin(idle_time * 1.7) * idle_radius
	var offset_y: float = cos(idle_time * 2.3) * idle_radius
	var target_pos: Vector3 = aoe_markers[marker_target_idx].global_position + \
		Vector3(offset_x, 0, offset_y)
	self.global_position = target_pos


func orbit_center_in_group(delta: float, is_evasive: bool = false) -> void:
	orbit_angle += angle_speed * delta
	# Modify the orbit angle based on how many enemies are orbiting in the group
	# so we have evenly spaced enemy orbits
	var angle_offset = (2 * PI) / group_size * (group_idx + 1)
	var current_angle = orbit_angle + angle_offset
	# offset in XZ-plane
	var offset_x = cos(current_angle) * arena_radius
	var offset_z = sin(current_angle) * arena_radius
	var orbit_pos = Vector3(offset_x, 0, offset_z)
	
	if is_evasive:
		var chase_direction: Vector3 = self.global_position.direction_to(target.global_position)
		var perpendicular: Vector3 = chase_direction.rotated(Vector3.UP, PI / 2)
		var wave_offset = perpendicular * sin(time_elapsed * wave_frequency) * wave_amplitude
		orbit_pos += wave_offset
	
	# Pathfind to orbit_pos
	navigation_component.set_nav_target_position(orbit_pos)

## MOVEMENT UTILS
#
func move_stack_to_pos(goal_pos: Vector3) -> void:
	sfx_player.stream = sfx_charge.pick_random()
	sfx_player.play()
	var tween = get_tree().create_tween()
	tween.tween_property(
		self, "global_position", goal_pos, 0.8
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	
	return

func return_split_stack_to_center() -> void:
	var goal_pos: Vector3 = center_pos
	if group_size > 1:
		goal_pos += Vector3(0, 0, 1.0).rotated(
			Vector3.UP,
			(2 * PI / group_size) * (group_idx - 1)
		)
	
	await move_stack_to_pos(goal_pos)
	
	return

# JUMPING
func split_stack_jump(goal_pos: Vector3, _height: float = jump_height, hover: bool = true) -> void:
	if group_size > 1:
		goal_pos += Vector3(0, 0, 1.0).rotated(
			Vector3.UP,
			(2 * PI / group_size) * (group_idx - 1)
		)
	
	anim_player.play("substack/jump_start")
	#
	sfx_player.stream = sfx_jump.pick_random()
	sfx_player.play()
	#
	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(
		self, "global_position", goal_pos, jump_time
	).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	await jump_tween.finished
	
	if hover:
		anim_player.play("substack/jump_apex")
		#
		sfx_player.stream = sfx_dive_telegraph.pick_random()
		sfx_player.play()
		#
		await get_tree().create_timer(jump_hang_time).timeout
	
	return

func split_stack_jump_to_center(height: float = jump_height, hover: bool = true) -> void:
	var goal_pos: Vector3 = center_pos
	goal_pos.y = jump_height
	if group_size > 1:
		goal_pos += Vector3(0, 0, 1.0).rotated(
			Vector3.UP,
			(2 * PI / group_size) * (group_idx - 1)
		)
	
	await split_stack_jump(goal_pos, height, hover)
	
	return

func split_stack_slam(target_pos: Vector3, time: float = drop_time) -> void:
	anim_player.play("substack/slam_start")
	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(
		self, "global_position", target_pos, time
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await jump_tween.finished
	
	return


##

func _on_attack_telegraph_state_entered() -> void:
	return


func _on_attack_telegraph_state_exited() -> void:
	return


## SMALL BLIND PROJECTILES

func _on_small_blind_targeting_state_entered() -> void:
	debug_state_label.text = "Small Blind Burst | Targeting"
	navigation_component.enable()
	
	anim_player.play("substack/idle")
	state_chart.send_event("start_moving")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.6).timeout
	state_chart.send_event("start_shooting")


func _on_small_blind_targeting_state_physics_processing(delta: float) -> void:
	orbit_target_in_group(delta)


func _on_small_blind_phase_2_targeting_state_entered() -> void:
	vel_vertical = 0
	GRAVITY = 0
	navigation_component.disable()
	
	# Pick a free platform far away from the player and move to it
	var target_marker: Marker3D = aoe_markers[marker_target_idx]
	
	self.collision_layer = 0
	await move_stack_to_pos(target_marker.global_position)
	self.collision_layer = 4
	
	anim_player.play("substack/idle")
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.6).timeout
	state_chart.send_event("start_shooting")


func _on_small_blind_phase_2_targeting_state_physics_processing(_delta: float) -> void:
	return
	#platform_idle(delta)


func _on_small_blind_shooting_state_entered() -> void:
	debug_state_label.text = "Small Blind Burst | Shooting"
	
	state_chart.send_event("start_targeting")
	navigation_component.disable()
	anim_player.play("substack/projectile_telegraph")
	#
	sfx_player.stream = sfx_shoot_telegraph.pick_random()
	sfx_player.play()
	#
	_telegraph_attack()
	
	for i in num_bursts:
		for j in chip_shots_per_burst:
			# HACK - break out of this loop if we've exited the state
			if not $StateChart/Root/Phase/SmallBlindProjectile.active and not $StateChart/Root/Phase/SmallBlindProjectilePhase2.active:
				return
			await get_tree().create_timer(delay_per_projectile).timeout
			# Animate shot
			face_sprite.visible = true
			var face_tween: Tween = get_tree().create_tween()
			face_tween.tween_property(face_sprite, "scale", Vector3(1.2, 1.2, 1.0), 0.2).set_ease(Tween.EASE_OUT)
			#
			sfx_player.stream = sfx_shoot.pick_random()
			sfx_player.play()
			#
			fire_projectile(chip_projectile, projectile_spawn_marker.global_position, sfx_chip_shot)
			face_tween.chain().tween_property(face_sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.1).set_ease(Tween.EASE_IN)
			face_tween.tween_callback(func(): face_sprite.visible = false)
			
		await get_tree().create_timer(delay_between_burst).timeout
	
	state_chart.send_event("stop_shooting")


func _on_small_blind_shooting_state_physics_processing(_delta: float) -> void:
	return
	#orbit_target_in_group(delta)


func _on_small_blind_recover_state_entered() -> void:
	debug_state_label.text = "Small Blind Burst | Recovering"
	_recover_state_entered()


func _recover_state_entered() -> void:
	anim_player.play("substack/RESET")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	#navigation_component.enable()
	
	state_chart.send_event("end_recovery")


## ARC SWIPE


func _on_arc_swipe_targeting_state_entered() -> void:
	debug_state_label.text = "Arc Wave Swipe | Targeting"
	state_chart.send_event("start_moving")


func _on_arc_swipe_targeting_state_physics_processing(delta: float) -> void:
	orbit_center_in_group(delta, true)


func _on_arc_swipe_phase_2_targeting_state_entered() -> void:
	debug_state_label.text = "Arc Wave Swipe | Targeting"
	vel_vertical = 0
	GRAVITY = 0
	navigation_component.disable()
	state_chart.send_event("start_targeting")
	state_chart.send_event("start_closing")


func _on_arc_swipe_phase_2_targeting_state_physics_processing(_delta: float) -> void:
	return
	#platform_idle(delta)


func _on_arc_swipe_closing_state_entered() -> void:
	debug_state_label.text = "Arc Wave Swipe | Closing"
	swipe_targeting_timer.start(swipe_targeting_timeout)
	state_chart.send_event("start_moving")


func _on_arc_swipe_closing_state_physics_processing(delta: float) -> void:
	if self.global_position.distance_to(target.global_position) <= swipe_range:
		swipe_targeting_timer.stop()
		state_chart.send_event("start_targeting")
		state_chart.send_event("attack_telegraph")
		
		var spark_marker: Marker3D = spark_spawn_marker_r if sprite.flip_h else spark_spawn_marker_l
		spark(spark_marker.global_position)
		anim_player.play("substack/slash_spark")
		
		await get_tree().create_timer(telegraph_time).timeout
		state_chart.send_event("attack_start")
		state_chart.send_event("start_swipe")
		return
	
	melee_approach(delta)


func _on_arc_swipe_phase_2_closing_state_entered() -> void:
	debug_state_label.text = "Arc Wave Swipe | Closing"
	# Pick a free platform close to the player and move to it
	var target_marker: Marker3D = aoe_markers[marker_target_idx]
	
	self.collision_layer = 0
	await move_stack_to_pos(target_marker.global_position)
	self.collision_layer = 4
	
	swipe_targeting_timer.start(swipe_targeting_timeout)


func _on_arc_swipe_phase_2_closing_state_physics_processing(_delta: float) -> void:
	# Trigger swipe
	if self.global_position.distance_to(target.global_position) <= swipe_range:
		swipe_targeting_timer.stop()
		state_chart.send_event("start_targeting")
		state_chart.send_event("attack_telegraph")
		
		await get_tree().create_timer(telegraph_time).timeout
		state_chart.send_event("attack_start")
		state_chart.send_event("start_swipe")
	
	return
	#platform_idle(delta)


func _on_arc_swipe_swiping_state_entered() -> void:
	debug_state_label.text = "Arc Wave Swipe | Swiping"
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_telegraph")
	
	var spark_marker: Marker3D = spark_spawn_marker_r if sprite.flip_h else spark_spawn_marker_l
	spark(spark_marker.global_position)
	anim_player.play("substack/slash_spark")
	
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	
	for i in num_swipes:
		if i % 2 == 0:
			anim_player.play("substack/slash_attack_proj")
			
			await anim_player.animation_finished
			await get_tree().create_timer(delay_between_swipe).timeout
			
			spark(spark_marker.global_position)
			anim_player.play("substack/slash_spark_offhand")
		else:
			anim_player.play("substack/slash_attack_proj_offhand")
			
			await anim_player.animation_finished
			await get_tree().create_timer(delay_between_swipe).timeout
			
			spark(spark_marker.global_position)
			anim_player.play("substack/slash_spark")
		sprite.flip_h = !sprite.flip_h
	
	sprite.flip_h = false
	state_chart.send_event("end_swipe")


func _spawn_arc_proj() -> void:
	sfx_player.stream = sfx_swipe.pick_random()
	sfx_player.play()
	#
	var arc_proj := fire_projectile(swipe_prefab, projectile_spawn_marker.global_position)
	arc_proj.rotation_degrees.z += randf_range(-10, 10)
	arc_proj.velocity = (
		arc_proj.get_arc_vector(target.global_position)
	)
	active_arc_projectiles.append(arc_proj)


func _on_arc_swipe_phase_2_swiping_state_entered(_delta: float) -> void:
	# Suppose to jitter around a bit but it was broken so Chewie bypassed it
	# platform_idle(delta)
	return

## SPLIT RUSH


func _on_split_rush_targeting_state_entered() -> void:
	debug_state_label.text = "Split Rush | Targeting"
	
	navigation_component.enable()
	
	state_chart.send_event("start_moving")
	state_chart.send_event("attack_buildup")
	reform_charge_timer.start(split_rush_targeting_time)
	await reform_charge_timer.timeout
	
	state_chart.send_event("attack_telegraph")
	#
	sfx_player.stream = sfx_charge_telegraph.pick_random()
	sfx_player.play()
	#
	var spark_marker: Marker3D = spark_spawn_marker_r if sprite.flip_h else spark_spawn_marker_l
	spark(spark_marker.global_position)
	anim_player.play("substack/slash_spark")

	await get_tree().create_timer(telegraph_time * 2).timeout
	
	# HACK - break out of this loop if we've exited the state
	if not $StateChart/Root/Phase/SplitRush.active:
		return
	
	charge_target_pos = target.global_position
	charge_target_pos.y = 0
	substack_charge_set.emit(charge_target_pos)
	
	state_chart.send_event("start_charge")


func _on_split_rush_targeting_state_physics_processing(delta: float) -> void:
	orbit_center_in_group(delta)


func _on_split_rush_charging_state_entered() -> void:
	debug_state_label.text = "Split Rush | Charging"
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_start")
	anim_player.play("substack/slash_attack")
	#
	sfx_player.stream = sfx_charge.pick_random()
	sfx_player.play()
	#
	navigation_component.disable()
	
	var charge_tween: Tween = get_tree().create_tween()
	var charge_time: float = self.global_position.distance_to(charge_target_pos) / charge_speed
	# Ignore collisions with player and other stacks
	self.collision_layer = 0
	self.collision_mask -= int(pow(2, 2 - 1))
	charge_tween.tween_property(self, "global_position", charge_target_pos, charge_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	#sfx_player.stream = sfx_charge.pick_random()
	#sfx_player.play()
	await charge_tween.finished
	state_chart.send_event("end_charge")


func merge_to_pos(pos: Vector3, time: float, destroy_on_merge: bool = true) -> void:
	#state_chart.send_event("end_attack")
	var tween: Tween = get_tree().create_tween()
	# Ignore collisions with player and other stacks
	self.collision_layer = 0
	self.collision_mask = 0
	#
	sfx_player.stream = sfx_merge_telegraph.pick_random()
	sfx_player.play()
	#
	tween.tween_property(self, "global_position", pos, time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	#sfx_player.stream = sfx_charge.pick_random()
	#sfx_player.play()
	await tween.finished
	
	if destroy_on_merge:
		self.queue_free()


func _on_split_rush_recover_state_entered() -> void:
	debug_state_label.text = "Split Rush | Recovering"
	desired_distance = DESIRED_DISTANCE
	health_component.died.emit()
	health_component.has_died = true
	state_chart.send_event("end_recovery")


func _on_place_your_bets_jumping_state_entered() -> void:
	vel_vertical = 0
	GRAVITY = 0
	
	anim_player.play("substack/jump_telegraph")
	await split_stack_jump_to_center()


func _on_place_your_bets_crashing_state_entered() -> void:
	await _telegraph_attack("Place Your Bets")
	self.collision_layer = 0
	var target_marker: Marker3D = aoe_markers[marker_target_idx]
	
	await split_stack_slam(target_marker.global_position)
	sfx_player.stream = sfx_slam.pick_random()
	sfx_player.play()
	anim_player.play("substack/slam_end")
	
	state_chart.send_event("end_dive")


func _on_place_your_bets_recover_state_entered() -> void:
	debug_state_label.text = "Place Your Bets | Recovering"
	GRAVITY = 14
	anim_player.play("substack/idle")
	substack_dive_finished.emit(self)
	await return_split_stack_to_center()
	self.collision_layer = 4
	state_chart.send_event("end_recovery")


func _on_died() -> void:
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
	state_chart.send_event("deactivate")
	return


func _on_melee_targeting_timer_timeout() -> void:
	state_chart.send_event("start_swipe")


func _on_charge_back_targeting_state_entered() -> void:
	debug_state_label.text = "Charge Back | Targeting"
	
	GRAVITY = 14
	navigation_component.enable()
	
	anim_player.play("substack/idle")
	state_chart.send_event("start_moving")


func _on_charge_back_targeting_state_physics_processing(delta: float) -> void:
	orbit_center_in_group(delta, true)


func _on_charge_back_charging_state_entered() -> void:
	debug_state_label.text = "Chargeback | Charging"
	
	chargeback_return_pos = self.global_position
	hurtbox.set_deferred("monitoring", true)
	
	var spark_marker: Marker3D = spark_spawn_marker_r if sprite.flip_h else spark_spawn_marker_l
	spark(spark_marker.global_position)
	anim_player.play("substack/slash_spark")
	
	#
	sfx_player.stream = sfx_charge_telegraph.pick_random()
	sfx_player.play()
	#
	await _telegraph_attack()
	
	# HACK - break out of this loop if we've exited the state
	if not $StateChart/Root/Phase/ChargeBack.active:
		return
	
	charge_target_pos = target.global_position
	charge_target_pos.y = 0
	substack_charge_set.emit(charge_target_pos)
	
	state_chart.send_event("attack_start")
	state_chart.send_event("start_targeting")
	navigation_component.disable()
	
	#
	sfx_player.stream = sfx_charge.pick_random()
	sfx_player.play()
	#
	anim_player.play("substack/slash_attack")
	var charge_tween: Tween = get_tree().create_tween()
	var charge_time: float = self.global_position.distance_to(charge_target_pos) / charge_speed
	charge_tween.tween_property(self, "global_position", charge_target_pos, charge_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	#sfx_player.stream = sfx_charge.pick_random()
	#sfx_player.play()
	await charge_tween.finished
	state_chart.send_event("end_charge")


func _on_charge_back_leaping_state_entered() -> void:
	hurtbox.set_deferred("monitoring", false)
	anim_player.play("substack/jump_telegraph")
	var jump_results = charge_back_jump(chargeback_return_pos)
	
	anim_player.play("substack/jump_start")
	#
	sfx_player.stream = sfx_jump.pick_random()
	sfx_player.play()
	#
	self.velocity = jump_results[0]
	var time_up = jump_results[1]
	var time_down = jump_results[2]
	
	await get_tree().create_timer(time_up).timeout
	
	await get_tree().create_timer(time_down).timeout

	anim_player.play("substack/slam_end")
	#
	sfx_player.stream = sfx_slam.pick_random()
	sfx_player.play()
	#
	await anim_player.animation_finished
	
	state_chart.send_event("end_leap")


func charge_back_jump(goal_pos: Vector3 = Vector3.ZERO, charge_jump_height: float = chargeback_leap_height, debug: bool = false) -> Array:
	var start_pos = self.global_position
	var highest_y = max(start_pos.y, goal_pos.y)
	var apex_y = highest_y + charge_jump_height
	
	var velocity_v: float = sqrt(
		2 * GRAVITY * (apex_y - start_pos.y)
	)
	
	# TODO - make time_up and time_down configurable so we can set a jump time
	var time_up: float = velocity_v / GRAVITY
	var time_down: float = sqrt(2.0 * (apex_y - goal_pos.y) / GRAVITY)
	var time: float = time_up + time_down
	
	var displacement_xz: Vector2 = Vector2(goal_pos.x, goal_pos.z) - Vector2(start_pos.x, start_pos.z)
	var horizontal_distance: float = displacement_xz.length()
	var velocity_h = horizontal_distance / time
	var horizontal_dir: Vector2 = displacement_xz.normalized()
	
	var initial_velocity := Vector3(
		horizontal_dir.x * velocity_h,
		velocity_v,
		horizontal_dir.y * velocity_h,
	)
	
	# Drawing
	if debug:
		var trajectory_points: Array = []
		
		for i in range(1, 151):
			var t = time * float(i) / float(151)
			var x = start_pos.x + initial_velocity.x * t
			var y = start_pos.y + initial_velocity.y * t - 0.5 * GRAVITY * t * t
			var z = start_pos.z + initial_velocity.z * t
			trajectory_points.append(Vector3(x, y, z))
		
		debug_trajectory_mesh.mesh.clear_surfaces()
		debug_trajectory_mesh.mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in trajectory_points:
			debug_trajectory_mesh.mesh.surface_set_color(Color.RED)
			debug_trajectory_mesh.mesh.surface_add_vertex(p)
		debug_trajectory_mesh.mesh.surface_end()
		
	return [initial_velocity, time_up, time_down]


func _on_charge_back_leaping_state_physics_processing(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()


func _on_charge_back_recover_state_physics_processing(delta: float) -> void:
	orbit_center_in_group(delta, true)


func _on_hurtbox_body_entered(body: Node3D) -> void:
	if body == target:
		body.health_component.damage(chargeback_damage)


func _on_aoe_merge_targeting_state_entered() -> void:
	debug_state_label.text = "Merge AoE | Targeting"
	
	vel_vertical = 0
	GRAVITY = 0
	navigation_component.disable()
	
	state_chart.send_event("start_merge")


func _on_aoe_merge_merging_state_entered() -> void:
	debug_state_label.text = "Merge AoE | Jumping"
	
	merge_to_pos(Vector3(0, 9.0, 0), 0.9, false)
	
	state_chart.send_event("end_merge")


func _on_aoe_merge_recover_state_entered() -> void:
	debug_state_label.text = "Merge AoE | Recovering"
	state_chart.send_event("end_recovery")


# TODO - make a global util method
func spark(spark_pos: Vector3) -> void:
	var spark_vfx = spark_scene.instantiate()
	scene_root.add_child(spark_vfx)
	spark_vfx.global_position = spark_pos


func _on_health_changed(new_health: float, prev_health: float) -> void:
	if not $StateChart/Root/Phase/SmallBlindProjectile.active or $StateChart/Root/Phase/SmallBlindProjectilePhase2.active:
		super (new_health, prev_health)
	else:
		if new_health < prev_health:
			state_chart.send_event("start_damage")
			hurt_sfx_player.stream = sfx_hit.pick_random()
			hurt_sfx_player.pitch_scale = randf_range(0.7, 1.2)
			hurt_sfx_player.play()


func _exit_tree() -> void:
	for proj in active_arc_projectiles:
		if is_instance_valid(proj):
			proj.queue_free()
	active_arc_projectiles = []
