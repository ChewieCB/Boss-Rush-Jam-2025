extends BossCore
class_name BossTest


func _ready() -> void:
	super()
	ranged_move_points = get_tree().get_nodes_in_group("boss_ranged_marker")
	area_move_points = get_tree().get_nodes_in_group("boss_area_marker")


func activate() -> void:
	super()
	select_attack()


### ATTACK PHASES --------------------------------
#### INACTIVE
func _on_phase_inactive_state_entered() -> void:
	debug_state_label.text = "Inactive"
	sprite.modulate = Color.DIM_GRAY


#### CHASE PLAYER
func _on_phase_target_player_state_entered() -> void:
	sprite.modulate = Color.WHITE
	debug_state_label.text = "Chase | Targeting"
	
	state_chart.send_event("start_targeting")
	await get_tree().create_timer(2.0).timeout
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	state_chart.send_event("charge_player")

func _on_phase_chase_player_charge_state_entered() -> void:
	SoundManager.play_sound(TEMP_sfx_charge)
	sprite.modulate = Color.ORANGE
	debug_state_label.text = "Chase | Charging"
	state_chart.send_event("start_charge")

func _on_phase_chase_player_recover_state_entered() -> void:
	sprite.modulate = Color.YELLOW
	debug_state_label.text = "Chase | Recovering"
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	
	state_chart.send_event("cooldown_end")
	charge_phase_count += 1
	select_attack()
	state_chart.send_event("end_recovery")


#### RANGED PROJECTILES
func _on_phase_ranged_projectiles_move_to_center_state_entered() -> void:
	sprite.modulate = Color.YELLOW
	debug_state_label.text = "Projectiles | Moving"
	
	MAX_SPEED *= 2
	
	var valid_move_points = ranged_move_points.duplicate()
	valid_move_points.sort_custom(
		func(a, b):
			var a_dist: float = self.global_position.distance_to(a.global_position)
			var b_dist: float = self.global_position.distance_to(b.global_position)
			if a_dist < b_dist:
				return true
			return false
	)
	valid_move_points.pop_front()
	
	cached_target = target
	if valid_move_points:
		target = valid_move_points[0]
		state_chart.send_event("start_moving")
		
		await navigation_component.nav_agent.navigation_finished
		state_chart.send_event("start_projectiles")
	else:
		select_attack()

func _on_phase_ranged_projectiles_move_to_center_state_exited() -> void:
	target = cached_target
	MAX_SPEED /= 2

func _on_phase_ranged_projectiles_fire_projectiles_state_entered() -> void:
	sprite.modulate = Color.ORANGE
	debug_state_label.text = "Projectiles | Firing"
	
	state_chart.send_event("start_targeting")
	
	for i in projectiles_per_phase:
		await get_tree().create_timer(delay_per_projectile).timeout
		var projectile: TestProjectile = projectile_scene.instantiate()
		get_parent().get_parent().add_child(projectile)
		projectile.global_position = self.global_position + Vector3(0, 3, 0)
		projectile.look_at(target.global_position, Vector3.UP)
		SoundManager.play_sound(TEMP_sfx_projectile)
	
	await get_tree().create_timer(delay_per_projectile).timeout
	state_chart.send_event("end_projectiles")

func _on_phase_ranged_projectiles_recover_state_entered() -> void:
	sprite.modulate = Color.YELLOW
	debug_state_label.text = "Projectiles | Recovering"
	
	state_chart.send_event("attack_end")
	projectile_round_count += 1
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	if projectile_round_count < max_projectile_rounds:
		var fire_again_chance: float = randf()
		if fire_again_chance < 0.55:
			state_chart.send_event("fire_again")
			return
	
	ranged_phase_count += 1
	select_attack()
	state_chart.send_event("change_position")

