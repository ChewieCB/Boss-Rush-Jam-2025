extends BossCore
class_name ChipBossSubStack

signal substack_charge_set(pos: Vector3)
signal substack_dive_finished(stack: ChipBossSubStack)

@export_group("Movement")
@export var DESIRED_DISTANCE: float = 20.0
@export var desired_distance: float = DESIRED_DISTANCE
#@export var MOVE_SPEED: float = 10.0
#@onready var move_speed: float = MOVE_SPEED:
	#set(value):
		#move_speed = value
		#navigation_component.current_speed = move_speed
@export var wave_amplitude: float = 7.0
@export var wave_frequency: float = 5.0
@export var time_elapsed: float = 0.0
@export_subgroup("Orbiting Movement")
@export var angle_speed: float = 1.0 # radians/second
@export var orbit_angle: float = 0.0 # track this over time
@export var orbit_radius: float = 40.0

@export_group("Attacks")
@export_subgroup("Small Blind Burst")
@export var chip_projectile: PackedScene
@export var chip_shots_per_burst: int = 4
@export var num_bursts: int = 1
@export var delay_between_burst: float = 0.6
# SFX
#
@export_subgroup("Arc Wave Swipe")
@export var swipe_prefab: PackedScene
@export var num_swipes: int = 2
@export var delay_between_swipe: float = 0.4
@export var swipe_damage: float = 4.0
@export var swipe_range: float = 10.0
@export var swipe_radius: float = 8.0
@export var swipe_height_scale: float = 0.12
@export var swipe_lifetime: float = 0.35
@export var swipe_targeting_timeout: float = 2.0
@onready var swipe_targeting_timer: Timer = $StateChart/Root/Phase/ArcWaveSwipe/MeleeTargetingTimer
# SFX
#
@export_subgroup("Chargeback")
@export var chargeback_targeting_time: float = 1.8
@export var chargeback_damage: float = 6.0
var chargeback_leap_height: float = 8.0
var chargeback_return_pos: Vector3

@export var sfx_chip_shot: Array[AudioStream]
@export_subgroup("Split Rush")
@export var explosion_scene: PackedScene
@export var arena_radius: float = 19.5
@export var split_rush_targeting_time: float = 5.0
@export var charge_speed: float = 40.0
var charge_target_pos: Vector3
@onready var reform_charge_timer: Timer = $StateChart/Root/Phase/SplitRush/ReformChargeTimer
# SFX
@export_subgroup("Place Your Bets")
@onready var aoe_markers: Array[Node] = get_tree().get_nodes_in_group("boss_aoe_marker")
@export var marker_target_idx: int

@onready var scene_root = get_parent().get_parent()

@onready var projectile_marker_pivot: Node3D = $MarkerPivot
@onready var projectile_spawn_marker: Marker3D = $MarkerPivot/Marker3D

var group_size: int = 1
var group_idx: int = 0

var nav_map_rid: RID
var nav_agent_rid: RID


func _ready() -> void:
	nav_map_rid = get_world_3d().get_navigation_map()
	nav_agent_rid = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_map(nav_agent_rid, nav_map_rid)
	
	debug_trajectory_mesh = MeshInstance3D.new()
	debug_trajectory_mesh.mesh = ImmediateMesh.new()
	get_tree().get_root().add_child.call_deferred(debug_trajectory_mesh)


#func _physics_process(delta: float) -> void:
	#orbit_target_in_group(delta)


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
	var desired_position = target.global_position + wave_offset
	navigation_component.set_nav_target_position(desired_position)
	move_and_slide()


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


## SMALL BLIND PROJECTILES

func _on_small_blind_targeting_state_entered() -> void:
	debug_state_label.text = "Small Blind Burst | Targeting"
	
	state_chart.send_event("start_moving")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.6).timeout
	state_chart.send_event("start_shooting")


func _on_small_blind_targeting_state_physics_processing(delta: float) -> void:
	orbit_target_in_group(delta)


