extends BossCore
class_name BossSlots

signal charge_lined_up

@onready var projectile_marker_pivot: Node3D = $MarkerPivot
@onready var projectile_spawn_marker: Marker3D = $MarkerPivot/Marker3D
@onready var slot_icons_parent: Node3D = $SlotIcons

var prev_phase

@export_group("Movement")
@export var DESIRED_DISTANCE: float = 10.0
@export var desired_distance: float = DESIRED_DISTANCE
@export var DESIRED_HEIGHT: float = 3.1
var desired_height: float = DESIRED_HEIGHT
@export var DROP_FACTOR: float = 1.0
var drop_factor: float = DROP_FACTOR
@export_subgroup("Orbiting")
@export var angle_speed = 1.0  # radians/second
@export var orbit_angle = 0.0  # track this over time
@export_group("Spin Slots")
var next_attack: String
var next_attack_idx: int
var next_attack_texture: Texture
@export_subgroup("Slot Icons")
@export var icon_coin: Texture
@export var icon_bell: Texture
@export var icon_bar: Texture
@export var icon_diamond: Texture
@export var icon_cherry: Texture
@onready var slot_icons: Array[Texture] = [
	icon_coin, icon_bell, icon_bar, icon_diamond, icon_cherry
]
@export_group("Coin Burst")
@export var coin_projectile: PackedScene
@export var num_bursts: int = 1
@export var delay_between_burst: float = 0.6
@export_group("Bell Drop")
@export var bell_scene: PackedScene
@export var drop_shadow_material: Material
@export_group("Lever Swipe")
@export var swipe_damage: float = 5.0
@export var swipe_knockback: float = 50.0
@export var swipe_dodge_speed: float = 10.0
@export_group("Charge")
@export var charge_damage: float = 10.0
@export var charge_knockback: float = 50.0
@export var min_charge_distance: float = 10.0
var charge_locked: bool = false


func activate() -> void:
	super()
	state_chart.send_event("start_phase_1")


func _physics_process(delta: float) -> void:
	super(delta)
	projectile_marker_pivot.look_at(target.global_position)
	slot_icons_parent.look_at(target.global_position)
	
	if hurtbox.monitoring:
		if target in hurtbox.get_overlapping_bodies():
			# TODO - add cooldown
			state_chart.send_event("start_lever_attack")
	
	if self.global_position.y > desired_height:
		self.global_position.y -= delta * drop_factor
	elif self.global_position.y < desired_height:
		self.global_position.y += delta * drop_factor


func select_attack_phase_1() -> void:
	var possible_phases = [
		# Tuples of event string and icon index 
		#["start_coin_attack", 0],
		#["start_bell_attack", 1],
		["start_charge_attack", 2],
		#"start_lever_attack", # TODO - only triggers in close range as a reaction
	]
	#if prev_phase:
		#possible_phases.erase(prev_phase)
	# TODO - add random weighting
	var new_phase = possible_phases.pick_random()
	prev_phase = new_phase
	next_attack = new_phase[0]
	next_attack_idx = new_phase[1]
	state_chart.send_event("start_spin_slots")


func _on_hurtbox_body_entered(body: Node3D) -> void:
	pass


### ATTACK PHASES --------------------------------
#### INACTIVE
func _on_phase_inactive_state_entered() -> void:
	debug_state_label.text = "Inactive"
	sprite.modulate = Color.DIM_GRAY

func _on_phase_inactive_state_exited() -> void:
	sprite.modulate = Color.WHITE


#### PHASE 1

func _on_phase_1_state_entered() -> void:
	current_phase = 1
	select_attack()


func orbit_player(delta) -> void:
	orbit_angle += angle_speed * delta
	# offset in XZ-plane
	var offset_x = cos(orbit_angle) * desired_distance
	var offset_z = sin(orbit_angle) * desired_distance
	var orbit_pos = target.global_position + Vector3(offset_x, 0, offset_z)
	# Pathfind to orbit_pos
	navigation_component.set_nav_target_position(orbit_pos)


