extends BossCore
class_name BossSlots

signal charge_lined_up
signal desired_height_reached

@onready var projectile_marker_pivot: Node3D = $MarkerPivot
@onready var projectile_spawn_marker: Marker3D = $MarkerPivot/Marker3D
@onready var slot_icons_parent: Node3D = $Sprite3D/SlotIcons

var prev_phase
@export var phase_2_health_percentage_trigger: float = 0.5

@export_group("Movement")
@export var DESIRED_DISTANCE: float = 10.0
@export var desired_distance: float = DESIRED_DISTANCE
@export var DESIRED_HEIGHT: float = 3.1
var desired_height: float = DESIRED_HEIGHT
@export var DROP_FACTOR: float = 1.0
var drop_factor: float = DROP_FACTOR
@export_subgroup("Orbiting")
@export var angle_speed: float = 1.0 # radians/second
@export var orbit_angle: float = 0.0 # track this over time
@export var orbit_radius: float = 20.0

@export_group("Attacks")
@export_subgroup("Spin Slots")
var next_attack: String
var next_attack_idx: int
var next_attack_texture: Texture
## Determines how long the slots roll for
@export var SLOT_TICKS: int = 20
var slot_ticks: int = SLOT_TICKS
# SFX
@export var sfx_slot_roll_long: AudioStream # For phase 1
@export var sfx_slot_roll_short: AudioStream # For phase 2
@export var sfx_slot_roll_ding: AudioStream
@export var sfx_slot_roll_coins: AudioStream
@export var sfx_slot_pick_coin: AudioStream
@export var sfx_slot_pick_bell: AudioStream
@export var sfx_slot_pick_bar: AudioStream
@export var sfx_slot_pick_diamond: AudioStream
@export var sfx_slot_pick_cherry: AudioStream
@onready var sfx_slot_picks: Array[AudioStream] = [
	sfx_slot_pick_coin,
	sfx_slot_pick_bell,
	sfx_slot_pick_bar,
	sfx_slot_pick_diamond,
	sfx_slot_pick_cherry
]

@export_subgroup("Slot Icons")
@export var icon_coin: Texture
@export var icon_bell: Texture
@export var icon_bar: Texture
@export var icon_diamond: Texture
@export var icon_cherry: Texture
@onready var slot_icons: Array[Texture] = [
	icon_coin, icon_bell, icon_bar, icon_diamond, icon_cherry
]
@onready var slot_decals: Array[Node] = get_tree().get_root().get_child(3).find_children("*", "SlotRollerDecal")

@export_subgroup("Coin Burst")
@export var coin_projectile: PackedScene
@export var coin_shots_per_burst: int = 8
@export var num_bursts: int = 1
@export var delay_between_burst: float = 0.6
# SFX
@export var sfx_coin_shot: Array[AudioStream]

@export_subgroup("Bell Drop")
@export var bell_scene: PackedScene
@export var bell_aoe_marker_ring: CompressedTexture2D
@export var bell_aoe_marker_arrows: CompressedTexture2D
@export var drop_shadow_material: Material
@export var bell_shadow_time: float = 1.4
@export var bell_spawn_area_radius: float = 28.0
@export var bells_to_spawn: int = 6
var bell_spawn_points: Array = []
# SFX
#@export var sfx_bell_Spawn: Array[AudioStream]  - TODO: Get spawn sounds
# Moved to the bell objects
@export var sfx_bell_windup: Array[AudioStream]
@export var sfx_bell_impact: Array[AudioStream]

@export_subgroup("Lever Swipe")
@export var swipe_damage: float = 5.0
@export var swipe_knockback: float = 50.0
@export var swipe_dodge_speed: float = 10.0
# SFX
@export var sfx_lever_swipe: Array[AudioStream]

@export_subgroup("Charge")
@export var charge_damage: float = 10.0
@export var charge_knockback: float = 50.0
@export var min_charge_distance: float = 10.0
var charge_locked: bool = false
# SFX
@export var sfx_charge: Array[AudioStream]
@export var sfx_charge_impact: Array[AudioStream]

