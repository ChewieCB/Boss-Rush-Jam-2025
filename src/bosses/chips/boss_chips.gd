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

#@onready var anim_player: AnimationPlayer = $AnimationPlayer
#@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer


func activate() -> void:
	super()
	navigation_component.follow_target = false
	navigation_component.enable()
	state_chart.send_event("start_phase_1")


func select_attack_phase_1() -> void:
	state_chart.send_event("start_backspin_chip")


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