#### SPIN SLOTS
# TODO - Telegraph before each attack with animation

func _on_spin_slots_state_physics_processing(delta: float) -> void:
	orbit_player(delta)

func _on_spin_slots_targeting_state_entered() -> void:
	debug_state_label.text = "Spin Slots | Targeting"
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	#await get_tree().create_timer(2.0).timeout
	state_chart.send_event("start_slots")

func _on_spin_slots_spinning_state_entered() -> void:
	debug_state_label.text = "Spin Slots | Spinning"
	for slot_sprite in slot_icons_parent.get_children():
		slot_sprite.texture = slot_icons.pick_random()
	
	next_attack_texture = slot_icons[next_attack_idx]
	
	# Spinning
	for i in range(20):
		for slot_sprite in slot_icons_parent.get_children():
			var sprite_idx: int = slot_icons.find(slot_sprite.texture) + 1
			var new_idx: int = wrapi(sprite_idx, 0, slot_icons.size() - 1) 
			slot_sprite.texture = slot_icons[new_idx]
		await get_tree().create_timer(0.1).timeout
	# Settle each roller one by one
	for i in range(slot_icons_parent.get_child_count()):
		while not slot_icons_parent.get_child(i).texture == next_attack_texture:
			for j in range(i, slot_icons_parent.get_child_count()):
				var slot_sprite = slot_icons_parent.get_child(j)
				var sprite_idx: int = slot_icons.find(slot_sprite.texture) + 1
				var new_idx: int = wrapi(sprite_idx, 0, slot_icons.size() - 1) 
				slot_sprite.texture = slot_icons[new_idx]
	
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	
	state_chart.send_event("attack_start")
	state_chart.send_event("end_slots")

func _on_spin_slots_recover_state_entered() -> void:
	debug_state_label.text = "Spin Slots | Recovering"
	state_chart.send_event("attack_end")
	
	#await get_tree().create_timer(attack_recovery_time).timeout
	
	state_chart.send_event("cooldown_end")
	state_chart.send_event(next_attack)
	state_chart.send_event("end_recovery")


#### COIN BURST - RICOCHET IN PHASE 2
# 3 Coins on rollers
# TODO - Rapid fire coin projectiles 

func fire_projectile(projectile_scene: PackedScene) -> BaseProjectile:
	var projectile := projectile_scene.instantiate()
	get_tree().root.get_child(0).add_child(projectile)
	projectile.global_position = projectile_spawn_marker.global_position
	projectile.look_at(target.global_position, Vector3.UP)
	SoundManager.play_sound(TEMP_sfx_projectile)
	return projectile


func _on_coin_projectiles_state_physics_processing(delta: float) -> void:
	orbit_player(delta)


func _on_coin_projectiles_targeting_state_entered() -> void:
	debug_state_label.text = "Coin Burst | Targeting"
	
	state_chart.send_event("start_moving")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.8).timeout
	state_chart.send_event("start_shooting")


func _on_coin_projectiles_shooting_state_entered() -> void:
	debug_state_label.text = "Coin Burst | Shooting"
	
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	
	for i in num_bursts:
		for j in projectiles_per_phase:
			await get_tree().create_timer(delay_per_projectile).timeout
			fire_projectile(coin_projectile)
		await get_tree().create_timer(delay_between_burst).timeout
	
	state_chart.send_event("stop_shooting")


func _on_coin_projectiles_recover_state_entered() -> void:
	debug_state_label.text = "Coin Burst | Recovering"
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	select_attack()
	state_chart.send_event("end_recovery")


#### BELL DROP
# 3 Bells on rollers
# TODO - Single large AoE bell drops from ceiling