func _on_small_blind_phase_2_targeting_state_entered() -> void:
	# Pick a free platform far away from the player and move to it
	var target_marker: Marker3D = aoe_markers[marker_target_idx]
	
	self.collision_layer = 0
	
	velocity.y += 8.0
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "global_position", Vector3(0, 2, -2), 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.chain().tween_property(self, "global_position",target_marker.global_position, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	self.collision_layer = 4
	
	_on_small_blind_targeting_state_entered()


func _on_small_blind_phase_2_targeting_state_physics_processing(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()


func _on_small_blind_shooting_state_entered() -> void:
	debug_state_label.text = "Small Blind Burst | Shooting"
	
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	
	for i in num_bursts:
		for j in chip_shots_per_burst:
			await get_tree().create_timer(delay_per_projectile).timeout
			fire_projectile(chip_projectile, projectile_spawn_marker.global_position, sfx_chip_shot)
		await get_tree().create_timer(delay_between_burst).timeout
	
	state_chart.send_event("stop_shooting")


func _on_small_blind_shooting_state_physics_processing(delta: float) -> void:
	orbit_target_in_group(delta)


func _on_small_blind_recover_state_entered() -> void:
	debug_state_label.text = "Small Blind Burst | Recovering"
	_recover_state_entered()


func _recover_state_entered() -> void:
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	state_chart.send_event("end_recovery")


## ARC SWIPE


func _on_arc_swipe_targeting_state_entered() -> void:
	debug_state_label.text = "Arc Wave Swipe | Targeting"
	state_chart.send_event("start_moving")


func _on_arc_swipe_targeting_state_physics_processing(delta: float) -> void:
	orbit_center_in_group(delta, true)


func _on_arc_swipe_closing_state_entered() -> void:
	debug_state_label.text = "Arc Wave Swipe | Closing"
	swipe_targeting_timer.start(swipe_targeting_timeout)
	state_chart.send_event("start_moving")


func _on_arc_swipe_closing_state_physics_processing(delta: float) -> void:
	if self.global_position.distance_to(target.global_position) <= swipe_range:
		swipe_targeting_timer.stop()
		state_chart.send_event("start_targeting")
		state_chart.send_event("attack_telegraph")
		await get_tree().create_timer(telegraph_time).timeout
		state_chart.send_event("attack_start")
		state_chart.send_event("start_swipe")
		return
	
	melee_approach(delta)


func _on_arc_swipe_swiping_state_entered() -> void:
	debug_state_label.text = "Arc Wave Swipe | Swiping"
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_telegraph")
	
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	
	for i in num_swipes:
		var swipe = swipe_prefab.instantiate()
		scene_root.add_child(swipe)
		
		swipe.global_transform = projectile_spawn_marker.global_transform
		swipe.look_at(target.global_position)
		# Rotate swipe to be ~45 degrees instead of horizontal
		swipe.global_rotation_degrees.z = -45 if randf() < 0.5 else -135
		swipe.global_rotation_degrees.z += randf_range(-15, 15)
		swipe.max_radius = swipe_radius
		swipe.mesh.scale.y = swipe_height_scale
		swipe.damage = swipe_damage
		swipe.wave_time = swipe_lifetime
		# animate swipe
		swipe.start_shockwave(true)
		
		await get_tree().create_timer(delay_between_swipe).timeout
	
	state_chart.send_event("end_swipe")


## SPLIT RUSH


func _on_split_rush_targeting_state_entered() -> void:
	debug_state_label.text = "Split Rush | Targeting"
	
	state_chart.send_event("start_moving")
	state_chart.send_event("attack_buildup")
	reform_charge_timer.start(split_rush_targeting_time)
	await reform_charge_timer.timeout
	
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time * 2).timeout
	
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
	navigation_component.disable()
	
	var charge_tween: Tween = get_tree().create_tween()
	var charge_time: float = self.global_position.distance_to(charge_target_pos) / charge_speed
	# Ignore collisions with player and other stacks
	self.collision_layer = 0
	self.collision_mask -= pow(2, 2-1)
	charge_tween.tween_property(self, "global_position", charge_target_pos, charge_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	#sfx_player.stream = sfx_charge.pick_random()
	#sfx_player.play()
	await charge_tween.finished
	state_chart.send_event("end_charge")


func merge_to_pos(pos: Vector3, time: float) -> void:
	state_chart.send_event("end_attack")
	var tween: Tween = get_tree().create_tween()
	# Ignore collisions with player and other stacks
	self.collision_layer = 0
	self.collision_mask = 0
	tween.tween_property(self, "global_position", pos, time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	#sfx_player.stream = sfx_charge.pick_random()
	#sfx_player.play()
	await tween.finished
	self.queue_free()


func _on_split_rush_recover_state_entered() -> void:
	debug_state_label.text = "Split Rush | Recovering"
	desired_distance = DESIRED_DISTANCE
	health_component.died.emit()
	health_component.has_died = true
	state_chart.send_event("end_recovery")


func _on_place_your_bets_targeting_state_entered() -> void:
	debug_state_label.text = "Place Your Bets | Targeting"
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	
	# Await an external signal so we can send the stacks down in any order


func _on_place_your_bets_crashing_state_entered() -> void:
	debug_state_label.text = "Place Your Bets | Crashing"
	
	vel_vertical = 0
	GRAVITY = 0
	
	# TODO - fix the telegraph timing
	#state_chart.send_event("attack_telegraph")
	#await get_tree().create_timer(telegraph_time * 2).timeout
	state_chart.send_event("start_dive")
	
	var target_marker: Marker3D = aoe_markers[marker_target_idx]
	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(self, "global_position",target_marker.global_position, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await jump_tween.finished
	
	state_chart.send_event("end_dive")


func _on_place_your_bets_recover_state_entered() -> void:
	debug_state_label.text = "Place Your Bets | Recovering"
	GRAVITY = 14
	substack_dive_finished.emit(self)
	state_chart.send_event("end_recovery")


func _on_died() -> void:
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
	state_chart.send_event("deactivate")
	return


func _on_melee_targeting_timer_timeout() -> void:
	state_chart.send_event("start_attack")


func _on_charge_back_targeting_state_entered() -> void:
	debug_state_label.text = "Charge Back | Targeting"
	
	GRAVITY = 14
	
	state_chart.send_event("start_moving")


func _on_charge_back_targeting_state_physics_processing(delta: float) -> void:
	orbit_center_in_group(delta, true)


func _on_charge_back_charging_state_entered() -> void:
	debug_state_label.text = "Chargeback | Charging"
	
	chargeback_return_pos = self.global_position
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("start_targeting")
	
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(chargeback_targeting_time).timeout
	
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time * 2).timeout
	
	charge_target_pos = target.global_position
	charge_target_pos.y = 0
	substack_charge_set.emit(charge_target_pos)
	
	state_chart.send_event("attack_start")
	navigation_component.disable()
	
	var charge_tween: Tween = get_tree().create_tween()
	var charge_time: float = self.global_position.distance_to(charge_target_pos) / charge_speed
	charge_tween.tween_property(self, "global_position", charge_target_pos, charge_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	#sfx_player.stream = sfx_charge.pick_random()
	#sfx_player.play()
	await charge_tween.finished
	state_chart.send_event("end_charge")


func _on_charge_back_leaping_state_entered() -> void:
	hurtbox.set_deferred("monitoring", false)
	var jump_results = charge_back_jump(chargeback_return_pos)
	self.velocity = jump_results[0]
	
	await get_tree().create_timer(jump_results[1]).timeout
	
	state_chart.send_event("end_leap")


func charge_back_jump(goal_pos: Vector3 = Vector3.ZERO, jump_height: float = chargeback_leap_height, debug: bool = false) -> Array:
	var start_pos = self.global_position
	var highest_y = max(start_pos.y, goal_pos.y)
	var apex_y = highest_y + jump_height
	
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
		
	return [initial_velocity, time]


func _on_charge_back_leaping_state_physics_processing(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()


func _on_hurtbox_body_entered(body: Node3D) -> void:
	if body == target:
		body.health_component.damage(chargeback_damage)



func _on_aoe_merge_targeting_state_entered() -> void:
	debug_state_label.text = "Merge AoE | Targeting"
	
	vel_vertical = 0
	GRAVITY = 0
	
	state_chart.send_event("start_merge")


func _on_aoe_merge_merging_state_entered() -> void:
	debug_state_label.text = "Merge AoE | Jumping"
	
	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(self, "global_position", Vector3(0, 9.0, 0), 0.9).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	await jump_tween.finished
	
	state_chart.send_event("end_merge")


func _on_aoe_merge_recover_state_entered() -> void:
	debug_state_label.text = "Merge AoE | Recovering"
	desired_distance = DESIRED_DISTANCE
	health_component.died.emit()
	health_component.has_died = true
	state_chart.send_event("end_recovery")
