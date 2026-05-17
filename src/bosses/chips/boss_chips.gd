extends BossCore
class_name BossChips

# Antes note:
# Ante 1: Place Your Bet - Enable place your bet attack
# Ante 2 (new): Unstable Split - All splitted stack will drop a random hazard area on the ground over time.
# Ante 3 (new): Empowered Avatar - Improved Chip Sweep, Shockwave and Backspin Chip
#               Chip Sweep can now do volley of 3 per repeat / Shockwave apply long slow debuff / Backspin create 3 chips
# Ante 4 (new): Five of a kind - Spawn 5 substack instead of 3
# Ante 5 (new): Spiked Beer - Beer will deal hp damage and slow

# TODO - Add intro cutscene of swarm of chips coming out of drains and forming the big stack

signal substack_attack_finished
signal substack_all_attacks_finished
signal flood_chamber
signal drain_chamber
signal break_floor
signal chiptopede_emerges
signal leap_finished(head_segment: Node)
signal segment_deactivated(segment: ChiptopedeSegment)

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
@export_subgroup("Jumping")
var aoe_markers: Array[Node]
var center_pos := Vector3(0, 0, -2)
@export var slam_aoe_decal: CompressedTexture2D

## Attacks
@export_group("Attacks | General")
@export var explosion_scene: PackedScene
@export var pushback_force: float = 20.0
var aoe_wave_pool: Array = []
var aoe_bubble_pool: Array = []
# SFX
@export var sfx_jump: Array[AudioStream]
@export var sfx_hurt_scream: Array[AudioStream]
#
@export_subgroup("Form Transitions")
@export var max_big_attacks: int = 3
var big_attacks_performed: int = 0
@export var max_small_attacks: int = 2
var small_attacks_performed: int = 0
var _spawn_tweens: Array[Tween] = []
# SFX
@export var sfx_stack_split: Array[AudioStream]
@export var sfx_stack_merge: Array[AudioStream]
@export var sfx_chiptopede_awaken: AudioStream
#
## BIG STACK
@export_group("Attacks | Big Stack")
@export_subgroup("Backspin Chip")
@export var rolling_chip_damage: float = 15
@export var rolling_chip_projectile: PackedScene
@export var n_chips_per_roll: int = 1 # Based on ante 3
@export var rolling_chip_repeat_per_attack: int = 2
var chips_fired: int = 0
var active_rolling_chips: Array[RollingChip] = []
var rolling_chip_spread_deg: float = 90 # Based on ante 3
# SFX
@export var sfx_chip_fire: Array[AudioStream]
#
@export_subgroup("Chip Sweep")
@export var chip_sweep_damage: float = 10
@export var n_chips_per_sweep_volley: int = 1 # Based on ante 3
@export var chip_sweep_repeat: int = 3
@export var sweep_time: float = 0.05
@export var sweep_delay: float = 0.4
@export var chip_sweep_prefab: PackedScene
var chip_sweep_instances: Array = []
# SFX
@export var sfx_chip_sweep_out: Array[AudioStream]
#
@export_subgroup("Stack Slam")
@export var slam_shockwave_prefab: PackedScene
@export var slam_count: int = 3
@export var slam_damage: float = 10.0
@export var slam_wave_speed: float = 2.1
@export var slam_wave_radius: float = 35.0
@export var slam_delay: float = 0.4
@export var shockwave_slow_duration: float = 2 # Based on ante 3
@export var shockwave_slow_perc: float = 50 # Based on ante 3
var completed_slams: int = 0
var aoe_floor = 0.0
var shockwave_apply_slow_enabled = false # Based on ante 3
var dash_speed_debuff_icon = preload("res://assets/sprite/status_icon/dash_speed_down.png")
var run_speed_debuff_icon = preload("res://assets/sprite/status_icon/run_speed_down.png")
# SFX
@export var sfx_slam: Array[AudioStream]
#
@export_subgroup("Place Your Bets")
var place_your_bet_attack_enabled = false
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
@export var small_stack_count: int = 3
@export var small_stack_prefab: PackedScene
@export var stack_spawn_time: float = 0.1
var small_stack_pool: Array = []
var active_stacks: Array = []
var finished_stacks: Array = []
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
@export var chip_mine_damage: float = 10
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
# Segment collision
@onready var segment_hit_area: Area3D = $ChiptopedeSegmentHitArea
var _segment_col_shapes: Array[CollisionShape3D] = []
var _segment_health: Array[int] = []
const SEGMENT_COLLISION_RADIUS: float = 4.0  # Aligns to ChiptopedeSegment mesh radius
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
@export var chip_stack_particles_prefab: PackedScene
@export var splash_particle_prefab: PackedScene
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
var is_leap_first_impact: bool = true
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
var shooting_stance_path: Path3D
var emerge_speed: float = 10.0
var emerge_distance: float

# CHIPTOPEDE stuff

@export var chiptopede_projectile_damage: float = 15
@export var chiptopede_projectile_speed: float = 50
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
@onready var chip_death_particles: GPUParticles3D = $ChipDeathParticles

