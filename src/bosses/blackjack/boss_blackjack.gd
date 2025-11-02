extends BossCore
class_name BossBlackjack

signal hand_attack_finished(hand)
signal all_hand_attacks_finished

@export var DEBUG_blackjack: bool = false

@export_group("Movement")
var flying_nav: NavigationRegion3D
@export var min_flying_height: float = 0.0
@export var max_flying_height: float = 14.0
#
@export var min_wander_distance: float = 2.0
@export var max_wander_distance: float = 8.0
@export var wander_speed: float = 4.0
var current_wander_target: Vector3
@export var wander_timeout: float = 0.5
@onready var wander_timer: Timer = $WanderTimer
var move_tween: Tween
var active_point_debug: Node3D

@export_group("Hands")
@onready var hand_anchor: Marker3D = $HandAnchor
var hand_spawn_pos: Node
@export var hand_scene: PackedScene
@export var hand_spacing: float = 5.0
@export var hand_respawn_time: float = 3.5
var hand_spawn_tween: Tween
var max_hand_spawn: int = 2
var spawned_hands = []
var despawned_hands = []
var finished_hands = []
var last_hand

@export_group("Particles")
# TODO - make this configurable per-attack
@export var wave_material: ShaderMaterial
@export var explosion_scene: PackedScene

@export_group("Dealing")
# Dealing
const SUIT_CARDS: Dictionary = {
	"ACE": 11, "TWO": 2, "THREE": 3, "FOUR": 4, "FIVE": 5, "SIX": 6, "SEVEN": 7, 
	"EIGHT": 8, "NINE": 9, "TEN": 10, "JACK": 10, "QUEEN": 10, "KING": 10, "JOKER": 0
}
var deal_tween: Tween
@export var deal_speed_scale: float = 1.0
@export var card_textures: Array[CompressedTexture2D]
@export var dealing_anim_points: Array[Marker3D]
@export var hand_count_label: Label3D
@export var card_particles: GPUParticles3D
@export var card_explosion_particles: GPUParticles3D
@export var blackjack_particles: GPUParticles3D
var hand_count: int = 0
@export_subgroup("Blackjack")
@export var blackjack_time_min: float = 8.0
@export var blackjack_time_max: float = 25.0
@export var blackjack_timer: Timer
@export_subgroup("Bust")
@export var bust_particles_parent: Node3D
@export var bust_self_damage: float = 150.0

# Intro
var intro_path_points: Array[Node] = []

@export_group("Attacks")
@export var attack_speed_scale: float = 1.0:
	set(value):
		attack_speed_scale = value
		for hand in spawned_hands:
			hand.attack_speed_scale = attack_speed_scale

@export_subgroup("Stand")
@export var slam_shockwave_prefab: PackedScene
var shockwave_instance_pool := []

@export_subgroup("Sweep")
@export var sweep_dist: float = 12.0
@export var sweep_angle_deg: float = 70.0
@export var sweep_card_scene: PackedScene
var sweep_card_instance_pool := []

@export_subgroup("Tilt")
var tilt_platform_origin_marker: Node
var tilt_hand_markers: Array[Node]
var tilt_tween: Tween
var hand_tween: Tween
@export var tilt_mesh: Node3D
@export var tilt_animateable_floor: AnimatableBody3D
var tilt_particles: GPUParticles3D
@export var tilt_max_deg: float = 25.0
@export var tilt_max_floor_speed: float = 7.8
@export var tilt_duration: float = 2.8
@export var tilt_floor_friction_mod: float = 0.30
var slippery_debuff: StatusEffect
@export_subgroup("Tilt Projectile")
@export var tilt_proj_scene: PackedScene
@export var tilt_proj_speed: float = 12.0
@export var tilt_proj_shots: int = 3
@export var tilt_proj_explosion_count: int = 1
@export var tilt_explosion_radius: float = 4.0
@export var tilt_proj_arc_height: float = 5.0
@export var tilt_proj_explosion_area_scene: PackedScene
var tilt_proj_explosion_area: Area3D
@export var tilt_explosion_damage: float = 25.0
var tilt_explosion_instances := []


