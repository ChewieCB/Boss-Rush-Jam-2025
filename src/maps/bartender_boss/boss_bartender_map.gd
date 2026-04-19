extends BossMap

@export_group("Flame Countertop")
@export var first_countertop_flame_marker: Marker3D
@export var countertop_flame_prefab: PackedScene
@onready var countertop_flame_holder: Node3D = $CountertopFlamingWallHolder
@onready var countertop_flame_duration_timer: Timer = $CountertopFlamingWallHolder/CountertopFlameTimer
@export_group("Stage Light")
@export var chandellier_lights: Array[StaticBody3D] = []
@export_group("SFX")
@export var sfx_fire_start: AudioStream
@export var sfx_fire_loop: AudioStream

var countertop_is_on_fire = false
const COUNTERTOP_FLAME_DISTANCE = 3.5
const COUNTERTOP_FLAME_COUNT = 10
const TIME_BETWEEN_COUTNERTOP_FIRE_SPAWN = 0.2

func _ready() -> void:
	boss.fire_started.connect(_on_fire_started)
	boss.boss_map = self
	super ()
	toggle_light(false)
	await get_tree().create_timer(5).timeout
	toggle_light(true)
	await get_tree().create_timer(5).timeout
	toggle_light(false)

func create_countertop_flame_wall(duration = 10) -> void:
	if countertop_is_on_fire:
		return
	for i in range(COUNTERTOP_FLAME_COUNT):
		var inst: HazardArea = countertop_flame_prefab.instantiate()
		inst.duration = duration
		countertop_flame_holder.add_child(inst)
		if i == 0:
			inst.global_position = first_countertop_flame_marker.global_position
		else:
			inst.global_position = first_countertop_flame_marker.global_position + Vector3((COUNTERTOP_FLAME_DISTANCE * i), 0, 0)
		await get_tree().create_timer(TIME_BETWEEN_COUTNERTOP_FIRE_SPAWN).timeout
	countertop_is_on_fire = true
	countertop_flame_duration_timer.start(duration)


func toggle_light(is_on: bool):
	directional_light.visible = is_on
	for item in chandellier_lights:
		if item.has_method("toggle_light"):
			item.toggle_light(is_on)


func _on_fire_started() -> void:
	var fire_sfx = SoundManager.play_ambient_sound(sfx_fire_start, 0.2, "SFX")
	fire_sfx.finished.connect(func():
		SoundManager.play_ambient_sound(sfx_fire_loop, 0.1, "SFX")
	)


func _on_player_death() -> void:
	SoundManager.stop_ambient_sound(sfx_fire_loop, 0.5)
	super ()


func _on_boss_defeated(_boss: BossCore) -> void:
	SoundManager.stop_ambient_sound(sfx_fire_loop, 0.5)
	super (_boss)


func _on_countertop_flame_timer_timeout() -> void:
	countertop_is_on_fire = false
