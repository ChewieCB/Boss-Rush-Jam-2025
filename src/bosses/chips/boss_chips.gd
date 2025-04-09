extends BossCore
class_name BossChips

var prev_phase
@export var phase_2_health_percentage_trigger: float = 0.5

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

#@onready var anim_player: AnimationPlayer = $AnimationPlayer
#@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer


func activate() -> void:
	super()
	navigation_component.follow_target = false
	navigation_component.enable()
	state_chart.send_event("start_phase_1")


func select_attack_phase_1() -> void:
	#state_chart.send_event("start_backspin_chip")
	state_chart.send_event("split_stack")


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


func _on_form_split_stacks_state_entered() -> void:
	# Hide the main boss body and disable collision
	sprite.visible = false
	debug_mesh.visible = false
	navigation_component.disable()
	# Disable player and projectile collisions
	self.collision_mask -= (pow(2, 2-1) + pow(2, 4-1))
	#collider.set_deferred("disabled",  true)
	hurtbox.set_deferred("monitoring",  false)
	# TODO - prevent damage numbers showing up
	
	spawned_sub_stacks = await spawn_stacks(3)
	
	await get_tree().create_timer(3.0).timeout
	state_chart.send_event("combine_stack")


func _stack_get_new_move_point(stack) -> void:
	var random_pos: Vector3 = NavigationServer3D.map_get_random_point(stack.nav_map_rid, 1, false)
	#draw_debug_sphere(random_pos, 1.0, Color.GREEN)
	stack.navigation_component.set_nav_target_position(random_pos)


func _on_form_split_stacks_state_exited() -> void:
	await despawn_stacks()
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
		spawned_stacks.append(small_stack_inst)
		
		var stack_spawn_tween: Tween = get_tree().create_tween()
		var spawn_pos: Vector3 = self.global_position + (self.global_transform.basis.z * 5).rotated(
			Vector3.UP, 2 * PI / stack_count * (i+1)
		)
		stack_spawn_tween.tween_property(small_stack_inst, "global_position", spawn_pos, stack_spawn_time)
		stack_spawn_tween.parallel().tween_property(small_stack_inst, "scale", Vector3.ONE, stack_spawn_time)
		
		await stack_spawn_tween.finished
		
		_stack_get_new_move_point(small_stack_inst)
		
	
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
	spawned_sub_stacks.erase(stack)