@export_subgroup("Homing Diamonds")
@export var diamond_projectile: PackedScene
@export var diamond_shots_per_attack: int = 12
@export var diamond_shot_time: float = 1.3
# SFX
@export var sfx_diamond_shot: Array[AudioStream]

@export_subgroup("Cherry Bombs")
@export var bomb_projectile: PackedScene
@export var bombs_per_attack: int = 5
@export var bomb_drop_delay: float = 0.4
@export var bomb_fuse_time: float = 2.5
@export var bomb_impulse: float = 100000.0
@export var max_drop_distance: float = 20.0
# SFX
# Moved to the bomb objects
@export var sfx_bomb_launch: Array[AudioStream]
#@export var sfx_bomb_bounce: Array[AudioStream]
#@export var sfx_bomb_explode: Array[AudioStream]

@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer


func activate() -> void:
	super()
	navigation_component.follow_target = false
	navigation_component.enable()
	state_chart.send_event("start_phase_1")


func _physics_process(delta: float) -> void:
	super(delta)
	
	if target:
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
	
	if abs(self.global_position.y - desired_height) < 0.1:
		desired_height_reached.emit()


func select_attack_phase_1() -> void:
	var possible_phases = [
		# Tuples of event string and icon windex 
		["start_coin_attack", 0],
		["start_bell_attack", 1],
		["start_charge_attack", 2],
	]
	if prev_phase:
		possible_phases.erase(prev_phase)
	# TODO - add random weighting
	var new_phase = possible_phases.pick_random()
	prev_phase = new_phase
	next_attack = new_phase[0]
	next_attack_idx = new_phase[1]
	state_chart.send_event("start_spin_slots")


func select_attack_phase_2() -> void:
	var possible_phases = [
		# Tuples of event string and icon windex 
		["start_bell_attack", 1],
		["start_charge_attack", 2],
		["start_diamond_attack", 3],
		["start_bomb_attack", 4],
	]
	if prev_phase:
		possible_phases.erase(prev_phase)
	# TODO - add random weighting
	var new_phase = possible_phases.pick_random()
	prev_phase = new_phase
	next_attack = new_phase[0]
	next_attack_idx = new_phase[1]
	state_chart.send_event("start_spin_slots")


func _on_health_changed(new_health: float, prev_health: float) -> void:
	super(new_health, prev_health)
	if new_health < health_component.max_health * phase_2_health_percentage_trigger:
		state_chart.send_event("start_phase_2")


func _on_died() -> void:
	super ()
	anim_player.stop()
	set_physics_process(false)
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position:y", -0.3, 1.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN_OUT)

func _on_hurtbox_body_entered(_body: Node3D) -> void:
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


func orbit_player(delta: float) -> void:
	orbit_angle += angle_speed * delta
	# offset in XZ-plane
	var offset_x = cos(orbit_angle) * desired_distance
	var offset_z = sin(orbit_angle) * desired_distance
	var orbit_pos = target.global_position + Vector3(offset_x, 0, offset_z)
	# Pathfind to orbit_pos
	navigation_component.set_nav_target_position(orbit_pos)


func orbit_towards_player(
	delta: float, approach_speed: float = 1.0, min_radius: float = 10.0
) -> void:
	orbit_angle += angle_speed * delta
	
	orbit_radius -= approach_speed * delta
	if min_radius:
		orbit_radius = max(orbit_radius, min_radius)
	
	# offset in XZ-plane
	var offset_x = cos(orbit_angle) * orbit_radius
	var offset_z = sin(orbit_angle) * orbit_radius
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
	state_chart.send_event("start_slots")

