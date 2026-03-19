extends BossMap

@export var fan_blades: AnimatableBody3D
@export var slot_rollers: Array[AnimatableBody3D]
@export var slot_roller_base_mat: StandardMaterial3D
var slot_rollers_mats: Array[StandardMaterial3D]

var rollers_spinning_active: bool = true
@export var MAX_ROLLER_SPEED: float = 2.5
var slot_roller_speed: float = MAX_ROLLER_SPEED


func _ready() -> void:
	for roller in slot_rollers:
		# Randomize starting UV y-offset
		var _roller_mesh: MeshInstance3D = roller.get_child(0)
		var _roller_mat: StandardMaterial3D = _roller_mesh.get_active_material(1).duplicate()
		#_roller_mat.uv1_offset.y = randi_range(0, 6) * 0.142  # Set to a random icon
		#_roller_mat.uv1_offset.y += randf_range(0.142/2, -0.142/2)  # Nudge it offcenter
		_roller_mesh.set_surface_override_material(1, _roller_mat)
		slot_rollers_mats.append(_roller_mat)
	super()
	boss.slot_icon_chosen.connect(_on_boss_attack_chosen)
	boss.start_slots_spin.connect(_on_boss_slots_spin)


func _physics_process(delta: float) -> void:
	fan_blades.rotate_y(delta)
	
	if rollers_spinning_active:
		slot_roller_speed = lerp(slot_roller_speed, MAX_ROLLER_SPEED, delta)
		for mat in slot_rollers_mats:
			mat.uv1_offset.y -= delta * slot_roller_speed


func _on_boss_attack_chosen(idx: int) -> void:
	rollers_spinning_active = false
	stop_all_rollers(idx)


func _on_boss_slots_spin() -> void:
	rollers_spinning_active = true

func stop_all_rollers(icon_idx: int) -> void:
	slot_roller_speed = 0.0
	#for i in range(slot_rollers.size()):
	for i in range(0, 3):
		_stop_roller(i, icon_idx)
	
	return


func _stop_roller(idx: int, icon_idx: int) -> void:
	var roller = slot_rollers[idx]
	var roller_mat = slot_rollers_mats[idx]
	
	await get_tree().create_timer(randf_range(0.15, 0.55), false).timeout
	
	# Get the nearest value divisible by 0.142 as the goal pos
	var current_revolutions := int(roller_mat.uv1_offset.y / -0.142)
	var goal_y: float = snappedf(roller_mat.uv1_offset.y, -0.142 * icon_idx * current_revolutions)
	
	# Tween the roller to the goal point
	var stop_tween := get_tree().create_tween()
	stop_tween.tween_property(
		roller_mat, "uv1_offset:y", goal_y, 0.55
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	
	await stop_tween.finished
	
	return
	