func _ready() -> void:
	super()
	
	slippery_debuff = StatusEffect.new()
	slippery_debuff.display_name = "Reduce movement friction"
	slippery_debuff.status_code = "blackjack_tilted_floor_slippery"
	slippery_debuff.modified_stat = StatusEffect.PlayerStatEnum.FLOOR_FRICTION_MODIFIER
	slippery_debuff.value = -tilt_floor_friction_mod
	slippery_debuff.modify_type = StatusEffect.ModifyType.PERCENTAGE
	slippery_debuff.duration = tilt_duration
	slippery_debuff.is_bad_effect = true
	#slow_run_debuff.status_icon = run_speed_buff_icon
	
	# Create the explosion area collider when the scene has finished setting up
	scene_root.ready.connect(func(): 
		# Collider
		tilt_proj_explosion_area = tilt_proj_explosion_area_scene.instantiate()
		scene_root.add_child(tilt_proj_explosion_area)
		tilt_proj_explosion_area.global_position = self.global_position
		tilt_proj_explosion_area.get_child(0).shape.radius = tilt_explosion_radius
		#tilt_proj_explosion_area.set_deferred("monitoring", false)
		
		# Instance re-usable explosion scenes for later
		for i in range(tilt_proj_explosion_count * 3):
			var _explosion: ExplosionParticles = explosion_scene.instantiate()
			_explosion.scale_factor = tilt_explosion_radius
			_explosion.explode_on_spawn = false
			_explosion.free_on_finished = false
			tilt_explosion_instances.append(_explosion)
			scene_root.add_child(_explosion)
		
		# Instance some cards for sweep attack
		for i in range(30):
			var _card = sweep_card_scene.instantiate()
			sweep_card_instance_pool.append(_card)
		
		# Instance shockwaves for stand attack
		for i in range(24):
			var shockwave = slam_shockwave_prefab.instantiate()
			scene_root.add_child(shockwave)
			shockwave.global_position = Vector3(0, -50, 0)
			shockwave_instance_pool.push_back(shockwave)
	)


func _physics_process(delta: float) -> void:
	# DEBUG - force destroy all spawned hands
	if Input.is_action_just_pressed("input_1"):
		for hand in spawned_hands:
			despawn_hand(hand)
	return


func activate() -> void:
	super()
	navigation_component.follow_target = false
	navigation_component.enable()
	if not self.is_node_ready():
		await self.ready
	state_chart.send_event("start_intro")


func select_attack_phase_1() -> void:
	#state_chart.send_event("end_attack")
	state_chart.send_event("end_recovery")
	
	#state_chart.send_event("start_hand_slam_attack")
	state_chart.send_event("start_hand_stand_attack")
	#state_chart.send_event("start_hand_sweep_attack")
	#state_chart.send_event("start_hand_tilt_attack")
	#var chance = randf()
	#if chance < 0.25:
		#state_chart.send_event("start_hand_slam_attack")
	#elif chance < 0.50:
		#state_chart.send_event("start_hand_sweep_attack")
	#elif chance < 0.75:
		#state_chart.send_event("start_hand_tilt_attack")
	#else:
		#state_chart.send_event("start_hand_stand_attack")


## HAND HELPER METHODS
# Since the floating hands are CharacterBody3D instances
# with their own state charts, we direct them here.
#
# Spawn/despawn methods
# Spawn a new hand from a packed scene
func spawn_hand(is_visible: bool = true) -> BlackjackHand:
	var new_hand := hand_scene.instantiate()
	spawned_hands.push_back(new_hand)
	scene_root.add_child(new_hand)
	
	new_hand.state_chart.event_received.connect(_hand_on_event_received.bind(new_hand))
	new_hand.health_component.health_diff.connect(_hand_hurt)
	new_hand.health_component.died.connect(_hand_dead.bind(new_hand))
	
	# Set hand spawn position
	new_hand.controller_boss = self
	new_hand.shockwave_instance_pool = shockwave_instance_pool
	new_hand.sweep_card_instance_pool = sweep_card_instance_pool
	new_hand.attack_speed_scale = attack_speed_scale
	#new_hand.walkable_floor_nav = walkable_floor_nav
	new_hand.target = self.target
	new_hand.visible = is_visible
	new_hand.position = Vector3.ZERO
	new_hand.global_position = hand_spawn_pos.global_position
	
	new_hand.spawn_dust()
	new_hand.spawn_explosion()
	
	return new_hand


# For when we want to "destroy" a hand, but not actually free and re-instantiate a new scene
func despawn_hand(hand: BlackjackHand, reorder_hands: bool = false) -> void:
	if hand not in spawned_hands:
		push_error("Can't despawn hand that wasn't spawned")
	
	var despawned_idx: int = spawned_hands.find(hand)
	spawned_hands.pop_at(despawned_idx)
	despawned_hands.push_back(hand)
	
	# When we erase a hand from the spawned hands array, the other hands move up.
	# So we want to re-anchor all hands when this happens.
	if reorder_hands:
		# Only re-order the first two hands
		if despawned_idx <= 1:
			# Prioritise replacing the dealing hand with idx 3 during blackjack
			if spawned_hands.size() == 4:
				var _hand = spawned_hands.pop_at(3)
				spawned_hands.push_front(_hand)
				_anchor_hand(_hand)
			for i in range(despawned_idx, spawned_hands.size()):
				var _hand = spawned_hands[i]
				_anchor_hand(_hand)
	
	await hand.fake_destroy()
	await hand.dust_particle.finished
	_release_hand(hand)

