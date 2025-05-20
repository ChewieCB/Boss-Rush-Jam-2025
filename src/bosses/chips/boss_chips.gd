extends BossCore
class_name BossChips

signal substack_attack_finished
signal substack_all_attacks_finished
signal flood_chamber
signal drain_chamber
signal break_floor
signal chiptopede_emerges
signal leap_finished(head_segment: Node)

## Phase transitions
@export_group("Phases")
var prev_phase
@export var phase_2_health_percentage_trigger: float = 0.5

enum ChipBossForms {
	BIG_STACK,
	SPLIT_STACKS,
	CHIPTOPEDE
}
var current_form: ChipBossForms
var prev_form: ChipBossForms

## Movement attributes
@export_group("Movement")
@export var DESIRED_DISTANCE: float = 10.0
@export var desired_distance: float = DESIRED_DISTANCE
@export_subgroup("Jumping")
var aoe_markers: Array[Node]
var center_pos := Vector3(0, 0, -2)
@export var slam_aoe_decal: CompressedTexture2D
@export_subgroup("Orbiting")
@export var angle_speed: float = 1.0 # radians/second
@export var orbit_angle: float = 0.0 # track this over time
@export var orbit_radius: float = 20.0

## Attacks
@export_group("Attacks | General")
@export var explosion_scene: PackedScene
@export var pushback_force: float = 20.0
# SFX
@export var sfx_jump: Array[AudioStream]
#
@export_subgroup("Form Transitions")
@export var max_big_attacks: int = 3
var big_attacks_performed: int = 0
@export var max_small_attacks: int = 2
var small_attacks_performed: int = 0
# SFX
@export var sfx_stack_split: Array[AudioStream]
@export var sfx_stack_merge: Array[AudioStream]
@export var sfx_chiptopede_awaken: AudioStream
#
## BIG STACK
@export_group("Attacks | Big Stack")
@export_subgroup("Backspin Chip")
@export var rolling_chip_projectile: PackedScene
@export var chips_per_attack: int = 2
var chips_fired: int = 0
var active_rolling_chip: RollingChip
# SFX
@export var sfx_chip_fire: Array[AudioStream]
#
@export_subgroup("Chip Sweep")
@export var chip_sweep_count: int = 3
@export var sweep_time: float = 0.05
@export var sweep_delay: float = 0.4
@export var chip_sweep_prefab: PackedScene
var chip_sweep_instances: Array = []
# SFX
@export var sfx_chip_sweep_out: Array[AudioStream]
#
@export_subgroup("Stack Slam")
@export var slam_shockwave_prefab: PackedScene
@export var slam_count: int = 4
@export var slam_damage: float = 10.0
@export var slam_wave_speed: float = 2.1
@export var slam_wave_radius: float = 35.0
@export var slam_delay: float = 0.4
var completed_slams: int = 0
var aoe_floor = 0.0
# SFX
@export var sfx_slam: Array[AudioStream]
#
@export_subgroup("Place Your Bets")
@export var jump_height: float = 9.0
@export var jump_time: float = 0.8
@export var jump_hang_time: float = 1.2
@export var drop_time: float = 0.3
@export var drop_damage: float = 20.0
@export var aoe_radius: float = 3.0
@export var aoe_wave_time: float = 0.4
@export var wave_material: ShaderMaterial
## SMALL STACK
@export_group("Attacks | Small Stacks")
@export_subgroup("Split Stacks")
@export var small_stack_prefab: PackedScene
@export var stack_spawn_time: float = 0.1
var spawned_sub_stacks: Array = []
var finished_sub_stacks: Array = []
var last_stack: ChipBossSubStack
@export_subgroup("Split Stack Rush")
@export var split_rush_range: float = 3.5
@export var split_rush_damage: float = 20.0
# SFX
@export var sfx_stack_spawn: Array[AudioStream]
@export var sfx_stack_despawn: Array[AudioStream]
#
@export_subgroup("Split Stack AoE")
@export var split_aoe_dive_delay: float = 0.3
# SFX
#
@export_subgroup("Chip Mines")
@export var chip_mine_count: int = 8
@export var chip_mine_layers: int = 2
@export var chip_mine_spawn_area_radius: float = 9.0
@export var chip_mine_trigger_radius: float = 6.0
@export var chip_mine_trigger_time: float = 0.8
@export var chip_mine_prefab: PackedScene
@export var chip_mine_cooldown: float = 30.0
@onready var chip_mine_spawn_timer: Timer = $ChipMineSpawnTimer
var chip_mine_spawn_points: Array
var active_mines: Array = []
# SFX
#
## CHIPTOPEDE
@export_group("Attacks | Chiptopede")
@export var chiptopede_segment_prefab: PackedScene
var chiptopede_spawns: Array[Node]
var chiptopede_snake_spawns: Array[Node]
var chiptopede_snake_path_points: Array[Node]
@onready var chiptopede_snake_points: Array[Node] = chiptopede_snake_spawns + chiptopede_snake_path_points
var chiptopede_shoot_spawns: Array[Node]
var last_spawn: Node
var last_leap_end_pos := Vector3.ZERO
# Segment caching
var despawned_pos := Vector3(0, -50, 0)
var cached_segments: Array = []
var segment_cache_parent: Node3D
var persist_segements: bool = false
# SFX
@export var sfx_chiptopede_death: Array[AudioStream]
#
@export_subgroup("Attributes")
@export var chiptopede_max_health: float = 6000
@export var chiptopede_segments: int = 24
@export var segment_separation: float = 2.0
@export var min_spawn_distance: float = 36.0
@export var chiptopede_explosion_delay: float = 0.07
@export_subgroup("Leap")
@export var leap_aoe_radius: float = 12.0
@export var leap_damage: float = 15.0
@export var leap_damage_cooldown: float = 0.4
@export var leap_time: float = 3.4
@onready var leap_damage_timer: Timer = $StateChart/Root/Phase/Phase3/ChiptopedeLeap/LeapDamageTimer
# Leap curve attributes
@export var leap_height: float = 16.0
@export var leap_out_ratio: float = 0.6667
@export var leap_in_ratio: float = 0.6667
var leap_path: Path3D
var leap_distance: float
var leap_speed: float
var leap_curve: Curve3D
# Arrays to track segment
var follow_nodes := []
var completed_nodes := []
var chiptopede_head_offset: float = 0.0
# SFX
@export var sfx_chiptopede_leap: Array[AudioStream]
@export var sfx_chiptopede_impact: Array[AudioStream]
#
@export_subgroup("Snake")
@export var snake_speed: float = 25.0
@onready var astar := AStar3D.new()
var snake_path: PackedVector3Array
var snake_path_3d: Path3D
var snake_distance: float
# SFX
@export var sfx_chiptopede_snake: Array[AudioStream]
#
@export_subgroup("Spit Projectiles")
@export var shooting_stance_prefab: PackedScene
var stance_path: Path3D
var emerge_speed: float = 10.0
var emerge_distance: float
@export var max_projectile_spawn_distance: float = 36.0
@export var chiptopede_targeting_speed: float = 3.0
@export var chiptopede_projectile: PackedScene
@export var chiptopede_projectile_bursts: int = 2
@export var chiptopede_shots_per_burst: int = 20
@export var chiptopede_delay_per_projectile: float = 0.05
@export var delay_between_burst: float = 0.3
# SFX
@export var sfx_chiptopede_emerge: Array[AudioStream]
@export var sfx_chiptopede_shoot: Array[AudioStream]
@export var sfx_chiptopede_retreat: Array[AudioStream]
#

@onready var big_stack_sfx_player: AudioStreamPlayer3D = $BigStackSFXPlayer
@onready var chiptopede_sfx_player: AudioStreamPlayer3D = $ChiptopedeHeadSFXPlayer

## USEFUL GLOBALS
#@onready var anim_player: AnimationPlayer = $AnimationPlayer
#@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer


func _ready() -> void:
	if OS.is_debug_build():
		print("\n[Export Variable Debug] Checking for unset exports in ", self.name)
		var export_info = self.get_property_list()
		for prop in export_info:
			if "usage" in prop and (prop.usage & PROPERTY_USAGE_EDITOR) and prop.name != "script":
				var value = self.get(prop.name)
				if value == null or (value is Resource and not is_instance_valid(value)):
					print("!! Unset or invalid export: ", prop.name)
				else:
					print(prop.name, " → ", value)
	super()
	leap_finished.connect(_on_chiptopede_leap_impact)


func activate() -> void:
	print_debug("BossChips activate called")
	super()
	navigation_component.follow_target = false
	navigation_component.enable()
	if not self.is_node_ready():
		await self.ready
	match current_phase:
		1:
			state_chart.send_event("start_phase_1")
		2:
			state_chart.send_event("start_phase_2")
		3:
			state_chart.send_event("start_phase_3")


func _exit_tree() -> void:
	_cleanup_segment_arrays()


## HEALTH TRIGGERS

func _on_health_changed(new_health: float, prev_health: float) -> void:
	super(new_health, prev_health)
	if new_health < health_component.max_health * phase_2_health_percentage_trigger:
		if current_phase == 1:
			state_chart.send_event("start_phase_2")


func _on_health_dead_state_entered() -> void:
	# Before we trigger the death state, make sure we've merged back into the big stack
	_enable_gravity()
	_cleanup_backspin_chip()
	_on_chip_sweep_state_exited()
	#return_big_stack_to_center()
	merge_stacks()
	super()


func _on_died() -> void:
	if current_phase != 3:
		state_chart.send_event("stop_moving")
		state_chart.send_event("deactivate")
		_on_health_dead_state_entered()
		await death_anim_finished
		await boss_death_slow_mo()
		defeated.emit(self)
	else:
		persist_segements = true
		state_chart.send_event("stop_moving")
		state_chart.send_event("chiptopede_death")


## ATTACK CHOICES

func select_attack_phase_1() -> void:
	state_chart.send_event("end_attack")
	# Weighted random chance attacks
	# 
	var attack_str: String = ""
	var attack_roll: int = randi_range(0, 99)
	
	match current_form:
		ChipBossForms.BIG_STACK:
			# Transition between big and small forms:
			if big_attacks_performed >= max_big_attacks:
				big_stack_sfx_player.stream = sfx_stack_split.pick_random()
				big_stack_sfx_player.play()
				state_chart.send_event("change_form_split")
				return
			
			# TODO - move mines to phase 2? Or maybe launch mines and have small stacks move but not attack
			# If we haven't spawned mines in a while, spawn some
			#if chip_mine_spawn_timer.is_stopped():
				#attack_str = "start_chip_mines"
			#else:
			# Focus on backspin chip, occasional slams and sweeps
			# 45% chance of chip sweep
			# 60% chance of backspin chip
			# 40% chance of slam
			if attack_roll < 45:
				attack_str = "start_chip_sweep"
			elif attack_roll < 75:
				attack_str = "start_backspin_chip"
			else:
				attack_str = "start_slam_attack"
			
			big_attacks_performed += 1
		
		ChipBossForms.SPLIT_STACKS:
			# Transition between big and small forms:
			if small_attacks_performed >= max_small_attacks:
				state_chart.send_event("start_charge_reform")
				return
			else:
				# 30% chance of sequential charges
				# 70% chance of projectiles
				if attack_roll < 50:
					attack_str = "start_split_stack_charge_back_attack"
				#elif attack_roll < 50:
					#attack_str = "start_split_stack_arc_attack"  # Move arc attack to phase 2, short range projectile attack
				else:
					attack_str = "start_split_stack_projectiles"
			
			small_attacks_performed += 1
	# TODO
	
	state_chart.send_event(attack_str)


func select_attack_phase_2() -> void:
	state_chart.send_event("end_attack")
	# Weighted random chance attacks
	# 
	var attack_str: String = ""
	var attack_roll: int = randi_range(0, 99)
	
	match current_form:
		ChipBossForms.BIG_STACK:
			# Transition between big and small forms:
			if big_attacks_performed >= max_big_attacks:
				# TODO - split with attack
				#state_chart.send_event("change_form_split_aoe")
				big_stack_sfx_player.stream = sfx_stack_split.pick_random()
				big_stack_sfx_player.play()
				state_chart.send_event("change_form_split")
				return
			
			# TODO - move mines to phase 2? Or maybe launch mines and have small stacks move but not attack
			# If we haven't spawned mines in a while, spawn some
			#if chip_mine_spawn_timer.is_stopped():
				#attack_str = "start_chip_mines"
			#else:
			if attack_roll < 25:
				attack_str = "start_chip_sweep"
			elif attack_roll < 35:
				attack_str = "start_backspin_chip"
			elif attack_roll < 65:
				attack_str = "start_place_your_bets_attack"
			else:
				attack_str = "start_slam_attack"
			
			big_attacks_performed += 1
		
		ChipBossForms.SPLIT_STACKS:
			# Transition between big and small forms:
			if small_attacks_performed >= max_small_attacks:
				# FIXME - radial attack with reform
				#state_chart.send_event("change_form_big_aoe_merge")
				big_stack_sfx_player.stream = sfx_stack_merge.pick_random()
				big_stack_sfx_player.play()
				state_chart.send_event("change_form_big")
				return
			else:
				#if attack_roll < 20:
					## TODO - chip mines defensive attack
					#attack_str = "start_split_stack_ projectiles"
				if attack_roll < 45:
					attack_str = "start_split_stack_arc_attack"
				elif attack_roll < 65:
					attack_str = "start_split_stack_projectiles"
				else:
					attack_str = "start_split_stack_aoe_attack"
			
			small_attacks_performed += 1
	# TODO
	
	state_chart.send_event(attack_str)


func select_attack_phase_3() -> void:
	state_chart.send_event("end_attack")
	
	var possible_phases = [
		"start_leap_attack",
		"start_leap_attack",
		"start_snake_attack",
		"start_shoot_attack",
		"start_shoot_attack",
	]
	if prev_phase:
		possible_phases.erase(prev_phase)
	# TODO - add random weighting
	var new_phase = possible_phases.pick_random()
	print(prev_phase, " -> ", new_phase)
	prev_phase = new_phase
	state_chart.send_event(new_phase)


## UTIL FUNCTIONS

# For animation player triggering - do we actually need this?
func _play_sfx_from_array(sfx_array_name: String) -> void:
	var sfx_array: Array = self.get(sfx_array_name)
	if sfx_array:
		big_stack_sfx_player.stream = sfx_array.pick_random()
		big_stack_sfx_player.play()
	else:
		push_error("No such sfx array: %s" % sfx_array_name)