@export_group("Passive")
@export_subgroup("Unstable Split")
var unstable_split_enabled = false # Based on ante 2
@onready var unstable_split_timer: Timer = $UnstableSplitTimer
@export var possible_hazards: Array[PackedScene] = []
@export var hazard_duration: float = 5
@export var unstable_split_interval: float = 6

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
	
	health_component.initialize_health()
	health_ui.clear_sub_health_bars()
	health_ui.init_boss_health_ui(int(health_component.max_health), 2)
	
	if GameManager.boss_ante >= 1:
		place_your_bet_attack_enabled = true
	if GameManager.boss_ante >= 2:
		unstable_split_enabled = true
	if GameManager.boss_ante >= 3:
		shockwave_apply_slow_enabled = true
		n_chips_per_roll = 5
		n_chips_per_sweep_volley = 3
	if GameManager.boss_ante >= 4:
		small_stack_count = 5
	if GameManager.boss_ante >= 5:
		pass # In boss_chip map script
	
	for i in range(slam_count + 1):
		_init_aoe_wave()
	
	# Stack pool init
	var _parent = get_parent()
	if not _parent.is_node_ready():
		await _parent.ready
	_init_stack_pool()
	
	# Chiptopede init
	leap_finished.connect(_on_chiptopede_leap_impact)
	chiptopede_max_health *= GameManager.get_risk_max_hp_mult()
	_create_segment_cache()
	generate_snake_graph()
	for i in range(5):
		_init_aoe_bubble()

	await get_tree().process_frame
	await get_tree().process_frame

	aoe_markers = get_tree().get_nodes_in_group("chip_boss_aoe_marker")

func activate() -> void:
	print_debug("BossChips activate called")
	super ()
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


func _physics_process(delta: float) -> void:
	# Disable big stack processing while hidden but keep ticking the chiptopede
	if sprite.visible:
		super(delta)
	_tick_segments(delta)


func _tick_segments(delta: float) -> void:
	for i in range(follow_nodes.size()):
		var path_follow: PathFollow3D = follow_nodes[i]
		if not path_follow or path_follow.get_child_count() == 0:
			continue
		
		var segment: ChiptopedeSegment = path_follow.get_child(0)
		
		# Rotate visual mesh
		segment.tick(delta)
		# Update collision shape position
		if i < _segment_col_shapes.size():
			var col_shape: CollisionShape3D = _segment_col_shapes[i]
			col_shape.disabled = false
			col_shape.global_position = segment.global_position


func _exit_tree() -> void:
	_cleanup_segment_arrays()


## HEALTH TRIGGERS

func _on_health_changed(new_health: float, prev_health: float) -> void:
	super(new_health, prev_health)
	if new_health < health_component.max_health * phase_2_health_percentage_trigger:
		if current_phase == 1:
			current_phase = 2
			state_chart.send_event("start_phase_2")


func _on_health_dead_state_entered() -> void:
	# Before we trigger the death state, make sure we've merged back into the big stack
	_enable_gravity()
	_cleanup_backspin_chip()
	_on_chip_sweep_state_exited()
	#return_big_stack_to_center()
	merge_stacks()

	died.emit()
	# interlude is 11.3 seconds from here

	if anim_player.is_playing():
		anim_player.stop()
		anim_player.play("RESET")

	chip_death_particles.emitting = true
	var death_time: float = 4.0
	for i in range(death_time / 0.2):
		# Death anim loops, so wait for X loops then finish
		anim_player.play("death")
		# TODO - chip particle effect
		#
		await anim_player.animation_finished
	chip_death_particles.emitting = false
	anim_player.process_mode = Node.PROCESS_MODE_DISABLED
	# Hide the sprite and explode into chips
	# TODO - make this area damage explosion a generic method we can re-use
	# Create an explosion
	sprite.render_priority = -1
	SoundManager.play_sound(sfx_chiptopede_impact.pick_random(), "SFX")
	var explosion_inst = explosion_scene.instantiate()
	add_child(explosion_inst)
	explosion_inst.change_mesh_scale(4.0)
	explosion_inst.global_position = self.global_position
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, explosion_inst.fire.lifetime / 2)

	death_anim_finished.emit()


func _on_died() -> void:
	if current_phase != 3:
		SoundManager.play_sound(sfx_death, "SFX")
		SoundManager.play_sound(sfx_hurt_scream.pick_random(), "SFX")
		state_chart.send_event("stop_moving")
		state_chart.call_deferred("send_event", "deactivate")
		_on_health_dead_state_entered()
		# 4s delay
		await death_anim_finished
		# 0.2s delay
		await boss_death_slow_mo()
		defeated.emit(self)
		health_ui.hide_ui()
	else:
		SoundManager.play_sound(sfx_chiptopede_death.pick_random(), "SFX")
		persist_segements = true
		state_chart.send_event("stop_moving")
		state_chart.call_deferred("send_event", "chiptopede_death")


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
			if place_your_bet_attack_enabled:
				if attack_roll < 25:
					attack_str = "start_chip_sweep"
				elif attack_roll < 35:
					attack_str = "start_backspin_chip"
				elif attack_roll < 65:
					attack_str = "start_place_your_bets_attack"
				else:
					attack_str = "start_slam_attack"
			else:
				if attack_roll < 35:
					attack_str = "start_chip_sweep"
				elif attack_roll < 65:
					attack_str = "start_backspin_chip"
				else:
					attack_str = "start_slam_attack"
			big_attacks_performed += 1

		ChipBossForms.SPLIT_STACKS:
			# Transition between big and small forms:
			if small_attacks_performed >= max_small_attacks:
				# FIXME - radial attack with reform
				#state_chart.send_event("change_form_big_aoe_merge")
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