func _on_spin_slots_spinning_state_entered() -> void:
	debug_state_label.text = "Spin Slots | Spinning"
	for slot_sprite in slot_icons_parent.get_children():
		slot_sprite.texture = slot_icons.pick_random()
	
	next_attack_texture = slot_icons[next_attack_idx]
	
	# Spinning
	sfx_player.stream = sfx_slot_roll_long if current_phase == 1 else sfx_slot_roll_short
	sfx_player.play()
	
	for i in range(slot_ticks):
		for slot_sprite in slot_icons_parent.get_children():
			var sprite_idx: int = slot_icons.find(slot_sprite.texture) + 1
			var new_idx: int = wrapi(sprite_idx, 0, slot_icons.size() - 1)
			slot_sprite.texture = slot_icons[new_idx]
			#for decal in slot_decals:
				#decal.mesh.material.albedo_texture = slot_icons[new_idx]
		await get_tree().create_timer(0.1).timeout
	# Settle each roller one by one
	for i in range(slot_icons_parent.get_child_count()):
		while not slot_icons_parent.get_child(i).texture == next_attack_texture:
			for j in range(i, slot_icons_parent.get_child_count()):
				var slot_sprite = slot_icons_parent.get_child(j)
				var sprite_idx: int = slot_icons.find(slot_sprite.texture) + 1
				var new_idx: int = wrapi(sprite_idx, 0, slot_icons.size())
				slot_sprite.texture = slot_icons[new_idx]
	
	#for decal in slot_decals:
		#decal.mesh.material.albedo_texture = slot_icons[next_attack_idx]
	
	sfx_player.stop()
	var choice_sfx: AudioStream = sfx_slot_picks[next_attack_idx]
	sfx_player.stream = choice_sfx
	sfx_player.play()
	
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
# Rapid fire coin projectiles 


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
		for j in coin_shots_per_burst:
			await get_tree().create_timer(delay_per_projectile).timeout
			fire_projectile(coin_projectile, projectile_spawn_marker.global_position, sfx_coin_shot)
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
# Single large AoE bell drops from ceiling
func drop_shadow(
	target_pos: Vector3,
	max_radius: float,
	drop_time: float = 3.5,
	_callback: Callable = func(): pass
) -> void:
	# Snap to floor
	#draw_debug_sphere(target_pos, 1.0, Color.YELLOW)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		target_pos,
		target_pos - Vector3(0, 20, 0),
		int(pow(2, 1 - 1))
	)
	var result = space_state.intersect_ray(query)
	if result:
		target_pos.y = result.position.y
		#draw_debug_sphere(target_pos, 1.0, Color.PURPLE)
	
	# AoE decal
	var aoe_tween: Tween = get_tree().create_tween()
	var decal_ring := Decal.new()
	decal_ring.texture_albedo = bell_aoe_marker_ring
	decal_ring.size = Vector3(0, 1, 0)
	get_parent().get_parent().add_child(decal_ring)
	decal_ring.global_position = target_pos
	
	var decal_arrows := Decal.new()
	decal_arrows.texture_albedo = bell_aoe_marker_arrows
	decal_arrows.size = Vector3(0, 1, 0)
	get_parent().get_parent().add_child(decal_arrows)
	decal_arrows.global_position = target_pos
	
	aoe_tween.tween_property(decal_ring, "size", Vector3(max_radius * 2, 1, max_radius * 2), drop_time * 0.75)
	aoe_tween.parallel().tween_property(decal_arrows, "size", Vector3(max_radius * 2, 1, max_radius * 2), drop_time)
	aoe_tween.parallel().tween_property(decal_arrows, "rotation_degrees:y", 360, drop_time)
	aoe_tween.chain().tween_callback(_spawn_bell.bind(target_pos, max_radius, [decal_arrows, decal_ring]))
	aoe_tween.chain().tween_property(decal_arrows, "size", Vector3.ZERO, 1.04)  # Based on bell sfx sample timing


func _cleanup_aoe_decals(decals_to_remove: Array) -> void:
	for decal in decals_to_remove:
		decal.queue_free()


func _spawn_bell(pos: Vector3, size: float, decals: Array) -> void:
	var bell = spawn_bell(pos, size)
	await bell.destroyed
	_cleanup_aoe_decals(decals)


