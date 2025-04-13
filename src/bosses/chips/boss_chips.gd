extends BossCore
class_name BossChips

signal substack_attacks_finished

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

@export_subgroup("Split Stacks")
@export var small_stack_prefab: PackedScene
@export var stack_spawn_time: float = 0.1
var spawned_sub_stacks: Array = []
var finished_sub_stacks: Array = []
var last_stack: ChipBossSubStack

#@onready var anim_player: AnimationPlayer = $AnimationPlayer
#@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer


func activate() -> void:
	super()
	navigation_component.follow_target = false
	navigation_component.enable()
	state_chart.send_event("start_phase_1")


func select_attack_phase_1() -> void:
	var possible_phases = [
		"start_backspin_chip",
		"start_split_stack_projectiles",
		"start_split_stack_charge",
	]
	if prev_phase:
		possible_phases.erase(prev_phase)
	# TODO - add random weighting
	var new_phase = possible_phases.pick_random()
	print(prev_phase, new_phase)
	prev_phase = new_phase
	state_chart.send_event(new_phase)


func _on_phase_1_state_entered() -> void:
	current_phase = 1
	select_attack()


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


# TODO - change this to specific split attack phases, not a split status. 
# We can have distinct attacks per form, then choose the form, and then attack
# in the select attack method.
func _on_form_split_stacks_state_entered() -> void:
	# Hide the main boss body and disable collision
	sprite.visible = false
	debug_mesh.visible = false
	navigation_component.disable()
	# Disable player and projectile collisions
	self.collision_mask -= (pow(2, 2-1) + pow(2, 4-1))
	hurtbox.set_deferred("monitoring",  false)
	# TODO - prevent damage numbers showing up
	
	spawned_sub_stacks = await spawn_stacks(3)
	
	for stack in spawned_sub_stacks:
		#stack.state_chart.send_event("start_small_projectile_attack")
		stack.state_chart.send_event("start_split_rush_attack")
	
	await substack_attacks_finished
	
	state_chart.send_event("combine_stack")


func _stack_get_new_move_point(stack) -> void:
	var random_pos: Vector3 = NavigationServer3D.map_get_random_point(stack.nav_map_rid, 1, false)
	#draw_debug_sphere(random_pos, 1.0, Color.GREEN)
	stack.navigation_component.set_nav_target_position(random_pos)


func _substack_on_event_received(event: String, stack: ChipBossSubStack) -> void:
	if event == "end_recovery":
		_substack_finished(stack)


func _substack_finished(stack: ChipBossSubStack) -> void:
	finished_sub_stacks.append(stack)
	if finished_sub_stacks.size() == spawned_sub_stacks.size():
		last_stack = stack
		substack_attacks_finished.emit()
		finished_sub_stacks = []


func _on_form_split_stacks_state_exited() -> void:
	await despawn_stacks()
	
	# TODO - generate explosion for split rush
	var explosion_vfx = explosion_scene.instantiate()
	get_tree().get_root().add_child(explosion_vfx)
	explosion_vfx.change_mesh_scale(4)
	explosion_vfx.global_position = self.global_position + Vector3(0, 3, 0)
	explosion_vfx.scale = Vector3(4, 4, 4)
	
	sprite.visible = true
	#navigation_component.enable()
	debug_mesh.visible = true
	self.collision_mask += (pow(2, 2-1) + pow(2, 4-1))
	await get_tree().create_timer(3.0).timeout
	select_attack()


func spawn_stacks(stack_count: int) -> Array:
	var spawned_stacks = []
	# Spawn small stacks from the center point of the big stack and space them out
	for i in range(stack_count):
		var small_stack_inst: CharacterBody3D = small_stack_prefab.instantiate()
		get_parent().add_child(small_stack_inst)
		small_stack_inst.global_transform = self.global_transform
		small_stack_inst.scale = Vector3(0, 1, 0)
		small_stack_inst.health_component.health_diff.connect(_small_stack_hurt)
		small_stack_inst.health_component.died.connect(_small_stack_dead.bind(small_stack_inst))
		small_stack_inst.navigation_component.destination_reached.connect(_stack_get_new_move_point.bind(small_stack_inst))
		small_stack_inst.state_chart.event_received.connect(_substack_on_event_received.bind(small_stack_inst))
		small_stack_inst.substack_charge_set.connect(_on_substack_charge_set)
		small_stack_inst.target = target
		small_stack_inst.group_size = stack_count
		small_stack_inst.group_idx = i
		spawned_stacks.append(small_stack_inst)
		
		var stack_spawn_tween: Tween = get_tree().create_tween()
		var spawn_pos: Vector3 = self.global_position + (self.global_transform.basis.z * 5).rotated(
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


func _small_stack_hurt(damage: float) -> void:
	health_component.damage(damage)


func _small_stack_dead(stack: CharacterBody3D) -> void:
	_substack_finished(stack)


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
	
	spawned_sub_stacks = await spawn_stacks(3)
	
	state_chart.send_event("start_attack")


func _on_merging_state_entered() -> void:
	await despawn_stacks()
	
	sprite.visible = true
	#navigation_component.enable()
	debug_mesh.visible = true
	self.collision_mask += (pow(2, 2-1) + pow(2, 4-1))
	health_component.show_damage_text = true
	
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


func _on_split_stack_projectiles_attacking_state_entered() -> void:
	trigger_substack_attack("start_small_projectile_attack")


func _on_split_stack_charge_attacking_state_entered() -> void:
	trigger_substack_attack("start_split_rush_attack")


func _on_substack_charge_set(pos: Vector3) -> void:
	self.global_position = pos