# BIG STACK MOVEMENT TWEENS
func return_big_stack_to_center() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(
		self, "global_position", center_pos, 0.8
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	
	return

func big_stack_jump(goal_pos: Vector3, height: float = jump_height, hover: bool = true) -> void:
	anim_player.play("big_stack/jump_start")
	big_stack_sfx_player.stream = sfx_jump.pick_random()
	big_stack_sfx_player.play()
	
	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(
		self, "global_position", goal_pos, jump_time
	).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	await jump_tween.finished
	anim_player.play("big_stack/jump_apex")
	
	if hover:
		await get_tree().create_timer(jump_hang_time).timeout
	
	return

func big_stack_jump_to_center(height: float = jump_height, hover: bool = true) -> void:
	var goal_pos: Vector3 = center_pos
	goal_pos.y = jump_height
	
	await big_stack_jump(goal_pos, height, hover)
	
	return

func big_stack_slam(target_pos: Vector3, time: float = drop_time) -> void:
	anim_player.play("big_stack/slam_start")
	
	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(
		self, "global_position", target_pos, time
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await jump_tween.finished
	
	anim_player.play("big_stack/slam_end")
	big_stack_sfx_player.stream = sfx_slam.pick_random()
	big_stack_sfx_player.play()
	
	var decal_slam := Decal.new()
	decal_slam.texture_albedo = slam_aoe_decal
	decal_slam.size = Vector3(6, 6, 6)
	scene_root.add_child(decal_slam)
	decal_slam.global_position = self.global_position
	decal_slam.global_position.y += 1
	
	var aoe_tween: Tween = get_tree().create_tween()
	aoe_tween.tween_property(decal_slam, "modulate:a", 0, 1.0).set_ease(Tween.EASE_IN)
	aoe_tween.tween_callback(decal_slam.queue_free)
	
	return

##
func show_big_stack() -> void:
	sprite.visible = true
	#debug_mesh.visible = true
	health_component.show_damage_text = true
	
	# Re-enable collision
	await get_tree().create_timer(0.1).timeout
	
	self.collision_layer = 4
	self.collision_mask = (pow(2, 1-1) + pow(2, 2-1) + pow(2, 4-1))
	
	return

func hide_big_stack() -> void:
	sprite.visible = false
	#debug_mesh.visible = false
	health_component.show_damage_text = false
	
	# Disable player and projectile collisions
	self.collision_layer = 0  # None
	self.collision_mask = 1  # World only
	hurtbox.set_deferred("monitoring",  false)

##
func _disable_gravity() -> void:
	vel_vertical = 0
	GRAVITY = 0

func _enable_gravity() -> void:
	GRAVITY = 14

##
func trigger_pushback(
	force: float = pushback_force, 
	pushback_source: Node3D = self, 
	pushback_radius: float = pushback_source.collider.shape.radius
) -> void:
	if target.global_position.distance_to(pushback_source.global_position) <= pushback_radius:
		var pushback_vector = pushback_source.global_position.direction_to(target.global_position)
		target.velocity = Vector3.ZERO
		target.vel_horizontal += Vector2(pushback_vector.x, pushback_vector.z) * force
		target.vel_vertical += 15.0


#### GENERIC SPLITTING/MERGING BEHAVIOUR
# Shared behaviour for splitting the big stack into multiple substacks,
# and reforming back into one big stack.
#
# Splitting
func split_stacks(spawn_func: Callable) -> void:
	hide_big_stack()
	await spawn_func.call()
	state_chart.send_event("end_attack")

func _spawn_stacks_close() -> void:
	spawned_sub_stacks = await spawn_stacks(3, 2.5)
	return

func _spawn_stacks_on_platforms() -> void:
	var far_platforms = aoe_markers.duplicate()
	far_platforms.sort_custom(
		_sort_by_distance_to_target.bind(false)
	)
	far_platforms = far_platforms.map(_map_marker_to_position)
	
	spawned_sub_stacks = await spawn_stacks(3, 0.0, far_platforms)
	return

# Merging
func merge_stacks() -> void:
	await despawn_stacks()
	trigger_pushback()
	await show_big_stack()
	
	# TODO - move this to the actual state trigger func
	state_chart.send_event("end_merge")


func _reset_to_split_stacks() -> void:
	current_form = ChipBossForms.SPLIT_STACKS
	big_attacks_performed = 0
	small_attacks_performed = 0

func _reset_to_big_stack() -> void:
	current_form = ChipBossForms.BIG_STACK
	big_attacks_performed = 0
	small_attacks_performed = 0


## Big/Split Form Transitions
func _on_split_stacks_state_entered_phase_1() -> void:
	_reset_to_split_stacks()
	await split_stacks(_spawn_stacks_close)
	select_attack()

func _on_split_stacks_state_entered_phase_2() -> void:
	# If we already have the Big Stack form before we call _reset_to_big_stack(),
	# this is the first transition from Phase1 -> Phase2 so do the AoE Merge
	if current_form == ChipBossForms.SPLIT_STACKS:
		await cancel_substack_attacks()
		state_chart.send_event("change_form_big_aoe_merge")
		return
	
	_reset_to_split_stacks()
	await split_stacks(_spawn_stacks_on_platforms)
	select_attack()


func _on_big_stack_state_entered_phase_1() -> void:
	_reset_to_big_stack()
	await return_big_stack_to_center()
	select_attack()

func _on_big_stack_state_entered_phase_2() -> void:
	# If we already have the Big Stack form before we call _reset_to_big_stack(),
	# this is the first transition from Phase1 -> Phase2 so do the AoE Merge
	if current_form == ChipBossForms.BIG_STACK:
		await big_stack_jump_to_center(jump_height, false)
		state_chart.send_event("start_merge_aoe_finisher")
		return
	
	_reset_to_big_stack()
	await big_stack_jump_to_center(jump_height, false)
	
	# TODO - make this area damage explosion a generic method we can re-use
	# Create an explosion
	var explosion_inst = explosion_scene.instantiate()
	add_child(explosion_inst)
	explosion_inst.change_mesh_scale(4.0)
	explosion_inst.global_position = self.global_position
	
	merge_stacks()
	
	state_chart.send_event("start_merge_aoe_finisher")


#### PHASE 1
# 
func _on_phase_1_state_entered() -> void:
	current_phase = 1


func _on_phase_1_state_exited() -> void:
	pass
	#return_big_stack_to_center()
	#await despawn_stacks(0.8)
	#show_big_stack()


### BIG STACK ATTACKS
#
## BACKSPIN CHIP
# Big stack fires a spinning chip that rolls back the way it came
func _on_backspin_chip_targeting_state_entered() -> void:
	_targeting_entered("start_spin", "Backspin Chip")


func _on_backspin_chip_forward_spin_state_entered() -> void:
	anim_player.play("big_stack/projectile_telegraph")
	await _telegraph_attack()
	anim_player.play("big_stack/projectile_fire")
	
	# Instance a chip projectile
	var chip_inst: RollingChip = rolling_chip_projectile.instantiate()
	active_rolling_chip = chip_inst
	scene_root.add_child(chip_inst)
	chip_inst.global_transform = self.global_transform
	
	# Send it towards the player
	big_stack_sfx_player.stream = sfx_chip_fire.pick_random()
	big_stack_sfx_player.play()
	var forward_target: Vector3 = chip_inst.get_point_before_wall()
	chip_inst.roll_to_point(forward_target, 0.8)
	
	await chip_inst.spin_finished
	
	state_chart.send_event("reverse_spin")


func _on_backspin_chip_back_spin_state_entered() -> void:
	debug_state_label.text = "Backspin Chip | BackwardSpin"
	
	# Send the chip rolling back to the stack
	active_rolling_chip.roll_to_point(self.global_position, 0.8)
	
	await active_rolling_chip.spin_finished
	
	state_chart.send_event("end_spin")


func _on_backspin_chip_recover_state_entered() -> void:
	debug_state_label.text = "Backspin Chip | Recovery"
	
	_cleanup_backspin_chip()
	chips_fired += 1
	anim_player.play("big_stack/projectile_telegraph")
	
	if chips_fired >= chips_per_attack:
		chips_fired = 0
		state_chart.send_event("attack_end")
		
		await get_tree().create_timer(attack_recovery_time).timeout
		
		state_chart.send_event("cooldown_end")
		anim_player.play("big_stack/idle")
		select_attack()
		state_chart.send_event("end_recovery")
	else:
		state_chart.send_event("start_targeting")
		state_chart.send_event("next_shot")


func _cleanup_backspin_chip() -> void:
	if is_instance_valid(active_rolling_chip):
		active_rolling_chip.queue_free()
		active_rolling_chip = null


func _on_backspin_chip_state_exited() -> void:
	# Cleanup chip projectile if we change phase mid-attack
	_cleanup_backspin_chip()


## Chip Sweep
#
func _on_chip_sweep_targeting_state_entered() -> void:
	_targeting_entered("start_sweep", "Chip Sweep")


func _on_chip_sweep_sweep_state_entered() -> void:
	debug_state_label.text = "Chip Sweep | Sweep"
	
	anim_player.play("big_stack/projectile_telegraph")
	await _telegraph_attack()
	
	for i in chip_sweep_count:
		# HACK - break out of this loop if we send an end_attack event
		if "end_attack" in state_chart._queued_events:
			return
		var sweep_proj: ChipSweepProjectile = chip_sweep_prefab.instantiate()
		scene_root.add_child(sweep_proj)
		sweep_proj.global_transform = self.global_transform
		chip_sweep_instances.append(sweep_proj)
		
		var chips_to_player: int = int(sweep_proj.global_position.distance_to(target.global_position))
		sweep_proj.anim_time = sweep_time / chips_to_player
		
		anim_player.play("big_stack/projectile_fire")
		# SFX
		big_stack_sfx_player.stream = sfx_chip_sweep_out.pick_random()
		big_stack_sfx_player.play()
		
		sweep_proj.add_chips(chips_to_player + 2)
		await sweep_proj.chips_placed
		# TODO - return sfx
		# SFX
		#big_stack_sfx_player.stream = sfx_chip_sweep_out.pick_random()
		#big_stack_sfx_player.play()
		
		sweep_proj.remove_chips()
		await sweep_proj.chips_removed
		anim_player.play("big_stack/projectile_telegraph")
		chip_sweep_instances.erase(sweep_proj)
		sweep_proj.queue_free()
		
		await get_tree().create_timer(sweep_delay).timeout
		
	anim_player.play("big_stack/idle")
	state_chart.send_event("end_sweep")


func _on_chip_sweep_state_exited() -> void:
	for inst in chip_sweep_instances:
		if is_instance_valid(inst):
			inst.queue_free()
	chip_sweep_instances = []


## Stack Slam
#
func _on_stack_slam_targeting_state_entered() -> void:
	await return_big_stack_to_center()
	_targeting_entered("start_jump", "Stack Slam")


func _on_stack_slam_jump_state_entered() -> void:
	debug_state_label.text = "Stack Slam | Jumping"
	_disable_gravity()
	
	anim_player.play("big_stack/jump_telegraph")
	
	await big_stack_jump_to_center(jump_height / 2, false)
	
	var target_pos: Vector3 = self.global_position
	target_pos.y = aoe_floor
	
	await big_stack_slam(target_pos, drop_time / 2)
	
	state_chart.send_event("spawn_wave")


func _on_stack_slam_slam_state_entered() -> void:
	var shockwave = slam_shockwave_prefab.instantiate()
	scene_root.add_child(shockwave)
	
	shockwave.global_transform = self.global_transform
	shockwave.global_position.y = aoe_floor
	shockwave.max_radius = slam_wave_radius
	shockwave.damage = slam_damage
	shockwave.wave_time = slam_wave_speed
	shockwave.start_shockwave()
	
	completed_slams += 1
		
	await get_tree().create_timer(slam_delay).timeout
	
	if completed_slams < slam_count:
		state_chart.send_event("start_jump")
	else:
		completed_slams = 0
		state_chart.send_event("end_slam")


### SMALL STACK ATTACKS
#
# SUBSTACK HELPER METHODS
# Since the small stacks are CharacterBody3D instances with their own state charts,
# we direct them here from the hidden big stack.
#
func trigger_substack_attack(attack_event: String, stack_delay: float = 0.0) -> void:
	for stack in spawned_sub_stacks:
		stack.state_chart.send_event(attack_event)
		if stack_delay:
			await get_tree().create_timer(stack_delay).timeout
	
	await substack_all_attacks_finished
	
	state_chart.send_event("finish_attack")


func cancel_substack_attacks() -> void:
	for stack in spawned_sub_stacks:
		stack.state_chart.send_event("end_attack")


func trigger_sequential_substack_attacks(activate_event: String, attack_event: String) -> void:
	for stack in spawned_sub_stacks:
		stack.state_chart.send_event(activate_event)
	for stack in spawned_sub_stacks:
		stack.state_chart.send_event(attack_event)
		await substack_attack_finished

	state_chart.send_event("finish_attack")


func _start_split_attack() -> void:
	state_chart.send_event("start_attack")


## SPLIT STACK PROJECTILES
# Split into multiple smaller stacks, orbit the player, and fire projectiles

func _on_ss_orbiting_projectiles_targeting_state_entered_phase_2() -> void:
	var furthest_targets = aoe_markers.duplicate()
	# Initial sort by furthest to player
	furthest_targets.sort_custom(
		_sort_by_distance_to_target.bind(false)
	)
	# Exclude the central platform
	furthest_targets = furthest_targets.filter(
		_filter_out_element_by_pos.bind(center_pos)
	)
	
	# CHASE PLAYER
	for i in range(spawned_sub_stacks.size()):
		var stack = spawned_sub_stacks[i]
		var target_marker: Marker3D = furthest_targets.pop_front()
		
		stack.marker_target_idx = aoe_markers.find(target_marker)
	
	_start_split_attack()

func _on_ss_orbiting_projectiles_attacking_state_entered() -> void:
	match current_phase:
		1:
			trigger_substack_attack("start_small_projectile_attack")
		2:
			trigger_substack_attack("start_small_projectile_attack_phase_2")

## SPLIT STACK SOLO CHARGE
#
func _on_ss_charge_solo_attacking_state_entered() -> void:
	trigger_sequential_substack_attacks("start_charge_back_attack", "start_charge")


#### SPLIT STACK CHARGE
# Split into multiple smaller stacks, orbit the player, and charge at them;
# reforming into the big stack in a big explosion
func _on_ss_charge_attacking_state_entered() -> void:
	trigger_substack_attack("start_split_rush_attack")

func _on_ss_charge_merging_state_entered() -> void:
	merge_stacks()
	
	big_stack_sfx_player.stream = sfx_stack_merge.pick_random()
	big_stack_sfx_player.play()
	
	# TODO - make this area damage explosion a generic method we can re-use
	#
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
	
	scene_root.add_child(area_collider)
	
	area_collider.global_position = self.global_position
	area_collider.body_entered.connect(_on_wave_collision.bind(split_rush_damage))
	
	await get_tree().create_timer(0.3).timeout
	
	area_collider.queue_free()

func _on_ss_charge_reform_recover_state_entered() -> void:
	state_chart.send_event("change_form_big")
	velocity = Vector3.ZERO
	#_recover_entered()


## Phase 2 - Flooded

func _on_phase_2_state_entered() -> void:
	flood_chamber.emit()
	current_phase = 2
	aoe_floor = 2.0
	big_attacks_performed = 0
	small_attacks_performed = 0
	
	# Update the center position to account for the platform
	center_pos.y = 2.0
	aoe_markers = get_tree().get_nodes_in_group("boss_aoe_marker")
	
	_cleanup_backspin_chip()
	_on_chip_sweep_state_exited()
	
	_disable_gravity()
	if current_form == ChipBossForms.SPLIT_STACKS:
		state_chart.send_event("phase_2_start_split_stacks")
		#state_chart.send_event("change_form_big_aoe_merge")
	else:
		state_chart.send_event("phase_2_start_big_stack")
		#await big_stack_jump_to_center()
		#state_chart.send_event("start_merge_aoe_finisher")
	#_reset_to_big_stack()
	# FIXME - radial attack with reform
	#state_chart.send_event("start_merge_aoe_finisher")


### AoE Merge Attack
# AOE Merge Attack
# Small stacks -> Big Stack | Big Stack slams down with radial wave AoE
#
# Small Stack merging
func _on_ss_merge_aoe_targeting_state_entered() -> void:
	state_chart.send_event("start_merge")

func _on_ss_merge_aoe_merging_state_entered() -> void:
	trigger_substack_attack("change_form_big_aoe")
	

func _on_ss_merge_aoe_recovering_state_entered() -> void:
	state_chart.send_event("attack_end")
	state_chart.send_event("change_form_big")
	state_chart.send_event("end_recovery")

#
# Small stack recovery triggers big stack slam
#
# Big Stack Slam down with radial wave
func _on_merge_aoe_targeting_state_entered() -> void:
	await big_stack_slam(center_pos, drop_time / 2)
	state_chart.send_event("start_slam")

func _on_merge_aoe_slam_state_entered() -> void:
	# Slam down and generate a radial wave AoE on impact
	var shockwave = slam_shockwave_prefab.instantiate()
	scene_root.add_child(shockwave)
	
	shockwave.global_transform = self.global_transform
	#shockwave.global_position.y += 0.4
	shockwave.max_radius = slam_wave_radius
	shockwave.arc_angle = 360
	shockwave.arc_thickness_ratio = 0.7
	shockwave.damage = slam_damage
	shockwave.wave_time = 1.4
	shockwave.start_shockwave()
	
	# Add pushback if player is in big stack collider
	trigger_pushback()
	
	await get_tree().create_timer(slam_delay).timeout
	
	_enable_gravity()
	
	state_chart.send_event("end_slam")

### BIG STACK
#
## PLACE YOUR BETS AoE
# Leap into the air and crash down on the 
# platform the player is currently on, temporarily destroying it
func _on_place_your_bets_targeting_state_entered() -> void:
	_targeting_entered("start_jump", "Place Your Bets")


func _on_place_your_bets_jumping_state_entered() -> void:
	debug_state_label.text = "Place Your Bets | Jumping"
	_disable_gravity()
	
	await big_stack_jump_to_center()
	# Disable collision to avoid clipping player into platform on slam
	self.collision_layer = 0  # None
	state_chart.send_event("aoe_dive")


func _on_place_your_bets_crashing_state_entered() -> void:
	debug_state_label.text = "Place Your Bets | Crashing"
	
	var closest_targets = aoe_markers.duplicate()
	closest_targets.sort_custom(
		_sort_by_distance_to_target.bind(true)
	)
	var target_pos: Vector3 = closest_targets.front().global_position
	
	await _telegraph_attack()
	await big_stack_slam(target_pos)
	await spawn_aoe_wave(aoe_radius, drop_damage, 0.1)
	# TODO - destroy platform
	#
	# Re-enable collision after pushback to avoid clipping
	self.collision_layer = 4  
	
	state_chart.send_event("end_aoe_attack")

### SPLIT STACKS
#
## Arc Projectile Attack
func _on_ss_arc_wave_targeting_state_entered() -> void:
	var closest_targets = aoe_markers.duplicate()
	
	# Initial sort by closest to player
	closest_targets.sort_custom(
		_sort_by_distance_to_target
	)
	# If the player is on the closest platform, exclude it
	var platform_near_player: Marker3D = closest_targets.front()
	if platform_near_player.global_position.distance_to(target.global_position) < 5.5:
		closest_targets = closest_targets.filter(
			_filter_out_element_by_pos.bind(platform_near_player.global_position)
		)
	
	for i in range(spawned_sub_stacks.size()):
		var stack = spawned_sub_stacks[i]
		var target_marker: Marker3D = closest_targets.pop_front()
		stack.marker_target_idx =  aoe_markers.find(target_marker)
	
	state_chart.send_event("start_attack")

func _on_ss_arc_wave_attacking_state_entered() -> void:
	trigger_substack_attack("start_arc_wave_attack_phase_2", 0.2)
	#trigger_sequential_substack_attacks("start_arc_wave_attack", "start_closing")


## Place Your Bets AoE
# Flood the arena and raise some platforms, leap into the air, 
# split into several smaller stacks, and crash down on the platforms in sequence
func _on_ss_place_your_bets_attacking_state_entered() -> void:
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
	
	for i in range(spawned_sub_stacks.size()):
		var stack = spawned_sub_stacks[i]
		
		closest_targets.sort_custom(
			_sort_by_distance_to_target
		)
		closest_targets = closest_targets.filter(_filter_out_element_by_pos.bind(center_pos))
		var target_marker: Marker3D = closest_targets.pop_front()
		var new_target_idx: int = aoe_markers.find(target_marker)
		
		# Dive implementation
		stack.marker_target_idx = new_target_idx
		
		stack.state_chart.send_event("start_dive")
		
		await stack.substack_dive_finished
		
		spawn_aoe_wave(
			aoe_radius, 
			drop_damage / spawned_sub_stacks.size(), 
			aoe_wave_time, 
			stack.global_position,
			stack
		)
		
		await get_tree().create_timer(split_aoe_dive_delay).timeout
	
	await substack_all_attacks_finished
	
	state_chart.send_event("finish_attack")


#### Phase 3 - Chiptopede

func _on_phase_3_state_entered() -> void:
	current_phase = 3
	
	await despawn_stacks()
	
	hide_big_stack()
	
	#
	self.global_position = despawned_pos
	_create_segment_cache()
	generate_snake_graph()
	
	# TODO - screen shake, particles, polish, etc.
	break_floor.emit()
	
	#await get_tree().create_timer(2.0).timeout
	await chiptopede_sfx_player.finished
	
	# Re-fill health bar, change name, and show
	health_component.has_died = false
	health_component.max_health = chiptopede_max_health
	health_component.current_health = chiptopede_max_health
	health_component.received_dmg_multiplier = 0.5
	health_ui.init_health_ui(chiptopede_max_health)
	health_ui.boss_name = "Chiptopede"
	health_ui.show_ui()
	
	# Have longer between chiptopede attacks
	attack_recovery_time *= 2
	await get_tree().create_timer(0.5)
	chiptopede_emerges.emit()
	state_chart.send_event("start_leap_attack")


## LEAP
#
func _on_chiptopede_leap_targeting_state_entered() -> void:
	# Move chiptopede to new spawn location
	self.global_position = get_chiptopede_spawn_pos(
		chiptopede_spawns, 
		min_spawn_distance,
		0.0,
		last_leap_end_pos
	).global_position
	
	# Get the player's current position as the target point
	var start_pos: Vector3 = self.global_position
	#print("Start pos dist to target: %s | Min spawn dist: %s" % [start_pos.distance_to(target.global_position), min_spawn_distance])
	var goal_pos: Vector3 = target.global_position
	goal_pos.y = -19
	leap_path = create_curve_path(start_pos, goal_pos, [], _create_leap_path)
	
	follow_nodes = spawn_segments(leap_path)
	
	leap_distance = leap_path.curve.get_baked_length()
	leap_speed = leap_distance / leap_time
	
	state_chart.send_event("start_leap")


func _on_chiptopede_leap_leaping_state_entered() -> void:
	chiptopede_head_offset = 0.0
	
	chiptopede_sfx_player.stream = sfx_chiptopede_leap.pick_random()
	chiptopede_sfx_player.play()


func _on_chiptopede_leapleaping_state_physics_processing(delta: float) -> void:
	move_segments_along_path(
		"end_leap", leap_speed, leap_distance, delta, leap_finished.emit
	)


func _on_chiptopede_leap_leaping_state_exited() -> void:
	if not persist_segements:
		_cleanup_segment_arrays()
		leap_path.queue_free()
	leap_damage_timer.stop()
	chiptopede_sfx_player.stop()
	chiptopede_sfx_player.stream = null


func _on_chiptopede_leap_impact(segment: Node) -> void:
	if leap_damage_timer.is_stopped():
		#
		chiptopede_sfx_player.stream = sfx_chiptopede_impact.pick_random()
		chiptopede_sfx_player.play()
		#
		spawn_aoe_bubble(leap_aoe_radius, leap_damage, segment.global_position, 0.4, segment)
		#spawn_aoe_wave(8.0, leap_damage, 0.1, segment.global_position, 0.5)
		# Create an explosion
		var explosion_inst = explosion_scene.instantiate()
		add_child(explosion_inst)
		explosion_inst.change_mesh_scale(8.0)
		explosion_inst.global_position = segment.global_position
		
		last_leap_end_pos = segment.global_position
		leap_damage_timer.start(leap_damage_cooldown)


## Snake
#
func _on_chiptopede_snake_targeting_state_entered() -> void:
	# Pick a spawn point
	var spawn: Node = get_chiptopede_spawn_pos(chiptopede_snake_spawns)
	var spawn_pos: Vector3 = spawn.global_position
	self.global_position = spawn_pos
	
	# Calculate a path for the snake to move along
	snake_path = []
	
	# FIXME - spawn -> target path
	#calculate_snake_path(self.global_position, target.global_position)
	
	# Get an end-point from another spawn
	var available_spawns = chiptopede_snake_spawns.duplicate()
	available_spawns.erase(spawn)
	available_spawns.sort_custom(
		func(a, b):
			var a_dist: float = a.global_position.distance_to(target.global_position)
			var b_dist: float = b.global_position.distance_to(target.global_position)
			if a_dist < b_dist:
				return true
			return false
	)
	var end_pos: Vector3 = available_spawns.front().global_position
	
	calculate_snake_path(spawn_pos, end_pos)
	
	# FIXME - target -> end path
	#calculate_snake_path(target.global_position, end_pos.global_position)
	
	# Create curve paths
	snake_path_3d = create_curve_path(
		spawn_pos,
		end_pos,
		snake_path,
		_create_snake_path
	)
	snake_distance = snake_path_3d.curve.get_baked_length()
	
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.8).timeout
	
	state_chart.send_event("start_snake")


func _on_chiptopede_snake_moving_state_entered() -> void:
	follow_nodes = spawn_segments(snake_path_3d)
	
	chiptopede_sfx_player.stream = sfx_chiptopede_leap.pick_random()
	chiptopede_sfx_player.play()


func _on_chiptopede_snake_moving_state_physics_processing(delta: float) -> void:
	move_segments_along_path(
		"end_snake", snake_speed, snake_distance, delta
	)


func _on_chiptopede_snake_moving_state_exited() -> void:
	if not persist_segements:
		_cleanup_segment_arrays()
		snake_path = []
		snake_path_3d.queue_free()
	chiptopede_sfx_player.stop()
	chiptopede_sfx_player.stream = null


## Projectile attack
#
func turn_towards_target(node: Node, speed: float, delta: float) -> void:
	var direction: Vector3 = node.global_position.direction_to(target.global_position)
	node.rotation.y = lerp_angle(
		node.rotation.y, atan2(
			direction.x, direction.z
		),
		delta * speed
	)


func _on_chiptopede_shoot_emerging_state_entered() -> void:
	# Move chiptopede to new spawn location
	self.global_position = get_chiptopede_spawn_pos(
		chiptopede_shoot_spawns, 
		24.0,
		max_projectile_spawn_distance,
	).global_position
	
	# Get the player's current position as the target point
	var spawn_pos: Vector3 = self.global_position
	spawn_pos.y = -21
	stance_path = create_premade_path(spawn_pos, shooting_stance_prefab)
	
	#
	chiptopede_sfx_player.stream = sfx_chiptopede_emerge.pick_random()
	chiptopede_sfx_player.play()
	#
	follow_nodes = spawn_segments(stance_path)
	
	emerge_distance = stance_path.curve.get_baked_length()


func _on_chiptopede_shoot_emerging_state_physics_processing(delta: float) -> void:
	turn_towards_target(stance_path, chiptopede_targeting_speed, delta)
	
	# Animate the chiptopede up it as it rears up
	move_segments_along_path(
		"end_emerge", emerge_speed, emerge_distance, delta,
		Callable(), false, false
	)


func _on_chiptopede_shoot_targeting_state_entered() -> void:
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.8).timeout
	state_chart.send_event("start_shooting")


