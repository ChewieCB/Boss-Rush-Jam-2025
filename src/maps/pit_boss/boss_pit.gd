extends BossMap

@export var active_bgm: AudioStream

## Boss Tracking
@onready var pit_boss: BossPit = find_children("*", "BossPit").front()
@onready var surveillance_boss: BossSurveillance = find_children("*", "BossSurveillance").front()
var dead_boss_count: int = 0
## Boss Stance & Phase Triggers
@onready var stance_timer: Timer = $StanceTimer
@export var phase_2_stance_time: float = 14.0
@export var phase_2_health_percentage_trigger: float = 0.7
@export var phase_3_health_percentage_trigger: float = 0.35
## Spawns
# Turrets
@onready var turret_spawns: Array = find_children("*", "TurretSpawnPoint")
# Cover
@export var cover_spawn_scene: PackedScene
@onready var initial_cover = find_children("*", "Cover")
var cover_objects: Array = []
var cover_spawn_points: Array = []


func _ready() -> void:
	await super()
	
	pit_boss.health_component.health_changed.connect(_on_boss_health_changed)
	pit_boss.health_component.died.connect(_on_boss_died.bind(pit_boss))
	pit_boss.surveillance_boss = surveillance_boss
	
	surveillance_boss.health_component.health_changed.connect(_on_boss_health_changed)
	surveillance_boss.health_component.died.connect(_on_boss_died.bind(surveillance_boss))
	surveillance_boss.turret_spawns = turret_spawns
	surveillance_boss.pit_boss = pit_boss
	
	for cover in initial_cover:
		var new_spawn = cover_spawn_scene.instantiate()
		nav_region.add_child(new_spawn)
		new_spawn.global_transform = cover.global_transform
		new_spawn.cover_type = cover._get_class()
		new_spawn.current_cover = cover
		cover.cover_destroyed.connect(_on_cover_destroyed)
		cover_spawn_points.push_back(new_spawn)
	for cover in initial_cover:
		cover.queue_free()


func _on_boss_health_changed(_new_health: float, _prev_health: float) -> void:
	var combined_current_health := pit_boss.health_component.current_health + surveillance_boss.health_component.current_health
	var combined_max_health := pit_boss.health_component.max_health + surveillance_boss.health_component.max_health
	var combined_health_ratio := combined_current_health / combined_max_health
	
	if combined_health_ratio <= phase_3_health_percentage_trigger:
		stance_timer.stop()
		pit_boss.state_chart.send_event("start_phase_3")
		surveillance_boss.state_chart.send_event("start_phase_3")
	elif pit_boss.health_component.current_health_ratio <= phase_2_health_percentage_trigger:
		if pit_boss.current_phase < 2 and surveillance_boss.current_phase < 2:
			stance_timer.stop()
			pit_boss.state_chart.send_event("start_phase_2")
			surveillance_boss.state_chart.send_event("start_phase_2")
			stance_timer.start(phase_2_stance_time + randf_range(-1.5, 1.5))


func _on_boss_died(boss: BossCore = boss) -> void:
	dead_boss_count += 1
	
	if dead_boss_count == 2:
		boss.defeated.connect(_on_bosses_defeated)
		boss.drop_barrel()
		var tween = self.create_tween()
		tween.tween_property(directional_light, "light_energy", 0, 1)
	
	var remaining_boss: BossCore
	match boss:
		pit_boss:
			remaining_boss = surveillance_boss
		surveillance_boss:
			remaining_boss = pit_boss
	remaining_boss.state_chart.send_event("start_phase_3")


func _on_bosses_defeated(_boss: BossCore) -> void:
	if _boss.boss_id != BossCore.BossIdEnum.NONE && not _boss.boss_id in GameManager.bosses_defeated:
		GameManager.bosses_defeated.append(_boss.boss_id)
		GameManager.all_bosses_defeated = GameManager.bosses_defeated.size() == 4
	
	collect_all_chips()
	
	var tween = self.create_tween()
	tween.tween_property(directional_light, "light_energy", 0, 1)


func spawn_cover() -> void:
	for object in cover_spawn_points:
		var cover = object.spawn_cover()
		object.remove_child(cover)
		nav_region.add_child(cover)
		cover.global_transform = object.global_transform
		cover.show_cover()
		cover.cover_destroyed.connect(_on_cover_destroyed)
		cover_objects.append(cover)
	_rebake_nav()


func _on_cover_destroyed(cover: Cover) -> void:
	var spawn = cover_spawn_points.filter(func(x): return x.current_cover == cover).front()
	cover_objects.erase(cover)
	_rebake_nav()
	await get_tree().create_timer(randf_range(3.0, 6.5)).timeout
	
	spawn.current_cover = null
	
	var new_cover = spawn.spawn_cover()
	spawn.remove_child(new_cover)
	nav_region.add_child(new_cover)
	new_cover.global_transform = spawn.global_transform
	new_cover.show_cover()
	new_cover.cover_destroyed.connect(_on_cover_destroyed)
	cover_objects.append(new_cover)
	
	nav_region.bake_navigation_mesh()


func _on_boss_trigger_volume_body_entered(body: Node3D) -> void:
	spawn_cover()
	surveillance_boss.activate()
	pit_boss.activate()
	SoundManager.play_music(active_bgm, 0.1, "BGM")
	elevator_doors.close()
	LuckHandler.enabled = true
	boss_trigger.queue_free()


func _on_stance_timer_timeout() -> void:
	pit_boss.toggle_stance()
	surveillance_boss.toggle_stance()
	stance_timer.start(phase_2_stance_time + randf_range(-1.5, 1.5))
