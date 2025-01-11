extends BossCore


func _ready() -> void:
	GRAVITY = 0.0
	super()


func change_phase() -> void:
	var dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases = [
		"start_ranged_attack",
		"start_area_attack"
	]
	if ranged_phase_count == max_sequential_phases:
		possible_phases.erase("start_ranged_attack")
		ranged_phase_count = 0
	if area_phase_count == max_sequential_phases:
		possible_phases.erase("start_area_attack")
		area_phase_count = 0
	
	# If we've somehow exluded all of the possible phases, 
	# the counters have been reset so just call this method again.
	if possible_phases == []:
		change_phase()
		return
	
	# If the player is too close, don't do area attacks
	if dist_to_target <= area_size / 2:
		possible_phases.erase("start_area_attack")
	else:
		#possible_phases.erase("start_area_attack")
		possible_phases.append("start_area_attack")
	
	# If the player is further away, prioritise charges and area attacks
	possible_phases.append("start_ranged_attack")
	possible_phases.append("start_ranged_attack")
	possible_phases.append("start_ranged_attack")
	possible_phases.append("start_area_attack")
	
	var new_phase: String = possible_phases[randi_range(0, possible_phases.size() - 1)]
	state_chart.send_event(new_phase)