func _on_chiptopede_shoot_targeting_state_physics_processing(delta: float) -> void:
	turn_towards_target(stance_path, chiptopede_targeting_speed, delta)


func _on_chiptopede_shoot_shooting_state_entered() -> void:
	state_chart.send_event("attack_start")
	
	for i in chiptopede_projectile_bursts:
		for j in chiptopede_shots_per_burst:
			await get_tree().create_timer(chiptopede_delay_per_projectile).timeout
			#
			chiptopede_sfx_player.stream = sfx_chiptopede_shoot.pick_random()
			chiptopede_sfx_player.play()
			#
			fire_projectile(chiptopede_projectile, follow_nodes[0].global_position)
		await get_tree().create_timer(delay_between_burst).timeout
	
	state_chart.send_event("stop_shooting")


func _on_chiptopede_shoot_shooting_state_physics_processing(delta: float) -> void:
	turn_towards_target(stance_path, chiptopede_targeting_speed, delta)


func _on_chiptopede_shoot_retreat_state_entered() -> void:
	completed_nodes = []
	#
	chiptopede_sfx_player.stream = sfx_chiptopede_retreat.pick_random()
	chiptopede_sfx_player.play()
	#


func _on_chiptopede_shoot_retreat_state_physics_processing(delta: float) -> void:
	move_segments_along_path(
		"end_retreat", emerge_speed, emerge_distance, delta,
		Callable(), true, true
	)


