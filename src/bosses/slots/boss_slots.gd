extends BossCore
class_name BossSlots

signal charge_lined_up
signal desired_height_reached


# Juice TODO:
# -Homing Diamond: Change the homing diamond to spawn all at once (instead of one by one), wait a bit then homing at player.  DONE
# -Coin Spray: Fire in a burst-of-5, with higher firerate, speed, and recoil. Maybe let the coin ricochet once at higher difficulty. DONE
# -Pinball: Add charge up timer and laser indicator to telegraph. Pinball speed is now hitscan.
# -Bell of Fortune: Add 3D VFX indicator to better telegraph. Add screenshake and dust cloud on impact.
# -Charge: Add ground decal effect on charge path to show its power. Add speedline. DONE
# -General: Add dust particle below to show that he's hovering.


# Antes note:
# Ante 1: Room of Fortune - Add a slot machine that add modifier to stages. Boss can interact with it too ( on a CD)
# Ante 2: Hidden Motive - Hide the slot UI / attack indicator
# Ante 3: Pinball Gamble - Enable new projectile attack that can ricochet
# Ante 4: New phase? At 20% HP, Overclock, where the boss significantly reduce its attack cooldown
# Ante 5: Greed Machine - Boss can pick up / steal dropped chips to recover HP

# Status
# Weak to Shock (he's a machine), resist to Bleeding (same reason)

@onready var projectile_marker_pivot: Node3D = $MarkerPivot
@onready var projectile_spawn_marker: Marker3D = $MarkerPivot/ProjectileSpawnMarker
@onready var slot_icons_parent: Node3D = $Sprite3D/SlotIcons
@onready var explode_vfx: ExplosionParticles = $MarkerPivot/ProjectileSpawnMarker/ExplosionPoly

var prev_phase
@export_group("Phase")
@export var phase_2_health_percentage_trigger: float = 0.5
@onready var phase_2_smoke_effect: GPUParticles3D = $Phase2Smoke

@export_group("Display")
@export var pulled_lever_sprite: CompressedTexture2D

@export_group("Movement")
@export var DESIRED_HEIGHT: float = 3.1
var desired_height: float = DESIRED_HEIGHT
@export var DROP_FACTOR: float = 1.0
var drop_factor: float = DROP_FACTOR

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
@export var sfx_slot_pick_pinball: AudioStream
@onready var sfx_slot_picks: Array[AudioStream] = [
	sfx_slot_pick_coin,
	sfx_slot_pick_bell,
	sfx_slot_pick_bar,
	sfx_slot_pick_diamond,
	sfx_slot_pick_cherry,
	sfx_slot_pick_pinball
]

@export_subgroup("Slot Icons")
@export var icon_coin: Texture
@export var icon_bell: Texture
@export var icon_charge: Texture
@export var icon_diamond: Texture
@export var icon_cherry_bomb: Texture
@export var icon_pinball: Texture
@onready var slot_icons: Array[Texture] = [
	icon_coin, icon_bell, icon_charge, icon_diamond, icon_cherry_bomb, icon_pinball
]
@onready var slot_decals: Array[Node] = get_tree().get_root().get_child(3).find_children("*", "SlotRollerDecal")

@export_subgroup("Coin Burst")
@export var coin_damage: float = 2
@export var coin_speed: float = 60
@export var coin_projectile: PackedScene
@export var coin_shots_per_burst: int = 4
@export var coin_burst_repeat: int = 3
@export var coin_firerate: float = 4
@export var coin_spread: float = 15
@export var delay_between_coin_burst: float = 0.5
# SFX
@export var sfx_coin_gun_blast: Array[AudioStream]
@export var sfx_coin_shot: Array[AudioStream]

@export_subgroup("Bell Drop")
var bell_attack_enabled = false # Based on ante 1
@export var bell_damage: float = 20
@export var bell_scene: PackedScene
@export var bell_flare_prefab: PackedScene
@export var bell_aoe_marker_ring: CompressedTexture2D
@export var bell_aoe_marker_arrows: CompressedTexture2D
@export var drop_shadow_material: Material
@export var bell_shadow_time: float = 1.4
@export var bell_spawn_area_radius: float = 28.0
@export var bells_to_spawn: int = 4
const BELL_RADIUS = 6.0
var bell_spawn_points: Array = []
# SFX
#@export var sfx_bell_Spawn: Array[AudioStream]  - TODO: Get spawn sounds
# Moved to the bell objects
@export var sfx_shoot_bell_flare: Array[AudioStream]
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
@export var speedline_vfx_prefab: PackedScene
@export var crack_decal_prefab: PackedScene
const CHARGE_CRACK_INTERVAL = 0.1
var charge_crack_interval_timer = 0
var charge_locked: bool = false
# SFX
@export var sfx_charge: Array[AudioStream]
@export var sfx_charge_impact: Array[AudioStream]

