extends Node3D
class_name BossMap

@export var bgm: AudioStream

@export_group("Actors")
@export var boss: BossCore
@onready var player: Player = find_children("*", "Player").front()
@onready var elevator_doors: ElevatorDoors = find_children("*", "ElevatorDoors").front()

@export_group("UI")
@export var win_subtext: Array[String]
@export var lose_tips: Array[String]
@onready var win_ui: Control = $UI/BossDefeatedUI

@export var directional_light: DirectionalLight3D

@onready var boss_trigger: Area3D = $BossTriggerVolume
@onready var spin_trigger: Area3D = $SpinTriggerVolume


func _ready() -> void:
	# Pre-load the lobby scene for faster level transitions
	LoadingHandler.current_scene_path = "res://src/maps/lobby/Lobby.tscn"
	# Connect UI signals
	if boss:
		boss.died.connect(_on_boss_died)
		boss.defeated.connect(_on_boss_defeated)
	player.health_component.died.connect(_on_player_death)
	# Sync the player's location in the elevator from the lobby
	var player_start_pos: Vector3 = elevator_doors.global_position - GameManager.cached_player_pos_relative_to_elevator_doors
	player.global_position = player_start_pos
	player.rotation = GameManager.cached_player_rotation
	player.player_camera.rotation = GameManager.cached_camera_rotation
	
	elevator_doors.open()


func show_end_panel() -> void:
	LuckHandler.enabled = false
	win_ui.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 1.0), 1.0)
	await tween.finished
	await get_tree().create_timer(2.5).timeout
	tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 0.0), 1.0)
	await tween.finished
	
	LoadingHandler.start_loading("Lobby")


func collect_all_chips() -> void:
	for chip in get_tree().get_nodes_in_group("currency_chips"):
		var chip_tween: Tween = get_tree().create_tween()
		chip_tween.tween_property(chip, "global_position", player.global_position, 0.1).set_ease(Tween.EASE_IN)


func _on_boss_died(boss: BossCore = boss) -> void:
	var tween = self.create_tween()
	tween.tween_property(directional_light, "light_energy", 0, 1)


func _on_boss_defeated(_boss: BossCore) -> void:
	collect_all_chips()
	win_ui.win("Floor Cleared", win_subtext.pick_random())
	show_end_panel()


func _on_player_death() -> void:
	win_ui.lose(lose_tips.pick_random())
	show_end_panel()


func _on_boss_trigger_volume_body_entered(body: Node3D) -> void:
	boss.activate()
	LuckHandler.enabled = true
	elevator_doors.close()
	boss_trigger.queue_free()


func _on_spin_trigger_body_entered(body: Node3D) -> void:
	spin_trigger.monitoring = false
	spin_trigger.queue_free()
	body.current_gun.spin_all_barrels()