func _on_chiptopede_shoot_recovering_state_entered() -> void:
	if not persist_segements:
		_cleanup_segment_arrays()
		stance_path.queue_free()
	_recover_entered()


func _on_chiptopede_hurt(health_diff: float) -> void:
	if health_diff < 0:
		health_component.damage(abs(health_diff))


#### SPLIT STACK HELPER METHODS
func spawn_stacks(stack_count: int, spawn_distance: float, spawn_positions: Array = []) -> Array:
	var spawned_stacks = []
	# Spawn small stacks from the center point of the big stack and space them out
	for i in range(stack_count):
		big_stack_sfx_player.stream = sfx_stack_spawn.pick_random()
		big_stack_sfx_player.play()
		
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
		small_stack_inst.center_pos = center_pos
		small_stack_inst.aoe_markers = aoe_markers
		if current_phase == 2:
			small_stack_inst.navigation_component.disable()
		
		spawned_stacks.append(small_stack_inst)
		
		var stack_spawn_tween: Tween = get_tree().create_tween()
		var spawn_pos: Vector3 = self.global_position + (self.global_transform.basis.z * spawn_distance).rotated(
			Vector3.UP, 2 * PI / stack_count * (i+1)
		)
		
		# If we specify spawn positions, use them instead of distance
		if spawn_positions:
			spawn_pos = spawn_positions[i]
		
		stack_spawn_tween.tween_property(small_stack_inst, "global_position", spawn_pos, stack_spawn_time)
		stack_spawn_tween.parallel().tween_property(small_stack_inst, "scale", Vector3.ONE, stack_spawn_time)
		
		await stack_spawn_tween.finished
	
	return spawned_stacks