@export_subgroup("Homing Diamonds")
var homing_diamond_enabled = false # Based on ante 2
@export var diamond_damage: float = 3
@export var diamond_speed: float = 20
@export var diamond_homing_speed: float = 40
@export var diamond_spread: float = 30
@export var diamond_projectile: PackedScene
@export var diamond_shots_per_attack: int = 7
# SFX
@export var sfx_diamond_gun_blast: Array[AudioStream]
@export var sfx_diamond_shot: Array[AudioStream]

@export_subgroup("Ricochet Pinball")
var pinball_enabled = false # Based on ante 3
@export var pinball_damage: float = 2
@export var pinball_speed: float = 50
@export var pinball_ricochet_count: int = 5
@export var pinball_projectile: PackedScene
@export var pinball_shots_per_attack: int = 6
@export var pinball_shot_time: float = 1.3
# SFX
@export var sfx_pinball_shot: Array[AudioStream]

@export_subgroup("Cherry Bombs")
@export var bomb_damage: float = 10
@export var bomb_projectile: PackedScene
@export var bombs_per_attack: int = 5
@export var bomb_fuse_time: float = 2.5
@export var bomb_impulse: float = 100000.0
@export var max_drop_distance: float = 20.0
@export var bomb_drop_delay: float = 0.4
@onready var bomb_drop_timer: Timer = $StateChart/Root/Phase/Phase2/CherryBombs/DroppingBombs/DropTimer
var active_bombs: Array = []
# SFX
# Moved to the bomb objects
@export var sfx_bomb_launch: Array[AudioStream]
#@export var sfx_bomb_bounce: Array[AudioStream]
#@export var sfx_bomb_explode: Array[AudioStream]

@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayerHolder/SFXPlayer

@export_group("Passive")
@export_subgroup("Absorb Chip")
var absorb_chip_enabled = false
@onready var absorb_chip_timer: Timer = $AbsorbChipTimer
@export var absorb_chip_interval: float = 10
@export var absorb_chip_range: float = 25
@export var chip_value_to_heal_ratio: float = 0.5

@onready var floor_raycast: RayCast3D = $FloorRaycast

func _ready() -> void:
	super ()
	bell_attack_enabled = true
	homing_diamond_enabled = true
	if GameManager.boss_ante >= 1:
		pass
	if GameManager.boss_ante >= 2:
		pinball_enabled = true
	if GameManager.boss_ante >= 3:
		pass
	if GameManager.boss_ante >= 4:
		slot_icons_parent.visible = false
	if GameManager.boss_ante >= 5:
		absorb_chip_enabled = true
		absorb_chip_timer.start(absorb_chip_interval)


func activate() -> void:
	super ()
	navigation_component.follow_target = false
	navigation_component.enable()
	state_chart.send_event("start_phase_1")


func _physics_process(delta: float) -> void:
	super (delta)

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
		# Tuples of event string and icon index
		["start_coin_attack", 0],
		["start_charge_attack", 2],
	]
	if bell_attack_enabled:
		possible_phases.append(["start_bell_attack", 1])
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
		# Tuples of event string and icon index
		["start_coin_attack", 0],
		["start_charge_attack", 2],
		["start_bomb_attack", 4],
	]
	if bell_attack_enabled:
		possible_phases.append(["start_bell_attack", 1])
	if homing_diamond_enabled:
		possible_phases.append(["start_diamond_attack", 3])
		possible_phases.erase(["start_coin_attack", 0]) # Replace coin with diamond
	if pinball_enabled:
		possible_phases.append(["start_pinball_attack", 5])
	if prev_phase:
		possible_phases.erase(prev_phase)
	# TODO - add random weighting
	var new_phase = possible_phases.pick_random()
	prev_phase = new_phase
	next_attack = new_phase[0]
	next_attack_idx = new_phase[1]
	state_chart.send_event("start_spin_slots")


func _on_health_changed(new_health: float, prev_health: float) -> void:
	super (new_health, prev_health)
	if new_health < health_component.max_health * phase_2_health_percentage_trigger:
		state_chart.send_event("start_phase_2")