func big_stack_jump(goal_pos: Vector3, _height: float = jump_height, hover: bool = true) -> void:
	anim_player.play("big_stack/jump_start")
	big_stack_sfx_player.stream = sfx_jump.pick_random()
	big_stack_sfx_player.play()

	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(
		self, "global_position", goal_pos, jump_time
	).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

	await jump_tween.finished
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 
	
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
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 

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
	# Re-enable collision
	await get_tree().create_timer(0.1).timeout
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 
	
	self.collision_layer = 4
	self.collision_mask = int(pow(2, 1 - 1) + pow(2, 2 - 1) + pow(2, 4 - 1))
	collider.set_deferred("disabled", false)
	hurtbox_collider.set_deferred("disabled", false)
	get_node("AimAssistBubble/CollisionShape3D").set_deferred("disabled", false)
	
	sprite.visible = true
	sprite.layers = 2
	#debug_mesh.visible = true
	health_component.show_damage_text = true
	
	#set_physics_process(true)
	set_process(true)
	navigation_component.enable()
	
	return


func hide_big_stack() -> void:
	#set_physics_process(false)
	set_process(false)
	navigation_component.disable()
	
	sprite.visible = false
	sprite.layers = 0
	#debug_mesh.visible = false
	health_component.show_damage_text = false
	
	collision_layer = 0
	collision_mask = 1
	collider.set_deferred("disabled", true)
	hurtbox_collider.set_deferred("disabled", true)
	get_node("AimAssistBubble/CollisionShape3D").set_deferred("disabled", true)

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
	active_stacks = await spawn_stacks(small_stack_count, 2.5)

func _spawn_stacks_on_platforms() -> void:
	var far_platforms = aoe_markers.duplicate()
	far_platforms.sort_custom(
		_sort_by_distance_to_target.bind(false)
	)
	far_platforms = far_platforms.map(_map_marker_to_position)

	active_stacks = await spawn_stacks(small_stack_count, 0.0, far_platforms)

# Merging
func merge_stacks() -> void:
	await despawn_stacks()
	trigger_pushback()
	await show_big_stack()
	big_stack_sfx_player.stream = sfx_stack_merge.pick_random()
	big_stack_sfx_player.play()

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
		cancel_substack_attacks()
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
		# Catch and handle a mid-await state change
		if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
			return 
		state_chart.send_event("start_merge_aoe_finisher")
		return

	_reset_to_big_stack()
	await big_stack_jump_to_center(jump_height, false)
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 

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

	var rotate_deg_per_chip_idx = rolling_chip_get_angles(n_chips_per_roll, rolling_chip_spread_deg)
	for i in range(n_chips_per_roll):
		# Instance a chip projectile
		var chip_inst: RollingChip = rolling_chip_projectile.instantiate()
		chip_inst.init(rolling_chip_damage * GameManager.get_risk_dmg_mult())
		active_rolling_chips.append(chip_inst)
		scene_root.add_child(chip_inst)
		chip_inst.global_transform = self.global_transform
		chip_inst.rotate_y(deg_to_rad(rotate_deg_per_chip_idx[i]))

		# Send it towards the player
		var forward_target: Vector3 = chip_inst.get_point_before_wall()
		chip_inst.roll_to_point(forward_target, 0.8)

	big_stack_sfx_player.stream = sfx_chip_fire.pick_random()
	big_stack_sfx_player.play()

	await active_rolling_chips[0].spin_finished
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 

	state_chart.send_event("reverse_spin")


func _on_backspin_chip_back_spin_state_entered() -> void:
	debug_state_label.text = "Backspin Chip | BackwardSpin"

	# Send the chip rolling back to the stack
	for chip in active_rolling_chips:
		chip.roll_to_point(self.global_position, 0.8)
	await active_rolling_chips[0].spin_finished
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 

	state_chart.send_event("end_spin")


func _on_backspin_chip_recover_state_entered() -> void:
	debug_state_label.text = "Backspin Chip | Recovery"

	_cleanup_backspin_chip()
	chips_fired += 1
	anim_player.play("big_stack/projectile_telegraph")

	if chips_fired >= rolling_chip_repeat_per_attack:
		chips_fired = 0
		state_chart.send_event("attack_end")

		await get_tree().create_timer(attack_recovery_time).timeout
		# Catch and handle a mid-await state change
		if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
			return 

		state_chart.send_event("cooldown_end")
		anim_player.play("big_stack/idle")
		select_attack()
		state_chart.call_deferred("send_event", "end_recovery")
	else:
		state_chart.send_event("start_targeting")
		state_chart.call_deferred("send_event", "next_shot")


func _cleanup_backspin_chip() -> void:
	for chip in active_rolling_chips:
		if is_instance_valid(chip):
			chip.queue_free()

	active_rolling_chips = []


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
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 

	for i in chip_sweep_repeat:
		# HACK - break out of this loop if we send an end_attack event
		if "end_attack" in state_chart._queued_events:
			return

		for j in range(n_chips_per_sweep_volley):
			var sweep_proj: ChipSweepProjectile = chip_sweep_prefab.instantiate()
			sweep_proj.init(chip_sweep_damage * GameManager.get_risk_dmg_mult())
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
		# Catch and handle a mid-await state change
		if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
			return 

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
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 

	var target_pos: Vector3 = self.global_position
	target_pos.y = aoe_floor

	await big_stack_slam(target_pos, drop_time / 2)
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 

	state_chart.send_event("spawn_wave")


