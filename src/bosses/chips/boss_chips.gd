extends BossCore
class_name BossChips

signal substack_attacks_finished
signal flood_chamber
signal drain_chamber
signal break_floor
signal leap_finished(head_segment: Node)

var prev_phase
@export var phase_2_health_percentage_trigger: float = 0.5

var last_attack: String

@export var explosion_scene: PackedScene

@export_group("Movement")
@export var DESIRED_DISTANCE: float = 10.0
@export var desired_distance: float = DESIRED_DISTANCE
@export_subgroup("Orbiting")
@export var angle_speed: float = 1.0 # radians/second
@export var orbit_angle: float = 0.0 # track this over time
@export var orbit_radius: float = 20.0

@export_group("Attacks")
@export_subgroup("Backspin Chip")
@export var rolling_chip_projectile: PackedScene
var active_rolling_chip: RollingChip
# SFX
@export_subgroup("Place Your Bets")
@export var jump_height: float = 9.0
@export var jump_time: float = 0.8
@export var jump_hang_time: float = 1.2
@export var drop_time: float = 0.3
@export var drop_damage: float = 20.0
@export var aoe_radius: float = 3.0
@export var aoe_wave_time: float = 0.4
@export var wave_material: ShaderMaterial
var aoe_markers: Array[Node]
@export_subgroup("Split Stacks")
@export var small_stack_prefab: PackedScene
@export var stack_spawn_time: float = 0.1
var spawned_sub_stacks: Array = []
var finished_sub_stacks: Array = []
var last_stack: ChipBossSubStack
@export_subgroup("Split Stack Rush")
@export var split_rush_range: float = 6.0
@export var split_rush_damage: float = 20.0
@export_group("Chiptopede")
@export var chiptopede_segment_prefab: PackedScene
var chiptopede_spawns: Array[Node] = []
var last_spawn: Node
var last_leap_end_pos: Vector3
@export_subgroup("Attributes")
@export var chiptopede_max_health: float = 8000
@export_subgroup("Chiptopede Leap")
@export var chiptopede_segments: int = 24
@export var segment_separation: float = 0.9
@export var leap_time: float = 3.4
var leap_distance: float
var leap_speed: float
@export var leap_damage: float = 15.0
var has_leap_impacted: bool = false
var leap_curve: Curve3D
var follow_nodes := []
var completed_nodes := []
var chiptopede_head_offset: float = 0.0
@export var leap_height: float = 16.0
@export var leap_out_ratio: float = 0.6667
@export var leap_in_ratio: float = 0.6667

#@onready var anim_player: AnimationPlayer = $AnimationPlayer
#@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer


func _ready() -> void:
	super()
	leap_finished.connect(_on_chiptopede_leap_impact)


#func _physics_process(delta: float) -> void:
	#pass


func activate() -> void:
	super()
	navigation_component.follow_target = false
	navigation_component.enable()
	state_chart.send_event("start_phase_3")


func select_attack_phase_1() -> void:
	var possible_phases = [
		"start_backspin_chip",
		"start_place_your_bets_attack",
		"start_split_stack_projectiles",
		"start_split_stack_charge",
		"start_split_stack_place_your_bets_attack",
	]
	if prev_phase:
		possible_phases.erase(prev_phase)
	# TODO - add random weighting
	var new_phase = possible_phases.pick_random()
	print(prev_phase, new_phase)
	prev_phase = new_phase
	state_chart.send_event(new_phase)


func select_attack_phase_3() -> void:
	state_chart.send_event("start_chiptopede_leap")