func _on_died() -> void:
	_cleanup_bombs()

	anim_player.stop()
	set_physics_process(false)
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position:y", -0.3, 1.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	died.emit()
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
	state_chart.send_event("deactivate")
	drop_barrel()

	await boss_death_slow_mo()


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
	block_hurt_frame = true
	sprite.texture = pulled_lever_sprite
	await get_tree().create_timer(0.2, false).timeout
	sprite.texture = base_sprite
	block_hurt_frame = false
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
		await get_tree().create_timer(0.1, false).timeout
	# Settle each roller one by one
	for i in range(slot_icons_parent.get_child_count()):
		while slot_icons_parent.get_child(i).texture != next_attack_texture:
			for j in range(i, slot_icons_parent.get_child_count()):
				var slot_sprite = slot_icons_parent.get_child(j)
				var sprite_idx: int = slot_icons.find(slot_sprite.texture) + 1
				var new_idx: int = wrapi(sprite_idx, 0, slot_icons.size())
				slot_sprite.texture = slot_icons[new_idx]

	sfx_player.stop()
	var choice_sfx: AudioStream = sfx_slot_picks[next_attack_idx]
	sfx_player.stream = choice_sfx
	sfx_player.play()

	state_chart.send_event("attack_start")
	state_chart.send_event("end_slots")

func _on_spin_slots_recover_state_entered() -> void:
	debug_state_label.text = "Spin Slots | Recovering"
	state_chart.send_event("attack_end")
	block_hurt_frame = true
	sprite.texture = pulled_lever_sprite
	await get_tree().create_timer(0.2, false).timeout
	block_hurt_frame = false
	sprite.texture = base_sprite
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
	await get_tree().create_timer(0.8, false).timeout
	state_chart.send_event("start_shooting")


func _on_coin_projectiles_shooting_state_entered() -> void:
	debug_state_label.text = "Coin Burst | Shooting"

	state_chart.send_event("attack_telegraph")
	# await get_tree().create_timer(0.4, false).timeout
	anim_player.play("coin_shot_telegraph")
	await anim_player.animation_finished
	anim_player.play("RESET")
	state_chart.send_event("attack_start")

	for i in coin_burst_repeat:
		explode_vfx.explode()
		play_positional_sound(sfx_coin_gun_blast.pick_random())
		for j in coin_shots_per_burst:
			await get_tree().create_timer(1.0 / coin_firerate, false).timeout
			var proj: BaseBossProjectile = fire_projectile(coin_projectile, projectile_spawn_marker.global_position, coin_spread, sfx_coin_shot)
			proj.init(coin_damage * GameManager.get_risk_dmg_mult(), coin_speed)
		# Dont play animation for the last one (since boss no longer actually shoot)
		if i < coin_burst_repeat - 1:
			anim_player.play("quick_coin_shot")
			await anim_player.animation_finished
			anim_player.play("RESET")
	state_chart.send_event("stop_shooting")


func _on_coin_projectiles_recover_state_entered() -> void:
	debug_state_label.text = "Coin Burst | Recovering"

	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time, false).timeout
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
	var decal_ring: Decal = spawn_decal_at_pos(target_pos, bell_aoe_marker_ring)
	var decal_arrows: Decal = spawn_decal_at_pos(target_pos, bell_aoe_marker_arrows)

	aoe_tween.tween_property(decal_ring, "size", Vector3(max_radius * 2, 1, max_radius * 2), drop_time * 0.75)
	aoe_tween.parallel().tween_property(decal_arrows, "size", Vector3(max_radius * 2, 1, max_radius * 2), drop_time)
	aoe_tween.parallel().tween_property(decal_arrows, "rotation_degrees:y", 360, drop_time)
	aoe_tween.chain().tween_callback(_spawn_bell.bind(target_pos, max_radius, [decal_arrows, decal_ring]))
	aoe_tween.chain().tween_property(decal_arrows, "size", Vector3.ZERO, 1.04) # Based on bell sfx sample timing


func shoot_bell_flare(target_pos: Vector3) -> void:
	play_positional_sound(sfx_shoot_bell_flare.pick_random())
	var inst = bell_flare_prefab.instantiate()
	get_tree().get_root().add_child(inst)
	const FLARE_PEAK_HEIGHT = 15
	inst.init(projectile_spawn_marker.global_position, target_pos, FLARE_PEAK_HEIGHT)


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
	get_tree().root.get_child(7).add_child(bell)
	bell.global_position = pos
	bell.init(bell_damage * GameManager.get_risk_dmg_mult(), size)
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
	await get_tree().create_timer(0.5, false).timeout
	anim_player.play("summon_bell_raise_gun")
	await anim_player.animation_finished
	anim_player.play("RESET")
	state_chart.send_event("attack_start")
	state_chart.send_event("start_drop")