func _on_stack_slam_slam_state_entered() -> void:
	var shockwave = slam_shockwave_prefab.instantiate()
	scene_root.add_child(shockwave)

	shockwave.global_transform = self.global_transform
	shockwave.global_position.y = aoe_floor
	shockwave.max_radius = slam_wave_radius
	shockwave.damage = slam_damage * GameManager.get_risk_dmg_mult()
	shockwave.wave_time = slam_wave_speed
	shockwave.start_shockwave()

	completed_slams += 1

	# Apply player slow
	if shockwave_apply_slow_enabled:
		GameManager.create_and_add_status_effect("Run speed down",
			"lunge_concussion_run_speed",
			StatusEffect.PlayerStatEnum.RUN_SPEED_MODIFIER,
			- shockwave_slow_perc,
			StatusEffect.ModifyType.PERCENTAGE,
			shockwave_slow_duration,
			true,
			true,
			run_speed_debuff_icon
		)
		GameManager.create_and_add_status_effect("Dash speed down",
			"lunge_concussion_slide_speed",
			StatusEffect.PlayerStatEnum.DASH_SPEED_MODIFIER,
			- shockwave_slow_perc,
			StatusEffect.ModifyType.PERCENTAGE,
			shockwave_slow_duration,
			true,
			true,
			dash_speed_debuff_icon
		)

	await get_tree().create_timer(slam_delay).timeout
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 

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
	for stack in active_stacks:
		stack.state_chart.send_event(attack_event)
		if stack_delay:
			await get_tree().create_timer(stack_delay).timeout
			# Catch and handle a mid-await state change
			if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
				return 

	await substack_all_attacks_finished
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 

	state_chart.send_event("finish_attack")


func cancel_substack_attacks() -> void:
	for stack in active_stacks:
		stack.state_chart.send_event("end_attack")


func trigger_sequential_substack_attacks(activate_event: String, attack_event: String) -> void:
	for stack in active_stacks:
		stack.state_chart.send_event(activate_event)
	for stack in active_stacks:
		stack.state_chart.send_event(attack_event)
		await substack_attack_finished
		# Catch and handle a mid-await state change
		if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
			return 

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
	for i in range(active_stacks.size()):
		var stack = active_stacks[i]
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
	area_collider.body_entered.connect(_on_wave_collision.bind(split_rush_damage * GameManager.get_risk_dmg_mult()))

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
	state_chart.call_deferred("send_event", "change_form_big")
	await get_tree().process_frame
	state_chart.call_deferred("send_event", "end_recovery")

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
	shockwave.damage = slam_damage * GameManager.get_risk_dmg_mult()
	shockwave.wave_time = 1.4
	shockwave.start_shockwave()

	big_stack_sfx_player.stream = sfx_stack_merge.pick_random()
	big_stack_sfx_player.play()

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
	# Catch and handle a mid-await state change
	if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
		return 
	# Disable collision to avoid clipping player into platform on slam
	self.collision_layer = 0 # None
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
	await spawn_aoe_wave(aoe_radius, drop_damage * GameManager.get_risk_dmg_mult(), 0.1)
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

	for i in range(active_stacks.size()):
		var stack = active_stacks[i]
		var target_marker: Marker3D = closest_targets.pop_front()
		stack.marker_target_idx = aoe_markers.find(target_marker)

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

	for i in range(active_stacks.size()):
		var stack = active_stacks[i]

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
		# Catch and handle a mid-await state change
		if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
			return 

		spawn_aoe_wave(
			aoe_radius,
			(drop_damage * GameManager.get_risk_dmg_mult()) / active_stacks.size(),
			aoe_wave_time,
			stack.global_position,
			stack
		)

		await get_tree().create_timer(split_aoe_dive_delay).timeout
		# Catch and handle a mid-await state change
		if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED:
			return 

	await substack_all_attacks_finished

	state_chart.send_event("finish_attack")


#### Phase 3 - Chiptopede

func _on_phase_3_state_entered() -> void:
	current_phase = 3
	# 4.2s delay going in
	# +0.3s despawning
	await despawn_stacks()

	hide_big_stack()

	#
	self.global_position = despawned_pos
	
	break_floor.emit()
	# 6.5s  delay
	await get_tree().create_timer(3.8).timeout
	activate_chiptopede()


func activate_chiptopede() -> void:
	# Play awakening sound from below
	chiptopede_sfx_player.stream = sfx_chiptopede_awaken
	chiptopede_sfx_player.play()
	
	# Re-fill health bar, change name, and show
	health_component.has_died = false
	if GameManager.CHEAT_oneshot:
		chiptopede_max_health = 1
	health_component.max_health = chiptopede_max_health
	health_component.current_health = chiptopede_max_health
	health_component.received_dmg_multiplier = 0.5
	#health_ui.init_health_ui(chiptopede_max_health)
	health_ui.clear_sub_health_bars()
	health_ui.init_boss_health_ui(int(chiptopede_max_health), 1)
	health_ui.boss_name = "Chiptopede"
	health_ui.show_ui()

	# Have longer between chiptopede attacks
	attack_recovery_time *= 2
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

	var chip_particles = chip_stack_particles_prefab.instantiate()
	scene_root.add_child(chip_particles)
	chip_particles.global_position = self.global_position
	chip_particles.process_material.emission_shape_scale = Vector3(3, 3, 3)
	chip_particles.emitting = true
	await chip_particles.finished
	chip_particles.queue_free()


func _on_chiptopede_leapleaping_state_physics_processing(delta: float) -> void:
	move_segments_along_path(
		"end_leap", leap_speed, leap_distance, delta, leap_finished.emit
	)


func _on_chiptopede_leap_leaping_state_exited() -> void:
	if not persist_segements:
		_cleanup_segment_arrays()
		leap_path.queue_free.call_deferred()
	leap_damage_timer.stop()
	chiptopede_sfx_player.stop()
	chiptopede_sfx_player.stream = null
	is_leap_first_impact = true