# Bring a "dead" hand back as a new hand without instantiating a new scene
func respawn_hand(hand: BlackjackHand) -> void:
	if hand not in despawned_hands:
		push_error("Can't respawn hand that wasn't despawned")
	
	despawned_hands.erase(hand)
	spawned_hands.push_back(hand)
	hand.attack_speed_scale = attack_speed_scale
	hand.position = Vector3.ZERO
	hand.global_position = hand_spawn_pos.global_position
	hand.health_component.is_invincible = true
	hand.reinstate()
	hand.spawn_dust()
	hand.spawn_explosion()
	await _anchor_hand(hand)
	hand.health_component.is_invincible = false
	hand.state_chart.send_event("activate")


func get_hand_anchor_point(hand: BlackjackHand) -> Vector3:
	if not hand in spawned_hands:
		push_error("Hand %s not found in spawned hands array" % [hand.name])
	
	var hand_idx = spawned_hands.find(hand)
	var lr_sign: int = 1 if hand_idx % 2 == 0 else -1
	var idx_spacing = ceil(float(hand_idx + 1) / 2)
	var hand_offset := Vector3(hand_spacing * idx_spacing * lr_sign, 2.0 * idx_spacing, 0)
	
	return self.global_position + hand_offset


# Move the hand scene to a child of the boss so they can move together
func _anchor_hand(hand: BlackjackHand, move_time: float = 0.6) -> void:
	# Cache hand position so we can add the hand as a child of the hand anchor
	# to get smooth, relative movement, but start in the same position without snapping
	var cached_hand_pos: Vector3 = hand.global_position
	# Move the hand node inside of the boss to anchor
	var hand_parent = hand.get_parent()
	if hand_parent:
		hand_parent.remove_child(hand)
	hand_anchor.add_child(hand)
	hand.global_position = cached_hand_pos
	
	# Hands are placed alternating left to right from the center, spaced evenly from the nearest hand.
	# So we can work out the spacing by setting a hand spacing variable and determining
	# the sign of the X pos offset by using the modulo operator to check even/odd indexes
	# in the array of spawned hands.
	var hand_idx = spawned_hands.find(hand)
	if hand_idx == -1:
		return
	
	var lr_sign: int = -1 if hand_idx % 2 == 0 else 1
	var idx_spacing = ceil(float(hand_idx + 1) / 2)
	var hand_offset := Vector3(hand_spacing * idx_spacing * lr_sign, 2.0 * idx_spacing, 0)
	hand.anchor_offset = hand_offset
	# Add offhand flag for even index hands so we can flip paths directions for left sided hands
	hand.is_offhand = (lr_sign == -1)
	
	# If this loop breaks, the hand has been despawned mid-move so we need to kill the tween
	while hand in spawned_hands:
		hand_spawn_tween = get_tree().create_tween()
		hand_spawn_tween.tween_property(hand, "position", hand_offset * Vector3(-1, 1, 1), move_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		#hand_spawn_tween.tween_property(hand, "global_position", self.global_position + hand_offset, move_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		hand_spawn_tween.parallel().tween_property(hand, "scale", Vector3.ONE, move_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await hand_spawn_tween.finished
		
		## Position needs to be flipped for some reason, relative rotation issue?
		#hand.position = hand_offset * Vector3(-1, 1, 1)
		
		# TODO - over scoping, come back to this if we need it. Having hands undock and return is the basic behaviour.
		# An exception to this is when a hand has undocked, if we undock a hand and immediately spawn
		# another - we could want the spawned hand to take the place of the undocked one for a quick reload
		# type behaviour.
		return
	if hand_spawn_tween:
		hand_spawn_tween.kill()


# Move the new hand to the scene root so it can move independently
func _release_hand(hand: BlackjackHand) -> void:
	var hand_parent: Node3D = hand.get_parent()
	var cached_pos: Vector3 = hand.global_position
	
	if hand_parent:
		hand_parent.remove_child(hand)
	scene_root.add_child(hand)
	
	hand.position = Vector3.ZERO
	hand.global_position = cached_pos
	hand.anchor_offset = Vector3.ZERO


# General event handler methods
func _hand_on_event_received(event: String, hand: BossCore) -> void:
	if event == "hand_finished":
		#hand.state_chart.send_event("hand_finished")
		_hand_finished(hand)

func _hand_finished(hand: BossCore) -> void:
	finished_hands.append(hand)
	_anchor_hand(hand)
	hand_attack_finished.emit(hand)
	# Check against the max current hand size, not currently spawned hands
	# since this will end early if the player destroys a hand mid-attack
	if finished_hands.size() >= max_hand_spawn:
		last_hand = hand
		all_hand_attacks_finished.emit()
		finished_hands = []

func _hand_hurt(health_diff: float) -> void:
	health_component.damage(abs(health_diff))

func _hand_dead(hand: BlackjackHand) -> void:
	var reorder: bool = true if $StateChart/Root/Phase/AttackPhase/Dealing.active else false
	despawn_hand(hand, reorder)

# Attack trigger methods
func _start_hand_attack() -> void:
	state_chart.send_event("start_attack")

func trigger_all_hand_attacks_sim(attack_event: String, hand_delay: float = 0.0) -> void:
	var hands_to_attack = spawned_hands.duplicate()
	for hand in hands_to_attack:
		while hand in spawned_hands:
			hand.state_chart.send_event("activate")
			_release_hand(hand)
			hand.state_chart.send_event(attack_event)
			hand.state_chart.send_event("hand_targeting")
			if hand_delay:
				await get_tree().create_timer(hand_delay).timeout
			break
		if spawned_hands.size() == 0:
			break
	
	await all_hand_attacks_finished

	state_chart.send_event("finish_attack")

func trigger_all_hand_attacks_seq(attack_event: String) -> void:
	var hands_to_attack = spawned_hands.duplicate()
	for hand in hands_to_attack:
		while hand in spawned_hands:
			hand.state_chart.send_event("activate")
			_release_hand(hand)
			hand.state_chart.send_event(attack_event)
			hand.state_chart.send_event("hand_targeting")
			await hand_attack_finished
			break
		if spawned_hands.size() == 0:
			break
	
	state_chart.send_event("finish_attack")

func cancel_active_hand_attacks() -> void:
	for hand in spawned_hands:
		hand.state_chart.send_event("end_attack")


#### HOVERING (Extnded from base WALKING state)
func _on_movement_walking_state_entered() -> void:
	# Pick a random location to wander to from the point cloud
	var new_wander_point: Vector3 = NavigationServer3D.map_get_random_point(
		flying_nav.get_navigation_map(),
		1,
		true
	)
	new_wander_point.y = randf_range(min_flying_height, max_flying_height)
	var wander_dir: Vector3 = self.global_position.direction_to(new_wander_point)
	#var wander_dist: float = randf_range(min_wander_distance, max_wander_distance)
	var wander_dist: float = self.global_position.distance_to(new_wander_point)
	var wander_time: float = wander_dist / wander_speed
	
	move_tween = get_tree().create_tween()
	move_tween.tween_property(self, "global_position", new_wander_point, wander_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	anim_player.play("blackjack_boss/moving")
	move_tween.tween_callback(_movement_callback)

func _movement_callback() -> void:
	state_chart.send_event("start_targeting")
	wander_timer.start(wander_timeout)
	if is_instance_valid(active_point_debug):
		active_point_debug.queue_free()

func _on_movement_walking_state_exited() -> void:
	anim_player.play("RESET")
	if move_tween:
		move_tween.pause()
		move_tween.kill()
	if is_instance_valid(active_point_debug):
		active_point_debug.queue_free()

func _on_wander_timer_timeout() -> void:
	state_chart.send_event("start_moving")

## PHASE STATES

## INTRO
func _on_intro_state_entered() -> void:
	# Play an animation of the boss rising up from the void,
	# two hands grabbing the edge to wrench them upwards.
	state_chart.send_event("start_targeting")
	
	# Spawn two initial hands
	for i in range(2):
		var _hand = spawn_hand(false)
		_hand.visible = false
		_hand.health_component.is_invincible = true
	
	move_tween = get_tree().create_tween()
	var hand_l = spawned_hands[1]
	var hand_r = spawned_hands[0]
	self.global_position = intro_path_points[0].global_position
	hand_l.global_position = intro_path_points[0].global_position
	hand_l.visible = true
	hand_r.global_position = intro_path_points[0].global_position
	hand_r.visible = true
	
	move_tween.tween_property(hand_l, "global_position", intro_path_points[1].global_position + Vector3(hand_spacing, -1 ,0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	move_tween.parallel().tween_property(hand_r, "global_position", intro_path_points[1].global_position + Vector3(-hand_spacing, -1, 0), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	move_tween.chain().tween_property(self, "global_position", intro_path_points[1].global_position, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	move_tween.chain().tween_property(self, "global_position", intro_path_points[2].global_position, 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	move_tween.parallel().tween_property(hand_l, "global_position", intro_path_points[2].global_position + Vector3(hand_spacing, 2.0 ,0), 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	move_tween.parallel().tween_property(hand_r, "global_position", intro_path_points[2].global_position + Vector3(-hand_spacing, 2.0 ,0), 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	
	await move_tween.finished
	
	_anchor_hand(hand_l)
	_anchor_hand(hand_r)
	
	for _hand in [hand_l, hand_r]:
		_hand.health_component.is_invincible = false
	
	state_chart.send_event("start_moving")
	state_chart.send_event("finish_intro")


## DEALING

func _on_dealing_idle_state_entered() -> void:
	hand_count_label.text = "0"
	
	var start_hand_count: int = spawned_hands.size()
	if start_hand_count < max_hand_spawn:
		for i in range(max_hand_spawn - start_hand_count):
			await respawn_hand(despawned_hands.front())
	
	state_chart.send_event("start_deal")


func _on_dealing_dealing_state_entered() -> void:
	# Keep dealing until we hit stand, blackjack, or bust
	hand_count = 0
	
	# Loop here so we can update the dealing hand tween if the current hand is killed
	while hand_count < 30:
		# Re-check the hand each loop so we can swap a new hand in as the dealing hand
		# if the dealing hand is destroyed 
		var hand_r: BlackjackHand
		if spawned_hands.size() == 0:
			state_chart.send_event("start_bust")
			state_chart.send_event("end_deal")
			return
		
		hand_r = spawned_hands[0]
		if not hand_r.health_component.died.is_connected(_abort_deal_tween):
			hand_r.health_component.died.connect(_abort_deal_tween)
		# Disconnect the deal tween kill callback from hands we've re-ordered
		for hand in spawned_hands.slice(1):
			if hand.health_component.died.is_connected(_abort_deal_tween):
				hand.health_component.died.disconnect(_abort_deal_tween)
		
		await _anchor_hand(hand_r, 0.0)
		var cached_pos: Vector3 = hand_r.position
		
		# Pick a card, update the count, and change the particle texture accordingly
		var card_key = SUIT_CARDS.keys().pick_random()
		var card_value = SUIT_CARDS[card_key]
		card_particles.draw_pass_1.surface_get_material(0).albedo_texture = card_textures[SUIT_CARDS.keys().find(card_key)]
		
		hand_count += card_value
		# Dealing with aces high and aces low
		if hand_count > 21 and card_value == 11 and hand_count - 10 <= 21:
			card_value -= 10
			hand_count -= 10
		
		if DEBUG_blackjack:
			hand_count = 21
		
		deal_tween = get_tree().create_tween()
		deal_tween.set_parallel(false)

		deal_tween.tween_property(hand_r, "position", dealing_anim_points[0].position, 0.1 / deal_speed_scale).set_ease(Tween.EASE_IN)
		deal_tween.tween_property(hand_r, "position", dealing_anim_points[1].position, 0.15 / deal_speed_scale).set_ease(Tween.EASE_IN_OUT)
		deal_tween.tween_property(hand_r, "position", dealing_anim_points[2].position, 0.1 / deal_speed_scale).set_ease(Tween.EASE_OUT)
		deal_tween.tween_callback(
			func():
				card_particles.emitting = true
				card_explosion_particles.emitting = true
				hand_count_label.text = str(hand_count)
		)
		deal_tween.tween_property(hand_r, "position",  cached_pos, 0.85 / deal_speed_scale).set_ease(Tween.EASE_OUT)
		
		await deal_tween.finished
		
		if hand_count >= 16:
			# BUST
			if hand_count > 21:
				state_chart.send_event("start_bust")
				_abort_deal_tween()
				state_chart.send_event("end_deal_special")
				return
			
			# BLACKJACK
			elif hand_count == 21:
				state_chart.send_event("start_blackjack")
			
			_abort_deal_tween()
			state_chart.send_event("end_deal")
			return
	
	# We can force the loop to break and kill the deal tween early by
	# setting the hand_count to > 30
	_abort_deal_tween()


func _on_dealing_dealing_state_exited() -> void:
	for hand_arr in [spawned_hands, despawned_hands, finished_hands]:
		for hand in hand_arr:
			if hand.health_component.died.is_connected(_abort_deal_tween):
				hand.health_component.died.disconnect(_abort_deal_tween)


func _abort_deal_tween() -> void:
	if deal_tween:
		deal_tween.kill()
		deal_tween.finished.emit()
	if spawned_hands.size() == 0:
		state_chart.send_event("start_bust")
		state_chart.send_event("end_deal")


func _on_dealing_dealing_state_physics_processing(_delta: float) -> void:
	# Catch if the player has destroyed all hands during the deal
	if spawned_hands.size() == 0:
		state_chart.send_event("start_bust")
		state_chart.send_event("end_deal")
		_abort_deal_tween()


func _on_dealing_recover_state_entered() -> void:
	state_chart.send_event("trigger_phase_1")
	state_chart.send_event("end_recovery")


## HIT

func _on_hand_hit_attacking_state_entered() -> void:
	state_chart.send_event("start_targeting")
	match current_phase:
		1:
			if $StateChart/Root/Status/Blackjack/Active.active:
				trigger_all_hand_attacks_sim("start_hit_attack", 0.7)
			else:
				trigger_all_hand_attacks_seq("start_hit_attack")
		#2:
			#trigger_substack_attack("start_small_projectile_attack_phase_2")

func _on_hand_hit_attacking_physics_process(_delta: float) -> void:
	if spawned_hands.size() == 0:
		state_chart.send_event("finish_attack")
		return


func _on_hand_stand_attacking_state_entered() -> void:
	match current_phase:
		1:
			if $StateChart/Root/Status/Blackjack/Active.active:
				trigger_all_hand_attacks_sim("start_stand_attack", 0.5)
			else:
				trigger_all_hand_attacks_sim("start_stand_attack", 0.8)
		#2:
			#trigger_substack_attack("start_small_projectile_attack_phase_2")

func _on_hand_stand_attacking_physics_process(_delta: float) -> void:
	if spawned_hands.size() == 0:
		state_chart.send_event("finish_attack")
		return


func _on_hand_sweep_attacking_state_entered() -> void:
	#for hand in spawned_hands:
		#var _angle: float = rad_to_deg(sweep_angle_deg)/2
		#var l_angle: float = _angle if hand.is_offhand else -_angle
		#var r_angle: float = -_angle if hand.is_offhand else _angle
		## Pick a sweep start point near the target
		#hand.sweep_start_pos = target.global_position - (target.global_basis.z * sweep_dist).rotated(Vector3.UP, l_angle)
		#hand.sweep_end_pos = target.global_position - (target.global_basis.z * sweep_dist).rotated(Vector3.UP, r_angle)
	match current_phase:
		1:
			if $StateChart/Root/Status/Blackjack/Active.active:
				trigger_all_hand_attacks_sim("start_sweep_attack", 0.65)
			else:
				trigger_all_hand_attacks_seq("start_sweep_attack")
		#2:
			#trigger_substack_attack("start_small_projectile_attack_phase_2")

func _on_hand_sweep_attacking_physics_process(_delta: float) -> void:
	if spawned_hands.size() == 0:
		state_chart.send_event("finish_attack")
		return


func _recover_entered() -> void:
	state_chart.send_event("attack_end")

	await get_tree().create_timer(attack_recovery_time).timeout

	state_chart.send_event("cooldown_end")
	state_chart.send_event("start_moving")
	state_chart.send_event("start_dealing")


func _on_phase_1_state_entered() -> void:
	#state_chart.send_event("start_moving")
	select_attack()


func _on_phase_1_state_exited() -> void:
	#state_chart.send_event("start_targeting")
	pass


func _on_wave_collision(
	body: Node3D,
	aoe_damage: float,
	pushback_source: Node3D = self,
	pushback_radius: float = pushback_source.collider.shape.radius
) -> void:
	if body == target:
		body.health_component.damage(aoe_damage)
		# TODO - pushback
		#trigger_pushback(pushback_force, pushback_source, pushback_radius)
		InputHelper.rumble_medium()


func _on_blackjack_active_state_entered() -> void:
	hand_count_label.modulate = Color.GREEN
	max_hand_spawn = 4
	# Play particle effects and juice
	blackjack_particles.emitting = true
	# Spawn 2 more hands
	for i in range(2):
		var _hand = spawn_hand()
		_anchor_hand(_hand)
	# Trigger attack
	state_chart.send_event("trigger_phase_1")
	# Start timer
	blackjack_timer.start(randf_range(blackjack_time_min, blackjack_time_max))


func _on_blackjack_timer_timeout() -> void:
	state_chart.send_event("end_blackjack")


func _on_blackjack_active_state_exited() -> void:
	hand_count_label.modulate = Color.WHITE
	max_hand_spawn = 2
	var current_hand_count: int = spawned_hands.size()
	if current_hand_count > 2:
		for i in range(1, current_hand_count - 1):
			var _hand = spawned_hands[-i]
			despawn_hand(_hand)
	blackjack_particles.emitting = false


func _on_bust_idle_state_entered() -> void:
	hand_count_label.modulate = Color.RED
	state_chart.send_event("stop_moving")
	# Cancel out any active blackjacks
	state_chart.send_event("end_blackjack")
	if not blackjack_timer.is_stopped():
		blackjack_timer.stop()
	
	anim_player.play("blackjack_boss/bust")
	state_chart.send_event("start_explode")


func _on_bust_exploding_state_entered() -> void:
	# Show joker card anim
	card_particles.draw_pass_1.surface_get_material(0).albedo_texture = card_textures[13]
	card_particles.emitting = true
	card_explosion_particles.emitting = true
	
	var emitters = bust_particles_parent.get_children()
	for emitter in emitters:
		emitter.explosion()
		self.health_component.damage(bust_self_damage * randf_range(0.7, 1.3) / emitters.size(), Color.RED)
		await get_tree().create_timer(randf_range(0.05, 0.2)).timeout
	await get_tree().create_timer(0.3).timeout
	state_chart.send_event("end_bust")


func _on_bust_recover_state_entered() -> void:
	hand_count_label.modulate = Color.WHITE
	# Stop animation
	anim_player.play("RESET")
	
	#move_tween = get_tree().create_tween()
	#var return_pos: Vector3 = NavigationServer3D.map_get_random_point(
		#flying_nav.get_navigation_map(),
		#1,
		#true
	#)
	#return_pos.y = randf_range(min_flying_height, max_flying_height)
	#move_tween.tween_property(self, "global_position", return_pos, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	#await move_tween.finished

	state_chart.send_event("start_targeting")
	# TODO
	state_chart.send_event("end_recovery")


func _on_tilt_moving_to_pos_state_entered() -> void:
	state_chart.send_event("start_targeting")
	# Move two hands to marker positions
	hand_tween = get_tree().create_tween()
	hand_tween.set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	hand_tween.tween_property(self, "global_position", tilt_platform_origin_marker.global_position, 0.8)
	for i in range(2):
		var idx: int = 1 - i
		if idx < spawned_hands.size():
			var _hand = spawned_hands[idx]
			_release_hand(_hand)
			hand_tween.tween_property(_hand, "global_position", tilt_hand_markers[i].global_position, 0.8)
	
	await hand_tween.finished
	
	state_chart.send_event("start_tilting")


func _on_tilt_moving_to_pos_state_physics_processing(delta: float) -> void:
	if spawned_hands.size() == 0:
		if hand_tween:
			hand_tween.kill()
			state_chart.send_event("end_attack")
			_recover_entered()



func _on_tilt_tilting_state_entered() -> void:
	# Enable the player controller to slide on slopes
	target.floor_stop_on_slope = false
	target.add_status_effect(slippery_debuff)
	
	# Tilt the arena by a rotation degree amount
	tilt_tween = get_tree().create_tween()
	tilt_tween.set_parallel(true)
	tilt_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tilt_tween.tween_property(tilt_mesh, "rotation_degrees:x", -tilt_max_deg, tilt_duration/2)
	tilt_tween.tween_property(tilt_animateable_floor, "constant_linear_velocity:z", -tilt_max_floor_speed, tilt_duration/2)
	
	await tilt_tween.finished
	target.vel_horizontal += Vector2(0, -8.0)
	tilt_particles.emitting = true
	
	state_chart.send_event("start_firing")


func _on_tilt_tilting_state_physics_processing(delta: float) -> void:
	self.global_position = tilt_platform_origin_marker.global_position
	self.rotation_degrees.x = tilt_mesh.rotation_degrees.x
	
	if spawned_hands.size() == 0:
		if tilt_tween:
			tilt_tween.kill()
			state_chart.send_event("stop_firing")
	
	for i in range(2):
		if i >= spawned_hands.size():
			return
		var _hand = spawned_hands[i]
		_hand.global_position =  tilt_hand_markers[i].global_position


func _on_tilt_firing_state_entered() -> void:
	var bounding_box: AABB = tilt_animateable_floor.get_child(0).mesh.get_aabb()
	for i in range(tilt_proj_shots):
		# If we have blackjack active, fire additional curved 
		# exploding projectiles from the extra hands
		var proj_sources: int = 3 if $StateChart/Root/Status/Blackjack/Active.active else 1
		var proj_origin: Vector3
		var target_offset: Vector3
		for j in range(proj_sources):
			# We want to fire in the order: CENTER, LEFT HAND, RIGHT HAND
			match j:
				0:
					# Center platform projectile, aim for the player
					proj_origin = self.global_position
					target_offset = Vector3.ZERO
				1:
					# Left Hand projectile, aim wide to the left
					if spawned_hands.size() < 3:
						break
					proj_origin = spawned_hands[2].global_position
					target_offset = Vector3(7.5, 0, 0)
				2:
					# Right Hand projectile, aim wide to the right
					if spawned_hands.size() < 4:
						break
					proj_origin = spawned_hands[3].global_position
					target_offset = Vector3(-7.5, 0, 0)
			
			# TODO - break this up into sub functions for readability
			#
			#
			# Fire a curved projectile that explodes into an AoE on impact with the floor
			var path = Path3D.new()
			# TODO - aim these in a cluster around the arena as an obstacle
			# TODO - lock target position to the floor surface
			var target_pos: Vector3 = target.global_position + target_offset
			
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(
				target_pos,
				target_pos - tilt_mesh.global_basis.y * 20,
				int(pow(2, 1 - 1))
			)
			var result = space_state.intersect_ray(query)
			if result:
				target_pos.y = result.position.y
			
			target_pos -= tilt_mesh.global_basis.z * 10.0
			if abs(target_pos.z) > bounding_box.size.z:
				var sign: int = 1 if target_pos.z > 0 else -1
				target_pos.z = bounding_box.size.z * sign
				
			var curve = _create_curved_path(proj_origin, target_pos, tilt_proj_arc_height)
			path.curve = curve
			
			# Add the path to the scene
			scene_root.add_child(path)
			var curve_path_follow = PathFollow3D.new()
			path.add_child(curve_path_follow)

			# Add the projectile/particle to the path follow
			var tilt_proj = tilt_proj_scene.instantiate()
			curve_path_follow.add_child(tilt_proj)
			tilt_proj.global_position = curve_path_follow.global_position
			
			# Animate the projectile along the path
			var curve_tween = get_tree().create_tween()
			curve_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CIRC)
			# Parent hand motion
			curve_tween.tween_property(curve_path_follow, "progress_ratio", 1.0, 0.45)
			
			await curve_tween.finished
			
			var hit_pos: Vector3 = tilt_proj.global_position
			path.queue_free()
			
			# Spawn a damaging area 3d
			#tilt_proj_explosion_area.set_deferred("monitoring", true)
			tilt_proj_explosion_area.global_position = hit_pos
			for body in tilt_proj_explosion_area.get_overlapping_bodies():
				if "health_component" in body:
					body.health_component.damage(tilt_explosion_damage)
				else:
					body.queue_free()
			#tilt_proj_explosion_area.set_deferred("monitoring", false)
			# Spawn an explosion on impact
			for k in range(tilt_proj_explosion_count):
				var _pos: Vector3 = hit_pos - tilt_mesh.global_basis.z.rotated(Vector3.UP, randf_range(0, 2*PI)) * 0.5
				var explosion = tilt_explosion_instances.pop_front()
				explosion.global_position = _pos
				explosion.explosion()
				await get_tree().create_timer(randf_range(0.05, 0.4))
				tilt_explosion_instances.push_back(explosion)
			# TODO
	
	state_chart.send_event("stop_firing")


func _on_tilt_firing_state_physics_processing(delta: float) -> void:
	if spawned_hands.size() == 0:
		state_chart.send_event("stop_firing")


func _on_tilt_untilting_state_entered() -> void:
	# Return the arena to the original zeroed rotation
	tilt_particles.emitting = false
	tilt_tween = get_tree().create_tween()
	tilt_tween.set_parallel(true)
	tilt_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tilt_tween.tween_property(tilt_mesh, "rotation_degrees:x", 0, tilt_duration/2)
	tilt_tween.tween_property(tilt_animateable_floor, "constant_linear_velocity:z", 0, tilt_duration/2)
	
	await tilt_tween.finished
	
	state_chart.send_event("stop_tilting")


func _on_tilt_untilting_state_physics_processing(delta: float) -> void:
	self.global_position = tilt_platform_origin_marker.global_position
	self.rotation_degrees.x = tilt_mesh.rotation_degrees.x
	
	for i in range(2):
		if i >= spawned_hands.size():
			return
		var _hand = spawned_hands[i]
		_hand.global_position =  tilt_hand_markers[i].global_position


func _on_tilt_recovering_state_entered() -> void:
	target.floor_stop_on_slope = true
	target.remove_status_effect(slippery_debuff)
	# Return the hands to the anchored position
	var return_tween = get_tree().create_tween()
	return_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	return_tween.tween_property(self, "global_position", intro_path_points[2].global_position, 0.6)
	
	for i in range(2):
		if spawned_hands.size() <= i:
			break
		var _hand = spawned_hands[i]
		_anchor_hand(_hand)
	
	_recover_entered()


func _create_curved_path(start_pos: Vector3, goal_pos: Vector3, height: float, apex_ratio: float = 0.5, out_ratio: float = 0.6667, in_ratio: float = 0.6667) -> Curve3D:
	var curve = Curve3D.new()
	var mid_point: Vector3 = start_pos.lerp(goal_pos, apex_ratio) + Vector3(0, height, 0)

	# Calculate bezier control points
	var out_0 = (mid_point - start_pos) * out_ratio
	var in_1 = (mid_point - goal_pos) * in_ratio
	curve.add_point(start_pos, Vector3.ZERO, out_0)
	curve.add_point(goal_pos, in_1, Vector3.ZERO)

	return curve