func _on_bell_drop_dropping_state_entered() -> void:
	debug_state_label.text = "Bell Drop | Dropping"
	state_chart.send_event("attack_telegraph")

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

	for point in bell_spawn_points:
		var spawn := Vector3(point.x, 0, point.y)
		anim_player.play("summon_bell_shoot")
		shoot_bell_flare(spawn)
		await anim_player.animation_finished

	anim_player.play("RESET")
	state_chart.send_event("finish_drop")


func _on_bell_drop_dropping_state_exited() -> void:
	for point in bell_spawn_points:
		if $StateChart/Root/Health/Dead.active:
			break
		var spawn := Vector3(point.x, 2.5, point.y)
		# Spawn shadow/mesh to show AoE, grow in size as it drops
		drop_shadow(spawn, BELL_RADIUS, bell_shadow_time)
		await get_tree().create_timer(0.2, false).timeout


func _on_bell_drop_recover_state_entered() -> void:
	anim_player.play("RESET")
	debug_state_label.text = "Bell Drop | Recovering"

	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time, false).timeout
	state_chart.send_event("cooldown_end")

	select_attack()
	state_chart.send_event("end_recovery")


#### LEVER SWIPE
# Whacks player with slot level arm if they get too close
func _on_lever_swipe_targeting_state_entered() -> void:
	debug_state_label.text = "Lever Swipe | Targeting"

	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time, false).timeout
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
		target.health_component.damage(swipe_damage * GameManager.get_risk_dmg_mult())
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

	await get_tree().create_timer(0.2, false).timeout
	sprite.modulate = Color.WHITE

	state_chart.send_event("end_swipe")


func _on_lever_swipe_recover_state_entered() -> void:
	debug_state_label.text = "Lever Swipe | Recovery"
	hurtbox.set_deferred("monitoring", true)
	sfx_player.stream = null

	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time, false).timeout
	state_chart.send_event("cooldown_end")

	select_attack()
	state_chart.send_event("end_recovery")


#### PHASE 2
#
func _on_phase_2_state_entered() -> void:
	current_phase = 2
	phase_2_smoke_effect.emitting = true
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
	# await get_tree().create_timer(0.8, false).timeout
	anim_player.play("diamond_shot_telegraph")
	await anim_player.animation_finished
	anim_player.play("RESET")
	state_chart.send_event("start_shooting")


func _on_homing_projectiles_shooting_state_entered() -> void:
	debug_state_label.text = "Diamond Scattershot | Shooting"
	# Fire out projctiles in a spiral, each projectile homes in on the player
	explode_vfx.explode()
	play_positional_sound(sfx_diamond_gun_blast.pick_random())
	for i in range(diamond_shots_per_attack):
		# await get_tree().create_timer(diamond_shot_time / diamond_shots_per_attack, false).timeout
		var projectile: DiamondProjectile = fire_projectile(diamond_projectile, projectile_spawn_marker.global_position, diamond_spread, sfx_diamond_shot)
		projectile.target = target
		projectile.init(diamond_damage * GameManager.get_risk_dmg_mult(), diamond_speed)
		projectile.diamond_homing_speed = diamond_homing_speed
	state_chart.send_event("stop_shooting")

func _on_homing_projectiles_recover_state_entered() -> void:
	debug_state_label.text = "Diamond Scattershot | Recovering"

	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time, false).timeout
	state_chart.send_event("cooldown_end")

	select_attack()
	state_chart.send_event("end_recovery")


#### PINBALL SCATTERSHOT
# Ricochet pinball projectile, fired in a spiral/radial pattern from boss
func _on_pinball_projectiles_state_physics_processing(delta: float) -> void:
	orbit_player(delta)


func _on_pinball_projectiles_targeting_state_entered() -> void:
	debug_state_label.text = "Pinball Riochet | Targeting"

	state_chart.send_event("start_moving")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.8, false).timeout
	state_chart.send_event("start_shooting")


func _on_pinball_projectiles_shooting_state_entered() -> void:
	debug_state_label.text = "Pinball Riochet | Shooting"
	# Fire out projctiles in a spiral, each projectile can ricochet
	for i in range(pinball_shots_per_attack):
		await get_tree().create_timer(pinball_shot_time / pinball_shots_per_attack, false).timeout
		var projectile = fire_projectile(pinball_projectile, projectile_spawn_marker.global_position, 0, sfx_coin_shot)
		projectile.init(diamond_damage * GameManager.get_risk_dmg_mult(), diamond_speed)
		projectile.ricochet_count_left = pinball_ricochet_count

	state_chart.send_event("stop_shooting")