func _on_chiptopede_leap_impact(segment: Node) -> void:
	if leap_damage_timer.is_stopped():
		# Check if we're impacting the water or a solid mesh
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			segment.global_position + Vector3(0, 30, 0),
			segment.global_position,
			int(pow(2, 1 - 1) + pow(2, 9 - 1)),
		)
		query.collide_with_areas = true
		var result = space_state.intersect_ray(query)
		if result:
			if result.collider is Area3D:
				var splash = splash_particle_prefab.instantiate()
				scene_root.add_child(splash)
				splash.global_position = result.collider.global_position
				# Scale up the splash particles
				splash.draw_pass_1.size = Vector2(7, 7)
				splash.amount = 32
				splash.get_child(0).draw_pass_1.size = Vector2(7, 7)
				splash.emitting = true
			else:
				if is_leap_first_impact:
					var chip_particles = chip_stack_particles_prefab.instantiate()
					scene_root.add_child(chip_particles)
					chip_particles.global_position = segment.global_position
					chip_particles.process_material.emission_shape_scale = Vector3(1.5, 1.5, 1.5)
					chip_particles.emitting = true
					#await chip_particles.finished
					#chip_particles.queue_free()
					is_leap_first_impact = false

		#
		chiptopede_sfx_player.stream = sfx_chiptopede_impact.pick_random()
		chiptopede_sfx_player.play()
		#
		spawn_aoe_bubble(leap_aoe_radius, leap_damage * GameManager.get_risk_dmg_mult(), segment.global_position, 0.4, segment)
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
	for node in follow_nodes:
		var segment = node.get_child(0)
		#segment.splash_particles.emitting = true
		segment.splash_ring_particles.emitting = true

	chiptopede_sfx_player.stream = sfx_chiptopede_snake.pick_random()
	chiptopede_sfx_player.play()


func _on_chiptopede_snake_moving_state_physics_processing(delta: float) -> void:
	move_segments_along_path(
		"end_snake", snake_speed, snake_distance, delta
	)


func _on_chiptopede_snake_moving_state_exited() -> void:
	if not persist_segements:
		_cleanup_segment_arrays()
		snake_path = []
		snake_path_3d.queue_free.call_deferred()
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
	shooting_stance_path = create_premade_path(spawn_pos, shooting_stance_prefab)

	#
	chiptopede_sfx_player.stream = sfx_chiptopede_emerge.pick_random()
	chiptopede_sfx_player.play()
	#
	follow_nodes = spawn_segments(shooting_stance_path)

	emerge_distance = shooting_stance_path.curve.get_baked_length()
	
	# TOOD - replace instancing/freeing with particle effect pool
	var splash = splash_particle_prefab.instantiate()
	scene_root.add_child(splash)
	splash.global_position = follow_nodes[0].get_child(0).global_position
	# Scale up the splash particles
	splash.draw_pass_1.size = Vector2(7, 7)
	splash.amount = 32
	splash.get_child(0).draw_pass_1.size = Vector2(7, 7)
	splash.emitting = true
	await splash.finished
	splash.queue_free.call_deferred()


func _on_chiptopede_shoot_emerging_state_physics_processing(delta: float) -> void:
	turn_towards_target(shooting_stance_path, chiptopede_targeting_speed, delta)

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
	turn_towards_target(shooting_stance_path, chiptopede_targeting_speed, delta)


func _on_chiptopede_shoot_shooting_state_entered() -> void:
	state_chart.send_event("attack_start")

	for i in chiptopede_projectile_bursts:
		for j in chiptopede_shots_per_burst:
			await get_tree().create_timer(chiptopede_delay_per_projectile).timeout
			#
			chiptopede_sfx_player.stream = sfx_chiptopede_shoot.pick_random()
			chiptopede_sfx_player.play()
			#
			var proj_inst = fire_projectile(chiptopede_projectile, follow_nodes[0].global_position)
			proj_inst.init(chiptopede_projectile_damage * GameManager.get_risk_dmg_mult(), chiptopede_projectile_speed)
		await get_tree().create_timer(delay_between_burst).timeout

	state_chart.send_event("stop_shooting")


func _on_chiptopede_shoot_shooting_state_physics_processing(delta: float) -> void:
	turn_towards_target(shooting_stance_path, chiptopede_targeting_speed, delta)


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
	var splash = splash_particle_prefab.instantiate()
	scene_root.add_child(splash)
	splash.global_position = follow_nodes[0].global_position
	# Scale up the splash particles
	splash.draw_pass_1.size = Vector2(7, 7)
	splash.amount = 32
	splash.get_child(0).draw_pass_1.size = Vector2(7, 7)
	splash.emitting = true

	if not persist_segements:
		_cleanup_segment_arrays()
		shooting_stance_path.queue_free.call_deferred()

	await splash.finished
	splash.queue_free.call_deferred()

	_recover_entered()


func _on_chiptopede_hurt(health_diff: float) -> void:
	if health_diff < 0:
		health_component.damage(abs(health_diff))


#### SPLIT STACK HELPER METHODS

func _init_stack_pool() -> void:
	for i in range(small_stack_count):
		var stack: ChipBossSubStack = small_stack_prefab.instantiate()
		get_parent().add_child(stack)
		stack.big_stack = self
		# Connect signals
		stack.health_component.health_diff.connect(_small_stack_hurt)
		stack.health_component.died.connect(_small_stack_dead.bind(stack))
		stack.state_chart.event_received.connect(_substack_on_event_received.bind(stack))
		stack.substack_charge_set.connect(_on_substack_charge_set)
		
		_deactivate_stack(stack)
		small_stack_pool.append(stack)