func spawn_bell(pos: Vector3, size: float) -> Bell:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		pos,
		pos + Vector3(0, 400, 0),
		int(pow(2, 1 - 1)),
	)
	var result = space_state.intersect_ray(query)
	if result:
		pos.y = result.position.y
	
	var bell: Bell = bell_scene.instantiate()
	bell.global_position = pos
	get_tree().root.get_child(7).add_child(bell)
	bell.mesh.scale *= size
	bell.collider.shape.radius = size
	bell.collider.shape.height = size * 2
	bell.collider.position.y = size / 2
	bell.hurtbox_collider.shape.radius = size
	bell.hurtbox_collider.shape.height = size * 2
	bell.hurtbox_collider.position.y = size / 2
	bell.drop()
	
	return bell


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
	
	# Get a bunch of evenly distributed points clamped to the navmesh
	bell_spawn_points = Poisson.generate_points_for_circle(
		Vector2.ZERO,
		bell_spawn_area_radius,
		30,
		15,
		Vector2(target.global_position.x, target.global_position.z),
		bells_to_spawn,
	)
	bell_spawn_points.insert(0, Vector2(target.global_position.x, target.global_position.z))
	state_chart.send_event("finish_drop")


func _on_bell_drop_dropping_state_exited() -> void:
	for point in bell_spawn_points:
		var spawn := Vector3(point.x, 2.5, point.y)
		# Spawn shadow/mesh to show AoE, grow in size as it drops
		drop_shadow(spawn, 6.0, bell_shadow_time)
		await get_tree().create_timer(0.2).timeout


func _on_bell_drop_recover_state_entered() -> void:
	debug_state_label.text = "Bell Drop | Recovering"
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	select_attack()
	state_chart.send_event("end_recovery")


#### LEVER SWIPE
# Whacks player with slot level arm if they get too close
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
	
	sfx_player.stream = sfx_lever_swipe.pick_random()
	sfx_player.play()
	
	# Hit player in melee range and flee away
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(swipe_damage)
		hurtbox.set_deferred("monitoring", false)
		# TODO - fix this knockback
		var knockback_vector = - self.global_basis.z * swipe_knockback
		target.velocity.x = 0
		target.velocity.z = 0
		target.velocity += knockback_vector
		
		var dodge_vector = self.global_basis.z * swipe_dodge_speed
		
		# Make sure we don't dodge into a wall
		var space_state = get_world_3d().direct_space_state
		var dodge_collisions = []
		for angle in [0, PI / 2, PI, 3 * PI / 2]:
			dodge_vector = dodge_vector.rotated(Vector3.UP, angle)
			var query = PhysicsRayQueryParameters3D.create(
				self.global_position,
				self.global_position + dodge_vector,
				int(pow(2, 1 - 1) + pow(2, 7 - 1))
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
	sfx_player.stream = null
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	select_attack()
	state_chart.send_event("end_recovery")


#### PHASE 2
#
func _on_phase_2_state_entered() -> void:
	current_phase = 2
	slot_ticks /= 4
	select_attack()


#### DIAMOND SCATTERSHOT
# 3 Diamonds on rollers
# Homing diamond projectile, fired in a spiral/radial pattern from boss
func _on_homing_projectiles_state_physics_processing(delta: float) -> void:
	orbit_player(delta)


func _on_homing_projectiles_targeting_state_entered() -> void:
	debug_state_label.text = "Diamond Scattershot | Targeting"
	
	state_chart.send_event("start_moving")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.8).timeout
	state_chart.send_event("start_shooting")


func _on_homing_projectiles_shooting_state_entered() -> void:
	debug_state_label.text = "Diamond Scattershot | Shooting"
	# Fire out projctiles in a spiral, each projectile homes in on the player
	for i in range(diamond_shots_per_attack):
		await get_tree().create_timer(diamond_shot_time / diamond_shots_per_attack).timeout
		var _sfx_player = get_available_sfx_player()
		_sfx_player.stream = sfx_diamond_shot.pick_random()
		_sfx_player.play()
		
		var projectile := diamond_projectile.instantiate()
		#get_tree().root.get_child(2).
		get_parent().add_child(projectile)
		projectile.global_position = projectile_spawn_marker.global_position
		projectile.target = target
		projectile.global_rotation.y = self.global_rotation.y
	#
	state_chart.send_event("stop_shooting")