func _on_pinball_projectiles_recover_state_entered() -> void:
	debug_state_label.text = "Pinball Riochet | Recovering"

	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time, false).timeout
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
	anim_player.play("charge_telegraph")
	await anim_player.animation_finished
	anim_player.play("RESET")
	# await get_tree().create_timer(telegraph_time * 2, false).timeout
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
	charge_crack_interval_timer = 0
	spawn_charge_crack()

	navigation_component.disable()
	hurtbox.set_deferred("monitoring", true)
	hurtbox.body_entered.connect(_on_charge_collision)
	var charge_dir = self.global_position.direction_to(target.global_position)
	var charge_impulse = self.global_position.distance_to(target.global_position) * charge_force
	velocity += charge_dir * charge_impulse
	sfx_player.stream = sfx_charge.pick_random()
	sfx_player.play()
	# Speedline VFX
	var pe: Node3D = speedline_vfx_prefab.instantiate()
	add_child(pe)
	pe.global_position = global_position
	pe.look_at(pe.global_position + charge_dir)
	pe.rotate_y(deg_to_rad(90))


func _on_charge_collision(body: Node3D) -> void:
	if body == target:
		velocity = Vector3.ZERO
		body.health_component.damage(charge_damage * GameManager.get_risk_dmg_mult())
		hurtbox.body_entered.disconnect(_on_charge_collision)
		hurtbox.set_deferred("monitoring", false)

func _on_charge_charging_state_physics_processing(delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, 0.05)
	velocity.z = lerp(velocity.z, 0.0, 0.05)

	charge_crack_interval_timer += delta
	if charge_crack_interval_timer > CHARGE_CRACK_INTERVAL:
		charge_crack_interval_timer = 0
		spawn_charge_crack()


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

	await get_tree().create_timer(attack_recovery_time, false).timeout

	state_chart.send_event("cooldown_end")
	select_attack()
	state_chart.send_event("end_recovery")


func spawn_charge_crack():
	var inst = crack_decal_prefab.instantiate()
	get_tree().get_root().add_child(inst)
	var spawn_pos = Vector3(global_position.x, global_position.y - 1, global_position.z)
	if floor_raycast.is_colliding():
		spawn_pos = floor_raycast.get_collision_point() + Vector3(0, 0.1, 0)
	inst.global_position = spawn_pos

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
		if $StateChart/Root/Health/Dead.active:
			break
		bomb_drop_timer.start(bomb_drop_delay)
		await bomb_drop_timer.timeout
		#await get_tree().create_timer(bomb_drop_delay, false).timeout
		sfx_player.stream = sfx_bomb_launch.pick_random()
		sfx_player.play()
		var projectile := bomb_projectile.instantiate() as RigidBody3D
		projectile.init(bomb_damage * GameManager.get_risk_dmg_mult(), bomb_fuse_time)
		get_tree().get_root().add_child(projectile)
		projectile.global_position = projectile_spawn_marker.global_position
		projectile.global_rotation.y = self.global_rotation.y + (PI / 8 * dir_counter)
		projectile.apply_central_force(-projectile.global_basis.z * bomb_impulse)
		active_bombs.append(projectile)

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

	await get_tree().create_timer(attack_recovery_time, false).timeout

	state_chart.send_event("cooldown_end")
	select_attack()
	state_chart.send_event("end_recovery")


func _cleanup_bombs() -> void:
	bomb_drop_timer.stop()
	for bomb in active_bombs:
		if is_instance_valid(bomb):
			bomb.destroy(false)
	active_bombs = []


func _on_boss_collect_chip(chip: PokerChip):
	if !is_instance_valid(chip):
		return
	const CONFIRM_ABSORB_RANGE = 10
	var chip_distance = chip.global_position.distance_to(global_position)
	if chip_distance <= CONFIRM_ABSORB_RANGE:
		health_component.current_health += chip.value * chip_value_to_heal_ratio
		chip.queue_free()
	else:
		chip.absorbing_by_boss = false

func boss_suck_chip() -> void:
	if health_component.has_died:
		return

	for item in get_tree().get_nodes_in_group("currency_chips"):
		if item is PokerChip:
			var chip: PokerChip = item
			var chip_distance = chip.global_position.distance_to(global_position)
			if chip_distance <= absorb_chip_range and not chip.collecting_by_player:
				chip.absorbing_by_boss = true
				var chip_tween: Tween = get_tree().create_tween()
				chip_tween.tween_property(chip, "global_position", global_position, 0.5).set_ease(Tween.EASE_IN)
				chip_tween.tween_callback(_on_boss_collect_chip.bind(chip))


func _on_absorb_chip_timer_timeout() -> void:
	boss_suck_chip()