func despawn_stacks(despawn_time: float = stack_spawn_time) -> void:
	for stack in spawned_sub_stacks:
		big_stack_sfx_player.stream = sfx_stack_despawn.pick_random()
		big_stack_sfx_player.play()
		
		var stack_spawn_tween: Tween = get_tree().create_tween()
		stack_spawn_tween.tween_property(stack, "global_position", self.global_position, stack_spawn_time)
		stack_spawn_tween.parallel().tween_property(stack, "scale", Vector3.ZERO, stack_spawn_time)
		
		await stack_spawn_tween.finished
		
		stack.queue_free()
	spawned_sub_stacks = []


func _substack_on_event_received(event: String, stack: ChipBossSubStack) -> void:
	if event == "end_recovery":
		stack.state_chart.send_event("end_attack")
		_substack_finished(stack)

func _on_substack_charge_set(pos: Vector3) -> void:
	self.global_position = pos

func _substack_finished(stack: ChipBossSubStack) -> void:
	finished_sub_stacks.append(stack)
	substack_attack_finished.emit()
	if finished_sub_stacks.size() == spawned_sub_stacks.size():
		last_stack = stack
		substack_all_attacks_finished.emit()
		finished_sub_stacks = []

func _small_stack_hurt(health_diff: float) -> void:
	health_component.damage(abs(health_diff))