func drop_shadow(
	target_pos: Vector3,
	max_radius: float, 
	drop_time: float = 1.0, 
	callback: Callable = func(): pass
) -> void:
	var debug_mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	
	# Generate a visual
	get_tree().get_root().add_child(debug_mesh_instance)
	
	debug_mesh_instance.mesh = mesh
	debug_mesh_instance.cast_shadow = false
	
	# Snap to floor
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		target_pos, 
		target_pos - Vector3(0, 100, 0),
		pow(2, 1-1) + pow(2, 7-1)
	)
	var result = space_state.intersect_ray(query)
	if result:
		target_pos.y = result.position.y
	
	debug_mesh_instance.global_position = target_pos
	
	mesh.bottom_radius = 0.0
	mesh.top_radius = 0.0
	mesh.height = 0.5
	mesh.material = drop_shadow_material
	
	var shadow_tween = get_tree().create_tween()
	
	shadow_tween.tween_property(debug_mesh_instance, "mesh:bottom_radius", max_radius, drop_time)#.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	shadow_tween.parallel().tween_property(debug_mesh_instance, "mesh:top_radius", max_radius, drop_time)#.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	shadow_tween.tween_callback(debug_mesh_instance.queue_free)


func _on_bell_drop_state_entered() -> void:
	desired_distance = 35.0

func _on_bell_drop_state_physics_processing(delta: float) -> void:
	orbit_player(delta)

func _on_bell_drop_state_exited() -> void:
	desired_distance = DESIRED_DISTANCE


func _on_bell_drop_targeting_state_entered() -> void:
	debug_state_label.text = "Bell Drop | Targeting"
	
	state_chart.send_event("start_moving")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(1.2).timeout
	state_chart.send_event("start_drop")


func _on_bell_drop_dropping_state_entered() -> void:
	debug_state_label.text = "Bell Drop | Dropping"
	
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	
	# TODO - spawn shadow/mesh to show AoE, grow in size as it drops
	drop_shadow(target.global_position, 8.0, 4.0)
	# TODO - spawn mesh that drops down and crashes, dealing damage
	#
	state_chart.send_event("finish_drop")


func _on_bell_drop_recover_state_entered() -> void:
	debug_state_label.text = "Bell Drop | Recovering"
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	select_attack()
	state_chart.send_event("end_recovery")


#### LEVER SWIPE
# TODO - Whacks player with slot level arm if they get too close
func _on_lever_swipe_targeting_state_entered() -> void:
	debug_state_label.text = "Lever Swipe | Targeting"
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	hurtbox.set_deferred("monitoring", true)
	state_chart.send_event("start_swipe")


func _on_lever_swipe_swipe_state_entered() -> void:
	debug_state_label.text = "Lever Swipe | Swipe"
	
	state_chart.send_event("attack_start")
	sprite.modulate = Color.ORANGE
	
	# Hit player in melee range and flee away
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(swipe_damage)
		hurtbox.set_deferred("monitoring", false)
		# TODO - fix this knockback
		var knockback_vector = -self.global_basis.z * swipe_knockback
		target.velocity.x = 0
		target.velocity.z = 0
		target.velocity += knockback_vector
		
		var dodge_vector = self.global_basis.z * swipe_dodge_speed
		
		# Make sure we don't dodge into a wall
		var space_state = get_world_3d().direct_space_state
		var dodge_collisions = []
		for angle in [0, PI/2, PI, 3 * PI/2]:
			dodge_vector = dodge_vector.rotated(Vector3.UP, angle)
			var query = PhysicsRayQueryParameters3D.create(
				self.global_position, 
				self.global_position + dodge_vector,
				pow(2, 1-1) + pow(2, 7-1)
			)
			var result = space_state.intersect_ray(query)
			if result:
				dodge_collisions.append(dodge_vector)
				continue
			else:
				break
		
		# If all options collide, pick the furthest direction to dodge in
		if dodge_collisions.size() == 4:
			dodge_collisions.sort_custom(
				func(a, b):
					var a_dist: float = self.global_position.distance_to(a)
					var b_dist: float = self.global_position.distance_to(b)
					if a_dist > b_dist:
						return true
					return false
			)
			dodge_vector = dodge_collisions.front()
		
		self.velocity.x = dodge_vector.x
		self.velocity.z = dodge_vector.z
	
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color.WHITE
	
	state_chart.send_event("end_swipe")


