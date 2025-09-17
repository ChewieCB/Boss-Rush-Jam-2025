extends BossMap

@onready var music_player: AudioStreamPlayer = $InteractiveMusicPlayer
var music_playback: AudioStreamPlaybackInteractive
#
@onready var chiptopede_spawns: Array[Node] = get_tree().get_nodes_in_group("boss_worm_spawn_marker")
@onready var chiptopede_snake_spawns: Array[Node] = get_tree().get_nodes_in_group("boss_snake_spawn_marker")
@onready var chiptopede_snake_path_points: Array[Node] = get_tree().get_nodes_in_group("boss_snake_path_marker")
@onready var chiptopede_shoot_spawns: Array[Node] = get_tree().get_nodes_in_group("boss_shoot_spawn_marker")

# Flooding/Draining levels
@export var lower_water_level: float = -0.1
@export var upper_water_level: float = 1.3
@export var platform_level: float = 2.0
@export var water_raise_time: float = 4.0
@export var waterfall_speed: float = 1.0
@onready var waterfalls: Node3D = $Waterfalls
@export var waterfall_meshes: Array[Node3D]
@export var waterfall_meshses_vertical: Array[Node3D]
@onready var water_surface: MeshInstance3D = $WaterSurfaceMesh
@onready var rising_platforms: Array[Node] = get_tree().get_nodes_in_group("rising_platforms")

@onready var SFXBeerPlayer: AudioStreamPlayer3D = $SFXBeerPlayer
@onready var SFXBeerPlayer2: AudioStreamPlayer3D = $SFXBeerPlayer2
@onready var SFXBeerFlood: AudioStreamPlayer3D = $SFXBeerFlood
@onready var SFXBeerFlood2: AudioStreamPlayer3D = $SFXBeerFlood2
@onready var SFXFloorBreak: AudioStreamPlayer3D = $SFXFloorBreak

# Water damage
@onready var water_damage_timer: Timer = $WaterDamageTimer
@export var water_damage_tick: float = 1.0
@export var water_damage_amount: float = 2.0
var water_damage_enabled = false
const DRUNK_DURATION = 5.0
@export var splash_particle_prefab: PackedScene
@export var sfx_splash: Array[AudioStream]

@export var breakable_floor: Node3D
@onready var collapse_fire_particles: GPUParticles3D = $FloorCollapseFire
@onready var collapse_smoke_particles: GPUParticles3D = $FloorCollapseSmoke


func _ready() -> void:
	super ()
	boss.flood_chamber.connect(raise_water)
	boss.drain_chamber.connect(lower_water)
	boss.break_floor.connect(break_floor)
	
	boss.chiptopede_spawns = chiptopede_spawns
	boss.chiptopede_snake_spawns = chiptopede_snake_spawns
	boss.chiptopede_snake_path_points = chiptopede_snake_path_points
	boss.chiptopede_shoot_spawns = chiptopede_shoot_spawns

	waterfalls.visible = false
	for mesh in waterfall_meshses_vertical:
		mesh.scale.x = 0
	water_surface.global_position.y = lower_water_level
	
	music_playback = music_player.get_stream_playback()

	if GameManager.boss_ante >= 5:
		water_damage_enabled = true


func _process(delta) -> void:
	if waterfalls.visible:
		for mesh in waterfall_meshes:
			mesh.mesh.surface_get_material(0).uv1_offset.x -= delta * waterfall_speed


func _on_boss_trigger_volume_body_entered(_body: Node3D) -> void:
	music_playback.switch_to_clip(1)
	super (_body)


func _on_boss_defeated(_boss: BossCore) -> void:
	collect_all_chips()
	
	if boss.current_phase != 3:
		# Wait for the bar to end then transition
		# TODO
		boss.state_chart.send_event("start_phase_3")
		await boss.chiptopede_emerges
		music_playback.switch_to_clip(3)
	else:
		win_ui.show_text("Floor Cleared", win_subtext.pick_random())
		print("Chips dropped: %s | Total chip value: %s" % [chips_dropped, chip_value_collected])
		
		if not boss.boss_id in GameManager.bosses_defeated:
			GameManager.bosses_defeated.append(boss.boss_id)
			print(GameManager.bosses_defeated)
			GameManager.all_bosses_defeated = GameManager.bosses_defeated.size() == BossCore.BossIdEnum.size() - 1

		reward_bet_money()
		show_end_panel()


func _on_boss_died(_boss: BossCore = boss) -> void:
	if boss.current_phase != 3:
		music_playback.switch_to_clip(2)
		return
	super (_boss)


#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("input_1"):
		#break_floor()
		#raise_water()
	#elif event.is_action_pressed("input_2"):
		#lower_water()