#### AREA DENIAL
func _on_phase_area_denial_move_to_center_state_entered() -> void:
	sprite.modulate = Color.BLUE_VIOLET
	debug_state_label.text = "Area | Moving"
	
	MAX_SPEED *= 2
	cached_target = target
	# TODO - add code to vary move points if more than one
	target = area_move_points[0]
	state_chart.send_event("start_moving")
	await navigation_component.nav_agent.navigation_finished
	
	state_chart.send_event("start_area_attack")

func _on_phase_area_denial_move_to_center_state_exited() -> void:
	target = cached_target
	MAX_SPEED /= 2
	state_chart.send_event("stop_moving")

func _on_phase_area_denial_spawn_damage_areas_state_entered() -> void:
	sprite.modulate = Color.ORANGE
	debug_state_label.text = "Area | Spawning"
	var angle_increment: float =  2 * PI / areas_per_phase
	var initial_point: Vector3 = target.global_position
	initial_point.y = self.global_position.y
	
	SoundManager.play_sound(TEMP_sfx_area_1)
	for i in areas_per_phase:
		var angle = angle_increment * i
		var dir = initial_point - self.global_position
		var adjusted_dir = dir.rotated(Vector3.UP, angle)
		var area_pos: Vector3 = self.global_position + adjusted_dir
		
		if delay_per_area > 0.0:
			await get_tree().create_timer(delay_per_area * i).timeout
		
		# Generate a collider
		var area_collider := Area3D.new()
		var area_collider_shape := CollisionShape3D.new()
		var collider_shape := CylinderShape3D.new()
		collider_shape.radius = area_size / 2
		collider_shape.height = 64.0
		area_collider_shape.shape = collider_shape
		area_collider.add_child(area_collider_shape)
		area_collider.collision_layer = 0
		area_collider.collision_mask = 2  # Player
		area_collider.monitoring = true
		
		get_tree().get_root().add_child(area_collider)
		
		area_collider.global_position = area_pos
		
		var debug_mesh_instance = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		var sphere_mat = ORMMaterial3D.new()
		
		spawned_area_objects.append([area_collider, debug_mesh_instance])
		
		# Generate a visual
		get_tree().get_root().add_child(debug_mesh_instance)
		
		debug_mesh_instance.mesh = mesh
		debug_mesh_instance.cast_shadow = false
		debug_mesh_instance.global_position = area_pos
		
		mesh.bottom_radius = 0.01
		mesh.top_radius = 0.01
		mesh.height = 0.5
		mesh.material = sphere_mat
		
		sphere_mat.transparency = true
		sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere_mat.cull_mode = 2
		sphere_mat.albedo_color = Color(Color.RED, 0.25)
		
		# Animate the visual
		var tween = get_tree().create_tween()
		tween.tween_property(mesh, "bottom_radius", area_size / 2, area_spawn_time)
		tween.parallel().tween_property(mesh, "top_radius", area_size / 2, area_spawn_time)
		tween.tween_callback(
			func():
				var height_tween = get_tree().create_tween()
				# Check if player is in area
				#area_collider.monitoring = true
				var bodies = area_collider.get_overlapping_bodies()
				for body in bodies:
					body.health_component.damage(area_damage) 
				height_tween.tween_property(mesh, "height", 64.0 / 2, 0.2).set_trans(Tween.TRANS_EXPO)
				height_tween.tween_callback(
					func():
						SoundManager.play_sound(TEMP_sfx_area_2)
						debug_mesh_instance.queue_free()
						area_collider.queue_free()
						areas_finished += 1
				)
		)


func _on_phase_area_denial_recover_state_entered() -> void:
	sprite.modulate = Color.YELLOW
	debug_state_label.text = "Area | Recovering"
	
	state_chart.send_event("attack_end")
	area_round_count += 1
	
	if area_round_count < max_area_rounds:
		var fire_again_chance: float = randf()
		if fire_again_chance < 0.85:
			state_chart.send_event("fire_again")
			return
	
	area_phase_count += 1
	await get_tree().create_timer(attack_recovery_time).timeout
	select_attack()
	state_chart.send_event("change_position")