func _activate_stack(stack: ChipBossSubStack, idx: int, count: int) -> void:
	stack.collider.set_deferred("disabled", false)
	stack.hurtbox_collider.set_deferred("disabled", false)
	stack.get_node("AimAssistBubble/CollisionShape3D").set_deferred("disabled", false)
	stack.collision_layer = 4
	stack.collision_mask = 1
	
	stack.group_size = count
	stack.group_idx = idx
	stack.center_pos = center_pos
	stack.aoe_markers = aoe_markers
	stack.target = target
	stack.global_transform = self.global_transform
	stack.scale = Vector3(0, 1, 0)
	stack.health_component.initialize_health()
	
	stack.process_mode = Node.PROCESS_MODE_INHERIT
	stack.set_physics_process(true)
	stack.set_process(true)
	stack.navigation_component.enable_for_pool()
	
	stack.show()
	stack.sprite.layers = 2
	active_stacks.append(stack)


func _deactivate_stack(stack: ChipBossSubStack) -> void:
	stack.process_mode = Node.PROCESS_MODE_DISABLED
	stack.set_physics_process(false)
	stack.set_process(false)
	stack.navigation_component.disable_for_pool()
	stack.navigation_component.disable()
	
	stack.hide()
	stack.sprite.layers = 0
	
	stack.collision_layer = 0
	stack.collision_mask = 0
	stack.collider.set_deferred("disabled", true)
	stack.hurtbox_collider.set_deferred("disabled", true)
	stack.get_node("AimAssistBubble/CollisionShape3D").set_deferred("disabled", true)
	
	active_stacks.erase(stack)


func spawn_stacks(stack_count: int, spawn_distance: float, spawn_positions: Array = []) -> Array:
	assert(stack_count <= small_stack_count, "stack_count exceeds stack pool size")
	var spawned: Array = []
	
	# Kill any leftover tweens from a previous call
	for tween in _spawn_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_spawn_tweens.clear()
	
	# Spawn small stacks from the center point of the big stack and space them out
	for i in range(stack_count):
		var stack: ChipBossSubStack = small_stack_pool[i]
		_activate_stack(stack, i, stack_count)
		
		# SFX trigger
		big_stack_sfx_player.stream = sfx_stack_spawn.pick_random()
		big_stack_sfx_player.play()
		
		var spawn_pos: Vector3
		if spawn_positions:
			spawn_pos = spawn_positions[i]
		else:
			spawn_pos = self.global_position + (
				self.global_transform.basis.z * spawn_distance
			).rotated(Vector3.UP, 2 * PI / stack_count * (i + 1))
		
		if current_phase == 2:
			stack.navigation_component.disable()
		
		var tween: Tween = get_tree().create_tween()
		_spawn_tweens.append(tween)
		tween.tween_property(stack, "global_position", spawn_pos, stack_spawn_time)
		tween.parallel().tween_property(stack, "scale", Vector3.ONE, stack_spawn_time)
		await tween.finished
		
		# Restore collision
		stack.collision_layer = 4
		spawned.append(stack)
	
	if unstable_split_enabled:
		unstable_split_timer.start(unstable_split_interval)
	
	return spawned


func despawn_stacks(_despawn_time: float = stack_spawn_time) -> void:
	for stack in active_stacks.duplicate(true):
		# SFX trigger
		big_stack_sfx_player.stream = sfx_stack_despawn.pick_random()
		big_stack_sfx_player.play()

		var tween: Tween = get_tree().create_tween()
		tween.tween_property(stack, "global_position", self.global_position, stack_spawn_time)
		tween.parallel().tween_property(stack, "scale", Vector3.ZERO, stack_spawn_time)

		await tween.finished

		_deactivate_stack(stack)
	
	active_stacks = []

	if unstable_split_enabled:
		unstable_split_timer.stop()


func _substack_on_event_received(event: String, stack: ChipBossSubStack) -> void:
	if event == "end_recovery":
		stack.state_chart.send_event("end_attack")
		_substack_finished(stack)

func _on_substack_charge_set(pos: Vector3) -> void:
	self.global_position = pos

func _substack_finished(stack: ChipBossSubStack) -> void:
	finished_stacks.append(stack)
	substack_attack_finished.emit()
	if finished_stacks.size() == active_stacks.size():
		last_stack = stack
		substack_all_attacks_finished.emit()
		finished_stacks = []

func _small_stack_hurt(health_diff: float) -> void:
	if health_diff < 0:
		health_component.damage(abs(health_diff))

func _small_stack_dead(stack: CharacterBody3D) -> void:
	_substack_finished(stack)
	_deactivate_stack(stack)


#### CHIPTOPEDE HELPER METHODS