func break_floor() -> void:
	# Screen shake for a beat
	InputHelper.start_rumble_large()
	collapse_fire_particles.emitting = true
	collapse_smoke_particles.emitting = true
	player.player_camera.add_long_trauma(0.7)
	await get_tree().create_timer(4.0).timeout
	SFXFloorBreak.play()
	collapse_fire_particles.emitting = false
	collapse_smoke_particles.emitting = false
	InputHelper.stop_rumble()
	player.player_camera.trauma = 0.0
	player.player_camera.long_trauma = 0.0
	player.player_camera.final_trauma = 0.0
	
	water_surface.visible = true
	water_surface.global_position.y = -20
	if breakable_floor:
		breakable_floor.queue_free()
	for platform in rising_platforms:
		platform.queue_free()


func _rebake_nav() -> void:
	if nav_region.is_baking():
		await nav_region.bake_finished
	nav_region.bake_navigation_mesh()


func raise_water() -> void:
	SFXBeerPlayer.play()
	SFXBeerPlayer2.play()
	SFXBeerFlood.play()
	SFXBeerFlood2.play()
	waterfalls.visible = true
	var water_tween: Tween = get_tree().create_tween()
	for mesh in waterfall_meshses_vertical:
		water_tween.parallel().tween_property(
			mesh,
			"scale:x",
			1.0,
			water_raise_time / 3
		)
		get_node("WaterfallArea").set_deferred("monitoring", true)
	water_tween.chain().tween_property(water_surface, "global_position:y", upper_water_level, water_raise_time)
	
	for platform in rising_platforms:
		platform.raise(platform_level, 1.4)
	
	
	await water_tween.finished


func lower_water() -> void:
	waterfalls.visible = false
	var water_tween: Tween = get_tree().create_tween()
	water_tween.tween_property(water_surface, "global_position:y", lower_water_level, 1.4)
	for platform in rising_platforms:
		platform.lower(1.4)
	
	await water_tween.finished


func _on_water_damage_area_body_entered(body: Node3D) -> void:
	# Add splash at location
	var splash = splash_particle_prefab.instantiate()
	add_child(splash)
	splash.global_position = body.global_position
	splash.global_position.y = water_surface.global_position.y
	# Scale up the splash particles for the player
	if body is Player:
		splash.draw_pass_1.size = Vector2(3, 3)
		splash.amount = 16
		splash.get_child(0).draw_pass_1.size = Vector2(3, 3)
		SoundManager.play_sound(sfx_splash.pick_random(), "SFX")
	elif body is ChiptopedeSegment:
		splash.draw_pass_1.size = Vector2(7, 7)
		splash.amount = 32
		splash.get_child(0).draw_pass_1.size = Vector2(7, 7)
	splash.emitting = true
	
	# Add drunk effect instead of damage
	# TODO - apply by building up a threshold instead of on/off
	if body is Player:
		player.apply_drunk_status(DRUNK_DURATION)
		water_damage_timer.start(water_damage_tick)
		if water_damage_enabled:
			player.health_component.damage(water_damage_amount)
		
	await splash.finished
	splash.queue_free()


func _on_water_damage_area_area_entered(area: Area3D) -> void:
	# Add splash at location
	var splash = splash_particle_prefab.instantiate()
	add_child(splash)
	splash.global_position = area.global_position
	splash.global_position.y = water_surface.global_position.y
	splash.emitting = true


func _on_waterfall_body_entered(body: Node3D) -> void:
	# Add splash at location
	var splash = splash_particle_prefab.instantiate()
	add_child(splash)
	splash.global_position = body.global_position
	# Scale up the splash particles for the player
	if body is Player:
		splash.draw_pass_1.size = Vector2(3, 3)
		splash.amount = 16
		splash.get_child(0).draw_pass_1.size = Vector2(3, 3)
		SoundManager.play_sound(sfx_splash.pick_random(), "SFX")
	elif body is ChiptopedeSegment:
		splash.draw_pass_1.size = Vector2(7, 7)
		splash.amount = 32
		splash.get_child(0).draw_pass_1.size = Vector2(7, 7)
	splash.emitting = true
	
	# Add drunk effect instead of damage
	# TODO - apply by building up a threshold instead of on/off
	if body is Player:
		player.apply_drunk_status(DRUNK_DURATION)
		water_damage_timer.start(water_damage_tick)
		if water_damage_enabled:
			player.health_component.damage(water_damage_amount)
		
	await splash.finished
	splash.queue_free()

func _on_waterfall_area_entered(area: Area3D) -> void:
	# Add splash at location
	var splash = splash_particle_prefab.instantiate()
	add_child(splash)
	splash.global_position = area.global_position
	splash.emitting = true


func _on_water_damage_area_body_exited(body: Node3D) -> void:
	if body is Player:
		water_damage_timer.stop()


func _on_water_damage_timer_timeout() -> void:
	player.apply_drunk_status(DRUNK_DURATION)
	if water_damage_enabled:
		player.health_component.damage(water_damage_amount)