func _on_homing_projectiles_recover_state_entered() -> void:
	debug_state_label.text = "Diamond Scattershot | Recovering"
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	select_attack()
	state_chart.send_event("end_recovery")

#### CHARGE/HEADBUTT
# 3 BARs on rollers
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
			int(pow(2, 1 - 1) + pow(2, 2 - 1) + pow(2, 7 - 1))
		)
		var result = space_state.intersect_ray(query)
		
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
	sfx_player.stream = sfx_charge.pick_random()
	sfx_player.play()

func _on_charge_collision(body: Node3D) -> void:
	if body == target:
		velocity = Vector3.ZERO
		body.health_component.damage(charge_damage)
		hurtbox.body_entered.disconnect(_on_charge_collision)
		hurtbox.set_deferred("monitoring", false)

func _on_charge_charging_state_physics_processing(_delta: float) -> void:
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
	
	hurtbox.set_deferred("monitoring", true)
	if hurtbox.body_entered.is_connected(_on_charge_collision):
		hurtbox.body_entered.disconnect(_on_charge_collision)
	
	await get_tree().create_timer(attack_recovery_time).timeout
	
	state_chart.send_event("cooldown_end")
	select_attack()
	state_chart.send_event("end_recovery")


#### CHERRY BOMB
# 3 Cherries on rollers
# Bouncing explosive projectiles
func _on_cherry_bombs_targeting_state_entered() -> void:
	debug_state_label.text = "Cherry Bomb | Targeting"
	
	state_chart.send_event("start_moving")
	state_chart.send_event("attack_buildup")


func _on_cherry_bombs_targeting_state_physics_processing(_delta: float) -> void:
	if self.global_position.distance_to(target.global_position) <= max_drop_distance:
		state_chart.send_event("start_dropping_bombs")


func _on_cherry_bombs_dropping_bombs_state_entered() -> void:
	debug_state_label.text = "Cherry Bomb | Dropping"
	desired_height = 4.3
	drop_factor = 3.0
	MAX_SPEED *= 1.6
	navigation_component.follow_target = true
	
	state_chart.send_event("start_targeting")
	await desired_height_reached
	
	state_chart.send_event("attack_start")
	
	var dir_counter: int = -1
	sfx_player.volume_db = 3.0
	for i in range(bombs_per_attack):
		await get_tree().create_timer(bomb_drop_delay).timeout
		sfx_player.stream = sfx_bomb_launch.pick_random()
		sfx_player.play()
		var projectile := bomb_projectile.instantiate() as RigidBody3D
		projectile.fuse_time = bomb_fuse_time
		get_parent().add_child(projectile)
		projectile.global_position = projectile_spawn_marker.global_position
		projectile.global_rotation.y = self.global_rotation.y + (PI / 8 * dir_counter)
		projectile.apply_central_force(-projectile.global_basis.z * bomb_impulse)
		
		dir_counter += 1
		dir_counter = wrapi(dir_counter, -1, 2)
	
	sfx_player.volume_db = 0.0
	state_chart.send_event("stop_dropping_bombs")


func _on_cherry_bombs_recover_state_entered() -> void:
	debug_state_label.text = "Cherry Bomb | Recovering"
	state_chart.send_event("attack_end")
	
	navigation_component.follow_target = false
	drop_factor = DROP_FACTOR
	desired_height = DESIRED_HEIGHT
	MAX_SPEED /= 2.0
	
	await desired_height_reached
	
	await get_tree().create_timer(attack_recovery_time).timeout
	
	state_chart.send_event("cooldown_end")
	select_attack()
	state_chart.send_event("end_recovery")