#### SUBSTACK METHODS
#
func spawn_stacks(stack_count: int, spawn_distance: float) -> Array:
	var spawned_stacks = []
	# Spawn small stacks from the center point of the big stack and space them out
	for i in range(stack_count):
		var small_stack_inst: CharacterBody3D = small_stack_prefab.instantiate()
		get_parent().add_child(small_stack_inst)
		small_stack_inst.global_transform = self.global_transform
		small_stack_inst.scale = Vector3(0, 1, 0)
		
		small_stack_inst.health_component.health_diff.connect(_small_stack_hurt)
		small_stack_inst.health_component.died.connect(_small_stack_dead.bind(small_stack_inst))
		small_stack_inst.state_chart.event_received.connect(_substack_on_event_received.bind(small_stack_inst))
		small_stack_inst.substack_charge_set.connect(_on_substack_charge_set)
		
		small_stack_inst.target = target
		small_stack_inst.group_size = stack_count
		small_stack_inst.group_idx = i
		
		spawned_stacks.append(small_stack_inst)
		
		var stack_spawn_tween: Tween = get_tree().create_tween()
		var spawn_pos: Vector3 = self.global_position + (self.global_transform.basis.z * spawn_distance).rotated(
			Vector3.UP, 2 * PI / stack_count * (i+1)
		)
		stack_spawn_tween.tween_property(small_stack_inst, "global_position", spawn_pos, stack_spawn_time)
		stack_spawn_tween.parallel().tween_property(small_stack_inst, "scale", Vector3.ONE, stack_spawn_time)
		
		await stack_spawn_tween.finished
	
	return spawned_stacks


func despawn_stacks() -> void:
	for stack in spawned_sub_stacks:
		var stack_spawn_tween: Tween = get_tree().create_tween()
		stack_spawn_tween.tween_property(stack, "global_position", self.global_position, stack_spawn_time)
		stack_spawn_tween.parallel().tween_property(stack, "scale", Vector3.ZERO, stack_spawn_time)
		
		await stack_spawn_tween.finished
		
		stack.queue_free()
	spawned_sub_stacks = []


func _substack_on_event_received(event: String, stack: ChipBossSubStack) -> void:
	if event == "end_recovery":
		_substack_finished(stack)


func _substack_finished(stack: ChipBossSubStack) -> void:
	finished_sub_stacks.append(stack)
	if finished_sub_stacks.size() == spawned_sub_stacks.size():
		last_stack = stack
		substack_attacks_finished.emit()
		finished_sub_stacks = []


func _small_stack_hurt(health_diff: float) -> void:
	health_component.damage(abs(health_diff))


func _small_stack_dead(stack: CharacterBody3D) -> void:
	_substack_finished(stack)


#### PHASE 1
#
func _on_phase_1_state_entered() -> void:
	current_phase = 1
	select_attack()


#### BACKSPIN CHIP
# Big stack fires a spinning chip that rolls back the way it came
func _on_backspin_chip_targeting_state_entered() -> void:
	debug_state_label.text = "Backspin Chip | Targeting"
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.8).timeout
	state_chart.send_event("start_spin")


func _on_backspin_chip_targeting_state_physics_processing(delta: float) -> void:
	pass


func _on_backspin_chip_forward_spin_state_entered() -> void:
	debug_state_label.text = "Backspin Chip | ForwardSpin"
	
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	
	# Instance a chip projectile
	var chip_inst: RollingChip = rolling_chip_projectile.instantiate()
	active_rolling_chip = chip_inst
	get_parent().add_child(chip_inst)
	chip_inst.global_transform = self.global_transform
	
	# Send it towards the player
	var forward_target: Vector3 = chip_inst.get_point_before_wall()
	chip_inst.roll_to_point(forward_target, 0.8)
	await chip_inst.spin_finished
	
	state_chart.send_event("reverse_spin")


func _on_backspin_chip_forward_spin_state_physics_processing(delta: float) -> void:
	pass # Replace with function body.


func _on_backspin_chip_back_spin_state_entered() -> void:
	debug_state_label.text = "Backspin Chip | BackwardSpin"
	
	# Send the chip rolling back to the stack
	active_rolling_chip.roll_to_point(self.global_position, 0.8)
	await active_rolling_chip.spin_finished
	
	state_chart.send_event("end_spin")