func _on_lever_swipe_recover_state_entered() -> void:
	debug_state_label.text = "Lever Swipe | Recovery"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	select_attack()
	state_chart.send_event("end_recovery")




#### DIAMOND SCATTERSHOT
# 3 Diamonds on rollers
# TODO - Homing diamond projectile, fired in a spiral/radial pattern from boss

#### CHARGE/HEADBUTT
# 3 BARs on rollers
# TODO - Existing charge behaviour
func _on_charge_targeting_state_entered() -> void:
	debug_state_label.text = "Charge | Targeting"
	
	navigation_component.enable()
	desired_distance = min_charge_distance * 2
	MAX_SPEED *= 1.6
	charge_locked = false
	state_chart.send_event("start_moving")
	
	await charge_lined_up
	#velocity = Vector3.ZERO
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time * 2).timeout
	state_chart.send_event("start_charge_attack")

func _on_charge_targeting_state_physics_processing(delta: float) -> void:
	if not charge_locked:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			self.global_position, 
			target.global_position,
			pow(2, 1-1) + pow(2, 2-1) + pow(2, 7-1)
		)
		var result =  space_state.intersect_ray(query)
		
		if self.global_position.distance_to(target.global_position) >= min_charge_distance:
			if result == null or result.collider == target:
				state_chart.send_event("stop_moving")
				charge_lined_up.emit()
				charge_locked = true
				return
		
		orbit_player(delta)

func _on_charge_charging_state_entered() -> void:
	debug_state_label.text = "Charge | Charging"
	state_chart.send_event("attack_start")
	
	MAX_SPEED /= 1.6
	desired_height = 0.2
	drop_factor = 12.0
	
	navigation_component.disable()
	hurtbox.set_deferred("monitoring", true)
	hurtbox.body_entered.connect(_on_charge_collision)
	var charge_dir = self.global_position.direction_to(target.global_position)
	var charge_impulse = self.global_position.distance_to(target.global_position) * charge_force
	velocity += charge_dir * charge_impulse
	SoundManager.play_sound(TEMP_sfx_charge)

func _on_charge_collision(body: Node3D) -> void:
	if body == target:
		velocity = Vector3.ZERO
		body.health_component.damage(charge_damage)
		hurtbox.body_entered.disconnect(_on_charge_collision)
		hurtbox.set_deferred("monitoring", false)

func _on_charge_charging_state_physics_processing(delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, 0.05)
	velocity.z = lerp(velocity.z, 0.0, 0.05)

	if abs(velocity.x) < 0.1 and abs(velocity.z) < 0.1:
		velocity.x = 0
		velocity.z = 0
		state_chart.send_event("end_charge_attack")
	elif is_on_floor():
		state_chart.send_event("end_charge_attack")

func _on_charge_recover_state_entered() -> void:
	debug_state_label.text = "Charge | Recovering"
	state_chart.send_event("attack_end")
	navigation_component.enable()
	
	desired_distance = DESIRED_DISTANCE
	desired_height = DESIRED_HEIGHT
	drop_factor = DROP_FACTOR
	
	hurtbox.set_deferred("monitoring", false)
	if hurtbox.body_entered.is_connected(_on_charge_collision):
		hurtbox.body_entered.disconnect(_on_charge_collision)
	
	await get_tree().create_timer(attack_recovery_time).timeout
	
	state_chart.send_event("cooldown_end")
	select_attack()
	state_chart.send_event("end_recovery")


#### CHERRY BOMB
# 3 Cherries on rollers
# TODO - Bouncing explosive projectiles







#### CHASE PLAYER



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