func _small_stack_dead(stack: CharacterBody3D) -> void:
	_substack_finished(stack)


#### CHIPTOPEDE HELPER METHODS
func get_chiptopede_spawn_pos(
	spawn_marker_group: Array[Node], 
	min_spawn_distance: float = 0.0,
	max_spawn_distance: float = 0.0,
	previous_pos: Vector3 = Vector3.ZERO,
	filter_func: Callable = Callable() 
) -> Node:
	# Don't spawn in the same place twice in a row
	var available_spawns = spawn_marker_group.duplicate()
	if last_spawn:
		available_spawns.erase(last_spawn)
	
	# By default, pick a spawn target furthest away from the player
	var sort_target: Vector3 = target.global_position
	var get_furthest: bool = true
	# If we provide a previous location, spawn near this location for continutity
	if previous_pos != Vector3.ZERO:
		sort_target = previous_pos
		get_furthest = false
	# 
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
	# If we have a minimum spawn distance, filter out any spawns within this distance 
	var filtered_spawns = available_spawns
	if min_spawn_distance:
		filtered_spawns = filtered_spawns.filter(
			func(spawn):
				return spawn.global_position.distance_to(sort_target) >= min_spawn_distance
		)
	if max_spawn_distance:
		filtered_spawns = filtered_spawns.filter(
			func(spawn):
				return spawn.global_position.distance_to(sort_target) <= max_spawn_distance
		)
	#
	if filter_func:
		filtered_spawns = filtered_spawns.filter(filter_func)
	
	## TODO - Make sure the spawn is somewhere the player is looking
	#var facing_spawns = filtered_spawns.filter(
		#func(spawn):
			## Check player is in view of arc
			#var in_view_angle: float = PI
			#var target_facing_dir: Vector3 = -target.global_transform.basis.z.normalized()
			#var to_spawn_dir: Vector3 = target.global_position.direction_to(spawn.global_position).normalized()
			#
			#var angle_threshold: float = cos(deg_to_rad(in_view_angle / 2))
			#var dot_product: float = target_facing_dir.dot(to_spawn_dir)
			#
			#return dot_product >= 0
	#)
	
	last_spawn = filtered_spawns.front()
	
	return last_spawn


func create_premade_path(start_pos: Vector3, prefab: PackedScene) -> Path3D:
	# Instance the shooting stance path
	var path: Path3D = prefab.instantiate()
	scene_root.add_child(path)
	path.global_position = start_pos
	
	return path


func create_curve_path(start_pos: Vector3, goal_pos: Vector3, follow_path: Array, curve_constructor: Callable) -> Path3D:
	var path := Path3D.new()
	var curve: Curve3D = curve_constructor.call(start_pos, goal_pos, follow_path)
	path.curve = curve

	# Add the path to the scene
	scene_root.add_child(path)
	
	return path


func _create_leap_path(start_pos: Vector3, goal_pos: Vector3, _follow_path: Array) -> Curve3D:
	var curve = Curve3D.new()
	var mid_point: Vector3 = start_pos.lerp(goal_pos, 0.5) + Vector3(0, leap_height, 0)

	# Calculate bezier control points
	var out_0 = (mid_point - start_pos) * leap_out_ratio  # 0.6667
	var in_1 = (mid_point - goal_pos) * leap_in_ratio  # 0.6667
	curve.add_point(start_pos, Vector3.ZERO, out_0)
	curve.add_point(goal_pos, in_1, Vector3.ZERO)
	
	return curve


func _create_snake_path(_start_pos: Vector3, _goal_pos: Vector3, follow_path: Array) -> Curve3D:
	var curve = Curve3D.new()
	
	for i in range(snake_path.size() - 1):
		var start_pos: Vector3 = snake_path[i]
		var goal_pos: Vector3 = snake_path[i + 1]
		var mid_point: Vector3 = start_pos.lerp(goal_pos, 0.5)

		# Calculate bezier control points
		var out_0 = (mid_point - start_pos) * 0.6667
		var in_1 = (mid_point - goal_pos) * 0.6667
		
		curve.add_point(start_pos, Vector3.ZERO, out_0)
		curve.add_point(goal_pos, in_1, Vector3.ZERO)
	
	return curve


func _cleanup_segment_arrays() -> void:
	for node in follow_nodes:
		if is_instance_valid(node):
			var segment = node.get_child(0)
			if segment:
				cache_segment(segment, node)
	follow_nodes = []
	completed_nodes = []
	chiptopede_head_offset = 0.0


func _create_segment_cache() -> Node3D:
	segment_cache_parent = Node3D.new()
	get_tree().root.get_children()[8].add_child(segment_cache_parent)
	segment_cache_parent.global_position = despawned_pos
	
	for idx in range(chiptopede_segments):
		var segment = chiptopede_segment_prefab.instantiate()
		segment.health_component.health_diff.connect(_on_chiptopede_hurt)
		cache_segment(segment)
	
	# Setup sfx player at head segment
	var chiptopede_head = segment_cache_parent.get_child(0)
	chiptopede_head.add_child(chiptopede_sfx_player)
	# Play awakening sound from below
	chiptopede_sfx_player.stream = sfx_chiptopede_awaken
	chiptopede_sfx_player.play()
	
	return segment_cache_parent


func cache_segment(segment: ChiptopedeSegment, segment_parent: Node3D = null) -> void:
	if segment_parent:
		segment_parent.remove_child(segment)
	segment_cache_parent.add_child(segment)
	segment.global_position = despawned_pos
	cached_segments.append(segment)


func get_segment_from_cache() -> ChiptopedeSegment:
	var segment: ChiptopedeSegment = cached_segments.pop_front()
	segment_cache_parent.remove_child(segment)
	
	return segment


func spawn_segments(path: Path3D) -> Array:
	# For each segment of the chiptopede, create a path follow 
	# and offset it by the distance between each segment
	var path_follow_nodes := []
	
	# DEBUG fallback, find the actual source of this
	if cached_segments.size() == 0:
		_cleanup_segment_arrays()
	
	for segment_idx in chiptopede_segments:
		var path_follow = PathFollow3D.new()
		path.add_child(path_follow)
		
		var new_segment: ChiptopedeSegment = get_segment_from_cache()
		# If there are segments in the cache, grab one
		#if segment_idx < cached_segments.size():
			#new_segment = get_segment_from_cache()
		## Otherwise, instantiate a new segment
		#else:
			#new_segment = chiptopede_segment_prefab.instantiate()
		
		# Moving segments
		path_follow.add_child(new_segment)
		new_segment.global_position = path_follow.global_position
		new_segment.visible = true
		
		path_follow_nodes.append(path_follow)
		
	return path_follow_nodes


func move_segments_along_path(
	end_event_str: String,speed: float, max_distance: float, delta: float,
	segment_callback: Callable = Callable(),
	is_reversed: bool = false, free_segment_when_finished: bool = true,
) -> void:
	if completed_nodes.size() == follow_nodes.size():
		#if free_segment_when_finished:
			#_cleanup_segment_arrays()
		state_chart.send_event(end_event_str)
		return
	
	var offset_diff: float = speed * delta
	if is_reversed:
		offset_diff *= -1
	chiptopede_head_offset += offset_diff
	
	for i in range(chiptopede_segments):
		var path_follow = follow_nodes[i]
		if not path_follow or path_follow.get_child_count() == 0:
			continue
		
		var offset = chiptopede_head_offset - (i * segment_separation)
		path_follow.progress = clamp(offset, 0, max_distance)
		
		var progress_endpoint: float = 0.0 if is_reversed else max_distance
		if path_follow.progress == progress_endpoint:
			# Only trigger AoE when first segment hits ground
			if segment_callback:
				segment_callback.call(path_follow)
			if free_segment_when_finished:
				var segment = path_follow.get_child(0)
				cache_segment(segment, path_follow)
			completed_nodes.append(i)