func _on_backspin_chip_back_spin_state_physics_processing(delta: float) -> void:
	pass # Replace with function body.


func _on_backspin_chip_recover_state_entered() -> void:
	debug_state_label.text = "Backspin Chip | Recovery"
	
	active_rolling_chip.queue_free()
	active_rolling_chip = null
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	select_attack()
	state_chart.send_event("end_recovery")


#### BIG STACK PLACE YOUR BETS AoE
# Flood the arena and raise some platforms, leap into the air, 
# and crash down on the platform the player is currently on
func _on_place_your_bets_jumping_state_entered() -> void:
	debug_state_label.text = "Place Your Bets | Jumping"
	
	vel_vertical = 0
	GRAVITY = 0
	
	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(self, "global_position", Vector3(0, jump_height, 0), jump_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	await jump_tween.finished
	await get_tree().create_timer(jump_hang_time).timeout
	
	state_chart.send_event("aoe_dive")


func _on_place_your_bets_crashing_state_entered() -> void:
	debug_state_label.text = "Place Your Bets | Crashing"
	
	aoe_markers = get_tree().get_nodes_in_group("boss_aoe_marker")
	var closest_targets = aoe_markers.duplicate()
	closest_targets.sort_custom(
		func(a, b):
			var a_dist: float = a.global_position.distance_to(target.global_position)
			var b_dist: float = b.global_position.distance_to(target.global_position)
			if a_dist < b_dist:
				return true
			return false
	)
	var target_pos: Vector3 = closest_targets.front().global_position
	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(self, "global_position", target_pos, drop_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await jump_tween.finished
	await spawn_aoe_wave(aoe_radius, drop_damage, aoe_wave_time)
	
	state_chart.send_event("drain_chamber")


#### GENERIC SPLITTING BEHAVIOUR
# Shared behaviour for splitting the big stack into multiple substacks,
# and reforming back into one big stack.
func _on_splitting_state_entered() -> void:
	# Hide the main boss body and disable collision
	sprite.visible = false
	debug_mesh.visible = false
	navigation_component.disable()
	# Disable player and projectile collisions
	self.collision_mask -= (pow(2, 2-1) + pow(2, 4-1))
	hurtbox.set_deferred("monitoring",  false)
	# TODO - prevent damage numbers showing up
	health_component.show_damage_text = false
	
	spawned_sub_stacks = await spawn_stacks(3, 2.5)
	
	state_chart.send_event("start_attack")


func _on_merging_state_entered() -> void:
	await despawn_stacks()
	
	sprite.visible = true
	#navigation_component.enable()
	debug_mesh.visible = true
	self.collision_mask += (pow(2, 2-1) + pow(2, 4-1))
	health_component.show_damage_text = true
	
	# TODO - add pushback if player is in big stack collider
	#
	
	state_chart.send_event("end_merge")


func _on_recover_state_entered() -> void:
	state_chart.send_event("attack_end")
	
	await get_tree().create_timer(attack_recovery_time).timeout
	
	state_chart.send_event("cooldown_end")
	state_chart.send_event("end_recovery")
	
	select_attack()


func trigger_substack_attack(attack_event: String) -> void:
	for stack in spawned_sub_stacks:
		stack.state_chart.send_event(attack_event)
	
	await substack_attacks_finished
	state_chart.send_event("finish_attack")


#### SPLIT STACK PROJECTILES
# Split into multiple smaller stacks, orbit the player, and fire projectiles
func _on_split_stack_projectiles_attacking_state_entered() -> void:
	trigger_substack_attack("start_small_projectile_attack")


#### SPLIT STACK CHARGE
# Split into multiple smaller stacks, orbit the player, and charge at them;
# reforming into the big stack in a big explosion
func _on_split_stack_charge_attacking_state_entered() -> void:
	trigger_substack_attack("start_split_rush_attack")


func _on_substack_charge_set(pos: Vector3) -> void:
	self.global_position = pos


#### SPLIT STACK AoE
# Flood the arena and raise some platforms, leap into the air, 
# split into several smaller stacks, and crash down on the platforms in sequence

func _on_split_stack_place_your_bets_crashing_state_entered() -> void:
	aoe_markers = get_tree().get_nodes_in_group("boss_aoe_marker")
	
	# Gets all substacks ready to drop
	trigger_substack_attack("start_place_your_bets_attack")
	
	# Triggers AoE drops in random order
	
	var closest_targets = aoe_markers.duplicate()
	
	# RANDOM ORDER
	#var shuffled_stacks = spawned_sub_stacks.duplicate()
	#var available_markers = range(aoe_markers.size())
	#shuffled_stacks.shuffle()
	#for i in range(shuffled_stacks.size()):
		#var stack = shuffled_stacks[i]
		#var wrapped_idx = wrapi(
			#i + randi_range(0, available_markers.size()), 
			#0, 
			#available_markers.size()
		#)
		#var new_target_idx = available_markers.pop_at(wrapped_idx)
	
	# CHASE PLAYER
	for i in range(spawned_sub_stacks.size()):
		var stack = spawned_sub_stacks[i]
		
		closest_targets.sort_custom(
		func(a, b):
			var a_dist: float = a.global_position.distance_to(target.global_position)
			var b_dist: float = b.global_position.distance_to(target.global_position)
			if a_dist < b_dist:
				return true
			return false
	)
		var target_marker: Marker3D = closest_targets.pop_front()
		var new_target_idx: int = aoe_markers.find(target_marker)
		
	# Dive implementation
		stack.marker_target_idx = new_target_idx
		stack.state_chart.send_event("start_dive")
		await stack.substack_dive_finished
		spawn_aoe_wave(aoe_radius, drop_damage / i, aoe_wave_time, stack.global_position)
	
	await substack_attacks_finished
	
	state_chart.send_event("drain_chamber")


func _on_split_stack_place_your_bets_merging_state_entered() -> void:
	self.global_position.y = 0
	_on_merging_state_entered()


#### ARENA CONTROL METHODS
func _on_flooding_state_entered() -> void:
	debug_state_label.text = "Place Your Bets | Flooding"
	navigation_component.disable()
	flood_chamber.emit()


func _on_draining_state_entered() -> void:
	debug_state_label.text = "Place Your Bets | Draining"
	GRAVITY = 14
	drain_chamber.emit()


# TODO - make generic
func spawn_aoe_wave(
	max_radius: float,
	damage: float = 10.0,
	spawned_wave_time: float = 1.0,
	area_pos: Vector3 = self.global_position,
	spawned_wave_height: float = 0.3,
	_telegraph: bool = false,
	callback: Callable = func(): pass
) -> void:
	# Generate a collider
	var area_collider := Area3D.new()
	var area_collider_shape := CollisionShape3D.new()
	var collider_shape := CylinderShape3D.new()
	collider_shape.radius = 0.01
	collider_shape.height = spawned_wave_height
	area_collider_shape.shape = collider_shape
	area_collider.add_child(area_collider_shape)
	area_collider.collision_layer = int(pow(2, 7))
	area_collider.collision_mask = int(pow(2, 2 - 1) + pow(2, 7 - 1)) # Player & Cover
	area_collider.monitoring = true
	
	get_tree().get_root().add_child(area_collider)
	
	area_collider.global_position = area_pos
	area_collider.body_entered.connect(_on_wave_collision.bind(damage))
	#area_collider.body_entered.connect(area_collider.queue_free.unbind(1))
	
	var debug_mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	
	spawned_area_objects.append([area_collider, debug_mesh_instance])
	
	# Generate a visual
	get_tree().get_root().add_child(debug_mesh_instance)
	
	debug_mesh_instance.mesh = mesh
	debug_mesh_instance.cast_shadow = false
	debug_mesh_instance.global_position = area_pos
	
	mesh.bottom_radius = 0.0
	mesh.top_radius = 0.0
	mesh.height = spawned_wave_height
	mesh.material = wave_material
	
	#if telegraph:
		#var telegraph_tween = get_tree().create_tween()
		#var mesh_color: Color = debug_mesh_instance.mesh.material.get("shader_parameter/color")
		#
		#telegraph_tween.tween_property(debug_mesh_instance, "mesh:bottom_radius", 6.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
		#telegraph_tween.parallel().tween_property(debug_mesh_instance, "mesh:top_radius", 6.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
		##telegraph_tween.parallel().tween_method(material_glow.bind(debug_mesh_instance.mesh.material, Color.RED), 0, 1, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
		#telegraph_tween.parallel().tween_callback(func(): state_chart.send_event("attack_telegraph")).set_delay(0)
		#telegraph_tween.chain().tween_property(debug_mesh_instance, "mesh:bottom_radius", 1.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		#telegraph_tween.parallel().tween_property(debug_mesh_instance, "mesh:top_radius", 1.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		##telegraph_tween.parallel().tween_method(material_glow.bind(debug_mesh_instance.mesh.material, mesh_color), 0, 1, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		#
		#await telegraph_tween.finished
	
	#state_chart.send_event("attack_start")
	
	# Animate the visual
	# TODO - SFX
	#sfx_player.stream = sfx_ground_pound.pick_random()
	#sfx_player.play()
	var tween = get_tree().create_tween()
	tween.tween_property(mesh, "bottom_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(mesh, "top_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(area_collider_shape.shape, "radius", max_radius, spawned_wave_time)
	tween.tween_callback(debug_mesh_instance.queue_free)
	tween.tween_callback(area_collider.queue_free)
	tween.tween_callback(callback)
	
	await tween.finished
	
	return


func _on_wave_collision(body: Node3D, aoe_damage: float) -> void:
	if body == target:
		body.health_component.damage(aoe_damage)


func _on_split_stack_charge_merging_state_entered() -> void:
	_on_merging_state_entered()
	
	# Create an explosion
	var explosion_inst = explosion_scene.instantiate()
	add_child(explosion_inst)
	explosion_inst.change_mesh_scale(4.0)
	
	# Create an AoE damage
	var area_collider := Area3D.new()
	var area_collider_shape := CollisionShape3D.new()
	var collider_shape := SphereShape3D.new()
	collider_shape.radius = split_rush_range
	area_collider_shape.shape = collider_shape
	area_collider.add_child(area_collider_shape)
	area_collider.collision_layer = int(pow(2, 7))
	area_collider.collision_mask = int(pow(2, 2 - 1)) # Player
	area_collider.monitoring = true
	
	get_tree().get_root().add_child(area_collider)
	
	area_collider.global_position = self.global_position
	area_collider.body_entered.connect(_on_wave_collision.bind(split_rush_damage))


## Phase 3 - Chiptopede

func _on_phase_3_state_entered() -> void:
	# Hide the main boss body and disable collision
	sprite.visible = false
	debug_mesh.visible = false
	navigation_component.disable()
	# Disable player and projectile collisions
	self.collision_mask -= (pow(2, 2-1) + pow(2, 4-1))
	hurtbox.set_deferred("monitoring",  false)
	# TODO - prevent damage numbers showing up
	health_component.show_damage_text = false
	
	# TODO - fakeout death
	#
	
	# Re-fill health bar, change name, and show
	health_component.max_health = chiptopede_max_health
	health_ui.init_health_ui(chiptopede_max_health)
	health_ui.boss_name = "Chiptopede"
	health_ui.show_ui()
	
	break_floor.emit()
	await get_tree().create_timer(0.5)
	state_chart.send_event("start_leap_attack")


# LEAP
func get_chiptopede_spawn() -> Vector3:
	var available_spawns = chiptopede_spawns.duplicate()
	if last_spawn:
		available_spawns.erase(last_spawn)
	# Pick a spawn location close to the last end position
	var sort_target: Vector3 = target.global_position
	var get_furthest: bool = true
	if last_leap_end_pos:
		sort_target = last_leap_end_pos
		get_furthest = false
	available_spawns.sort_custom(
		func(a, b):
			var a_dist: float = a.global_position.distance_to(sort_target)
			var b_dist: float = b.global_position.distance_to(sort_target)
			if get_furthest:
				if a_dist > b_dist:
					return true
				return false
			else:
				if a_dist < b_dist:
					return true
				return false
	)
	last_spawn = available_spawns.front()
	
	return last_spawn.global_position


func _on_chiptopede_leap_targeting_state_entered() -> void:
	# Move chiptopede to new spawn location
	self.global_position = get_chiptopede_spawn()
	# Get the player's current position as the target point
	var start_pos: Vector3 = self.global_position
	var goal_pos: Vector3 = target.global_position
	goal_pos.y = -19
	# Create a leaping path between these two points
	var path = Path3D.new()
	leap_curve = Curve3D.new()
	var mid_point: Vector3 = start_pos.lerp(goal_pos, 0.5) + Vector3(0, leap_height, 0)

	# Calculate bezier control points
	var out_0 = (mid_point - start_pos) * leap_out_ratio  # 0.6667
	var in_1 = (mid_point - goal_pos) * leap_in_ratio  # 0.6667
	leap_curve.add_point(start_pos, Vector3.ZERO, out_0)
	leap_curve.add_point(goal_pos, in_1, Vector3.ZERO)
	path.curve = leap_curve

	# Add the path to the scene
	var scene_root = get_tree().root.get_children()[8]
	scene_root.add_child(path)
	
	# For each segment of the chiptopede, create a path follow 
	# and offset it by the distance between each segment
	follow_nodes = []
	for segment in chiptopede_segments:
		var path_follow = PathFollow3D.new()
		path.add_child(path_follow)
		
		var new_segment: ChiptopedeSegment = chiptopede_segment_prefab.instantiate()
		path_follow.add_child(new_segment)
		new_segment.global_position = path_follow.global_position
		new_segment.health_component.health_diff.connect(_on_chiptopede_hurt)
		
		follow_nodes.append(path_follow)
	
	leap_distance = leap_curve.get_baked_length()
	leap_speed = leap_distance / leap_time
	has_leap_impacted = false
	
	state_chart.send_event("start_leap")


func _on_chiptopede_leap_leaping_state_entered() -> void:
	chiptopede_head_offset = 0.0
	completed_nodes = []


func _on_chiptopede_leapleaping_state_physics_processing(delta: float) -> void:
	if completed_nodes.size() == follow_nodes.size():
		state_chart.send_event("end_leap")
		return
	
	chiptopede_head_offset += leap_speed * delta
	for i in range(chiptopede_segments):
		var segment = follow_nodes[i]
		if not segment:
			continue
		
		var offset = chiptopede_head_offset - (i * segment_separation)
		segment.progress = clamp(offset, 0, leap_distance)
		
		if segment.progress_ratio == 1.0:
			# Only trigger AoE when first segment hits ground
			leap_finished.emit(segment)
			segment.queue_free()
			completed_nodes.append(i)


func _on_chiptopede_leap_leaping_state_exited() -> void:
	completed_nodes = []
	follow_nodes = []


func _on_chiptopede_leap_impact(segment: Node) -> void:
	if not has_leap_impacted:
		spawn_aoe_wave(8.0, leap_damage, 0.1, segment.global_position, 0.5)
		has_leap_impacted = true


func _on_chiptopede_hurt(health_diff: float) -> void:
	health_component.damage(abs(health_diff))


func _exit_tree() -> void:
	for node in follow_nodes:
		node.queue_free()
	follow_nodes = []