func get_chiptopede_spawn_pos(
	spawn_marker_group: Array[Node],
	_min_spawn_distance: float = 0.0,
	_max_spawn_distance: float = 0.0,
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
	if _min_spawn_distance:
		filtered_spawns = filtered_spawns.filter(
			func(spawn):
				return spawn.global_position.distance_to(sort_target) >= _min_spawn_distance
		)
	if _max_spawn_distance:
		filtered_spawns = filtered_spawns.filter(
			func(spawn):
				return spawn.global_position.distance_to(sort_target) <= _max_spawn_distance
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

	# Failsafe
	if last_spawn == null:
		push_warning("Can't find a spawn in get_chiptopede_spawn_pos()")
		last_spawn = available_spawns[0]

	return last_spawn


# PATH GENERATION

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
	var out_0 = (mid_point - start_pos) * leap_out_ratio # 0.6667
	var in_1 = (mid_point - goal_pos) * leap_in_ratio # 0.6667
	curve.add_point(start_pos, Vector3.ZERO, out_0)
	curve.add_point(goal_pos, in_1, Vector3.ZERO)

	return curve

func _create_snake_path(_start_pos: Vector3, _goal_pos: Vector3, _follow_path: Array) -> Curve3D:
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

## Segment Handlers

func _create_segment_cache() -> Node3D:
	segment_cache_parent = Node3D.new()
	get_tree().root.get_children()[8].add_child(segment_cache_parent)
	segment_cache_parent.global_position = despawned_pos
	_segment_col_shapes.clear()

	for idx in range(chiptopede_segments):
		var segment = chiptopede_segment_prefab.instantiate()
		segment.big_stack = self
		# Collision
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = SEGMENT_COLLISION_RADIUS
		shape.shape = sphere
		shape.disabled = true  # Disable until we activate the segment
		segment_hit_area.add_child(shape)
		_segment_col_shapes.append(shape)
		
		cache_segment(segment)
	
	# Setup sfx player at head segment
	var chiptopede_head = segment_cache_parent.get_child(0)
	chiptopede_head.add_child(chiptopede_sfx_player)
	
	return segment_cache_parent


func cache_segment(segment: ChiptopedeSegment, segment_parent: Node3D = null) -> void:
	var idx: int = segment.segment_idx
	if idx >= 0 and idx < _segment_col_shapes.size():
		_segment_col_shapes[idx].disabled = true
		segment_deactivated.emit(segment)
	
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

	for idx in chiptopede_segments:
		var path_follow := PathFollow3D.new()
		path.add_child(path_follow)

		var new_segment: ChiptopedeSegment = get_segment_from_cache()
		new_segment.segment_idx = idx

		# Moving segments
		path_follow.add_child(new_segment)
		new_segment.global_position = path_follow.global_position
		new_segment.visible = true
		new_segment.splash_particles.emitting = false
		new_segment.splash_ring_particles.emitting = false
		
		# Enable collision
		if idx < _segment_col_shapes.size():
			_segment_col_shapes[idx].disabled = false

		path_follow_nodes.append(path_follow)

	return path_follow_nodes


func move_segments_along_path(
	end_event_str: String, speed: float, max_distance: float, delta: float,
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


func _cleanup_segment_arrays() -> void:
	for node in follow_nodes:
		if is_instance_valid(node):
			if node.get_child_count() == 0:
				continue
			var segment = node.get_child(0)
			if segment:
				segment.splash_particles.emitting = false
				segment.splash_ring_particles.emitting = false
				cache_segment(segment, node)
	follow_nodes = []
	completed_nodes = []
	chiptopede_head_offset = 0.0


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
	state_chart.call_deferred("send_event", "attack_buildup")
	await get_tree().create_timer(0.8).timeout
	state_chart.send_event("start_jump")


func _on_chip_mines_jump_state_entered() -> void:
	debug_state_label.text = "Chip Mines | Jumping"

	vel_vertical = 0
	GRAVITY = 0

	var jump_tween: Tween = get_tree().create_tween()
	jump_tween.tween_property(self, "global_position", Vector3(0, jump_height / 2, -2), jump_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

	await jump_tween.finished
	await get_tree().create_timer(jump_hang_time / 3).timeout

	var target_pos: Vector3 = self.global_position
	target_pos.y = 0
	jump_tween = get_tree().create_tween()
	jump_tween.tween_property(self, "global_position", target_pos, drop_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	await jump_tween.finished
	await spawn_aoe_wave(aoe_radius, drop_damage * GameManager.get_risk_dmg_mult(), aoe_wave_time)

	state_chart.send_event("start_spawn")


func _on_chip_mines_spawn_mines_state_entered() -> void:
	debug_state_label.text = "Chip Mines | Spawning Mines"
	# Animate each chip mine spawning out of floor
	for i in range(chip_mine_layers):
		for j in range(chip_mine_count / (chip_mine_layers - i)):
			var mine = chip_mine_prefab.instantiate()
			mine.init(chip_mine_damage * GameManager.get_risk_dmg_mult())
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

func _init_aoe_wave() -> void:
	# Generate a collider
	var wave := Node3D.new()
	var area_collider := Area3D.new()
	var area_collider_shape := CollisionShape3D.new()
	var collider_shape := CylinderShape3D.new()
	collider_shape.radius = 0.01
	area_collider_shape.shape = collider_shape
	area_collider.add_child(area_collider_shape)
	area_collider.collision_layer = int(pow(2, 7))
	area_collider.collision_mask = int(pow(2, 2 - 1) + pow(2, 7 - 1)) # Player & Cover
	area_collider_shape.disabled = true
	
	# Generate a visual
	var wave_mesh := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	wave_mesh.mesh = mesh
	wave_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	mesh.bottom_radius = 0.0
	mesh.top_radius = 0.0
	mesh.material = wave_material
	
	wave.add_child(wave_mesh)
	wave.add_child(area_collider)
	scene_root.add_child(wave)
	wave.global_position = despawned_pos
	wave.visible = false
	
	spawned_area_objects.append([area_collider, wave_mesh])
	aoe_wave_pool.push_back(wave)


func spawn_aoe_wave(
	max_radius: float,
	damage: float = 10.0,
	spawned_wave_time: float = 1.0,
	area_pos: Vector3 = self.global_position,
	_pushback_source: Node3D = self,
	spawned_wave_height: float = 0.3,
	callback: Callable = func(): pass ,
) -> void:
	var wave = aoe_wave_pool.pop_front()
	var wave_mesh: MeshInstance3D = wave.get_child(0)
	wave_mesh.mesh.height = spawned_wave_height
	var area: Area3D = wave.get_child(1)
	var area_col: CollisionShape3D = area.get_child(0)
	area_col.shape.radius = 0.01
	area_col.shape.height = spawned_wave_height
	area_col.disabled = false
	area.body_entered.connect(_on_wave_collision.bind(damage, area, max_radius))
	
	wave.global_position = area_pos
	wave.visible = true

	# Animate the visual
	# TODO - SFX)
	var tween = get_tree().create_tween()
	tween.tween_property(wave_mesh.mesh, "bottom_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(wave_mesh.mesh, "top_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(area_col.shape, "radius", max_radius, spawned_wave_time)
	tween.tween_callback(
		func():
			area_col.body_entered.disconnect(_on_wave_collision)
			wave.visible = false
			aoe_wave_pool.push_back(wave)
	)
	tween.tween_callback(callback)
	
	await tween.finished
	
	return


func _init_aoe_bubble() -> void:
	var bubble := Node3D.new()
	# Generate a collider
	var area_collider := Area3D.new()
	var area_collider_shape := CollisionShape3D.new()
	var collider_shape := SphereShape3D.new()
	collider_shape.radius = 0.01
	area_collider_shape.shape = collider_shape
	area_collider.add_child(area_collider_shape)
	area_collider.collision_layer = int(pow(2, 7))
	area_collider.collision_mask = int(pow(2, 2 - 1))
	area_collider_shape.disabled = true

	bubble.add_child(area_collider)
	scene_root.add_child(bubble)
	bubble.global_position = despawned_pos
	bubble.visible = false
	
	spawned_area_objects.append([area_collider])
	aoe_bubble_pool.push_back(bubble)


func spawn_aoe_bubble(radius: float, damage: float, spawn_pos: Vector3, duration: float, pushback_source: Node3D = self) -> void:
	var bubble = aoe_bubble_pool.pop_front()
	var area: Area3D = bubble.get_child(0)
	var area_col: CollisionShape3D = area.get_child(0)
	area_col.shape.radius = radius
	area_col.disabled = false
	area.body_entered.connect(_on_wave_collision.bind(damage, pushback_source, radius))
	
	bubble.global_position = spawn_pos
	
	await get_tree().create_timer(duration).timeout
	
	area_col.shape.disabled = true
	aoe_bubble_pool.push_back(bubble)


func _on_wave_collision(
	body: Node3D,
	aoe_damage: float,
	pushback_source: Node3D = self,
	pushback_radius: float = pushback_source.collider.shape.radius
) -> void:
	if body == target:
		body.health_component.damage(aoe_damage)
		trigger_pushback(pushback_force, pushback_source, pushback_radius)
		InputHelper.rumble_medium()


func _on_chiptopede_death_freeze_state_entered() -> void:
	for node in follow_nodes:
		var segment = node.get_child(0)
		if segment:
			self.global_position = segment.global_position
			break
	state_chart.send_event("start_exploding")


func _on_chiptopede_death_exploding_state_entered() -> void:
	# Explode chiptopede segments one by one
	InputHelper.start_rumble_large()
	follow_nodes.reverse()
	for node in follow_nodes:
		if is_instance_valid(node):
			var segment = node.get_child(0)
			if segment:
				segment.visible = false
				segment.process_mode = PROCESS_MODE_DISABLED
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
	state_chart.call_deferred("send_event", "death")
	died.emit()
	InputHelper.stop_rumble()
	#await death_anim_finished
	var land_markers = chiptopede_spawns.duplicate()
	land_markers.sort_custom(
		_sort_by_distance_to_target
	)
	var nearest_land_pos: Vector3 = land_markers.front().global_position + Vector3(0, 1.0, 0)
	drop_barrel(nearest_land_pos)
	await boss_death_slow_mo()


func _on_attack_telegraph_state_entered() -> void:
	return

func _on_attack_telegraph_state_exited() -> void:
	return

func rolling_chip_get_angles(n: int, spread: float) -> Array[float]:
	var result: Array[float] = []
	if n <= 0:
		return result
	if n == 1:
		return [0.0]

	# shrink the effective spread so items don't sit exactly at the edges
	var effective_spread: float = spread * float(n - 1) / float(n)
	var step: float = effective_spread / float(n - 1)

	for i in range(n):
		var angle: float = - effective_spread / 2.0 + i * step
		result.append(angle)
	return result

func _on_unstable_split_timer_timeout() -> void:
	for stack in active_stacks:
		var chosen_hazard_s


func _on_chiptopede_segment_hit_area_area_entered(area: Area3D) -> void:
	var _parent = area.get_parent()
	if _parent is BaseBullet:
		if _parent is StickyBombProjectile:
			return
		_parent._on_area_3d_body_entered(self)
	
	# TODO - add small chip burst particles on hit 

func _on_chiptopede_segment_hit_area_area_shape_entered(area_rid: RID, area: Area3D, area_shape_idx: int, local_shape_idx: int) -> void:
	var _parent = area.get_parent()
	if _parent is StickyBombProjectile:
		if _parent.sticked:
			return
		# Get the segment node and stick the bullet to that
		var _segment = follow_nodes[local_shape_idx].get_child(0)
		_parent.damage_body(self)
		_parent.stick_bullet(_segment)
		_parent.exploded.connect(_on_sticky_bomb_detonate_segment.bind(local_shape_idx))
		_parent.start_countdown()


func _on_sticky_bomb_detonate_segment(explosion_inst: ExplosionDamageArea, segment_idx: int) -> void:
	var segment_col: CollisionShape3D = _segment_col_shapes[segment_idx]
	# If the segment is off screen the explosion should still do damage
	if segment_col.disabled:
		explosion_inst._on_body_entered(self, false)
		