func generate_snake_graph() -> void:
	var all_points = chiptopede_snake_spawns + chiptopede_snake_path_points
	for i in range(all_points.size()):
		var point = all_points[i]
		astar.add_point(i, point.global_position)
		all_points.append(point)
	for point in all_points:
		var point_idx: int = all_points.find(point)
		for connection in point.connected_points:
			var connection_idx: int = all_points.find(connection)
			astar.connect_points(point_idx, connection_idx)


# FIXME - double-backing in places
func calculate_snake_path(start_pos: Vector3, target_pos: Vector3) -> void:
	snake_path += astar.get_point_path(
		astar.get_closest_point(start_pos),
		astar.get_closest_point(target_pos)
	)














#### CHIP MINES
# Jump up, crash into the ground creating an AoE and 
# make chip mines pop up out of the floor.
func _on_chip_mines_targeting_state_entered() -> void:
	debug_state_label.text = "Chip Mines | Targeting"
	
	# TODO - detonate any existing chip mines before we spawn new ones
	for mine in active_mines:
		if is_instance_valid(mine):
			mine.detonate()
	active_mines = []
	#
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.8).timeout
	state_chart.send_event("start_jump")


func _on_chip_mines_jump_state_entered() -> void:
	debug_state_label.text = "Chip Mines | Jumping"
	
	vel_vertical = 0
	GRAVITY = 0
	
	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(self, "global_position", Vector3(0, jump_height/2, -2), jump_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	await jump_tween.finished
	await get_tree().create_timer(jump_hang_time/3).timeout
	
	var target_pos: Vector3 = self.global_position
	target_pos.y = 0
	jump_tween = get_tree().create_tween()
	jump_tween.tween_property(self, "global_position", target_pos, drop_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await jump_tween.finished
	await spawn_aoe_wave(aoe_radius, drop_damage, aoe_wave_time)
	
	state_chart.send_event("start_spawn")


func _on_chip_mines_spawn_mines_state_entered() -> void:
	debug_state_label.text = "Chip Mines | Spawning Mines"
	# Animate each chip mine spawning out of floor
	for i in range(chip_mine_layers):
		for j in range(chip_mine_count / (chip_mine_layers - i)):
			var mine = chip_mine_prefab.instantiate()
			active_mines.append(mine)
			scene_root.add_child(mine)
			
			mine.global_position = self.global_position
			var mine_rot: float = (2 * PI / chip_mine_count) * j
			var mine_dist: float = chip_mine_spawn_area_radius * (i + 1)
			var goal_pos := self.global_position + Vector3.FORWARD.rotated(Vector3.UP, mine_rot) * mine_dist
			goal_pos.y += 1.4
			
			var tween = get_tree().create_tween()
			tween.tween_property(mine, "global_position", goal_pos, 0.25).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
			tween.tween_callback(mine.arm)
		
	chip_mine_spawn_timer.start(chip_mine_cooldown)
	state_chart.send_event("end_spawn")


func get_mine_spawn_position() -> Vector3:
	# Make sure we don't spawn too close to player/boss
	var valid_spawns = chip_mine_spawn_points.filter(
		func(point):
			for mine in active_mines:
				if point.distance_to(mine.global_position) < chip_mine_trigger_radius:
					return false
			
			var self_dist: float = point.distance_to(self.global_position)
			var target_dist: float = point.distance_to(target.global_position)
			
			return self_dist > chip_mine_trigger_radius \
			and target_dist > chip_mine_trigger_radius \
	)
	#if last_spawn:
		#valid_spawns.sort_custom(
			#func(a, b):
				#return a.distance_to(last_spawn) > b.distance_to(last_spawn)
		#)
		#last_spawn = valid_spawns.front()
	#else:
	
	return valid_spawns.pick_random()


## UTILITY FUNCTIONS

func _filter_out_element_by_pos(element: Node3D, exlude_pos: Vector3):
	return element.global_position != exlude_pos

func _sort_by_distance_to_target(a: Node3D, b: Node3D, sort_close: bool = true) -> bool:
	var a_dist: float = a.global_position.distance_to(target.global_position)
	var b_dist: float = b.global_position.distance_to(target.global_position)
	
	if a_dist > b_dist:
		return !sort_close
	return sort_close

func _map_marker_to_position(marker: Node3D) -> Vector3:
	return marker.global_position

## AREA OF EFFECT HELPERS

func spawn_aoe_wave(
	max_radius: float,
	damage: float = 10.0,
	spawned_wave_time: float = 1.0,
	area_pos: Vector3 = self.global_position,
	pushback_source: Node3D = self,
	spawned_wave_height: float = 0.3,
	_telegraph: bool = false,
	callback: Callable = func(): pass,
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
	
	scene_root.add_child(area_collider)
	
	area_collider.global_position = area_pos
	area_collider.body_entered.connect(_on_wave_collision.bind(damage, area_collider, max_radius))
	#area_collider.body_entered.connect(area_collider.queue_free.unbind(1))
	
	var debug_mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	
	spawned_area_objects.append([area_collider, debug_mesh_instance])
	
	# Generate a visual
	scene_root.add_child(debug_mesh_instance)
	
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


func spawn_aoe_bubble(radius: float, damage: float, spawn_pos: Vector3, duration: float, pushback_source: Node3D = self) -> void:
	# Generate a collider
	var area_collider := Area3D.new()
	var area_collider_shape := CollisionShape3D.new()
	var collider_shape := SphereShape3D.new()
	collider_shape.radius = radius
	area_collider_shape.shape = collider_shape
	area_collider.add_child(area_collider_shape)
	area_collider.collision_layer = int(pow(2, 7))
	area_collider.collision_mask = int(pow(2, 2 - 1))
	area_collider.monitoring = true
	
	scene_root.add_child(area_collider)
	
	area_collider.global_position = spawn_pos
	area_collider.body_entered.connect(_on_wave_collision.bind(damage, pushback_source, radius))
	
	await get_tree().create_timer(duration).timeout
	
	area_collider.queue_free()


func _on_wave_collision(
	body: Node3D, 
	aoe_damage: float, 
	pushback_source: Node3D = self, 
	pushback_radius: float = pushback_source.collider.shape.radius
) -> void:
	if body == target:
		body.health_component.damage(aoe_damage)
		trigger_pushback(pushback_force, pushback_source, pushback_radius)


func _on_chiptopede_death_freeze_state_entered() -> void:
	self.global_position = follow_nodes[0].get_child(0).global_position
	state_chart.send_event("start_exploding")


func _on_chiptopede_death_exploding_state_entered() -> void:
	# Explode chiptopede segments one by one
	follow_nodes.reverse()
	for node in follow_nodes:
		if is_instance_valid(node):
			var segment = node.get_child(0)
			if segment:
				segment.queue_free()
				# If the segment is below the waterline just free it and move on
				if segment.global_position.y < -20.0:
					continue
				var explosion_inst = explosion_scene.instantiate()
				scene_root.add_child(explosion_inst)
				explosion_inst.global_position = segment.global_position
				explosion_inst.change_mesh_scale(2.0)
				await get_tree().create_timer(chiptopede_explosion_delay).timeout
	
	state_chart.send_event("end_exploding")


func _on_chiptopede_death_dead_state_entered() -> void:
	state_chart.send_event("deactivate")
	state_chart.send_event("death")
	died.emit()
	#await death_anim_finished
	var land_markers = chiptopede_spawns.duplicate()
	land_markers.sort_custom(
		_sort_by_distance_to_target
	)
	var nearest_land_pos: Vector3 = land_markers.front().global_position + Vector3(0, 1.0, 0)
	drop_barrel(nearest_land_pos)
	await boss_death_slow_mo()
