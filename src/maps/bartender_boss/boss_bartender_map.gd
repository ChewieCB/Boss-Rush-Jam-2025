extends Node3D

@export var bgm: AudioStream

@export var boss: BossCore
@export var player: Player
@export var elevator_doors: ElevatorDoors

@export var win_subtext: Array[String]
@export var lose_tips: Array[String]
@export var directional_light: DirectionalLight3D

@onready var win_ui: Control = $UI/BossDefeatedUI
@onready var boss_trigger: Area3D = $BossTriggerVolume


func _ready() -> void:
	boss.died.connect(_on_boss_died)
	boss.defeated.connect(_on_boss_defeated)
	player.health_component.died.connect(_on_player_death)
	
	if GameManager.cached_player_pos_relative_to_elevator_doors:
		var player_start_pos: Vector3 = elevator_doors.global_position - GameManager.cached_player_pos_relative_to_elevator_doors
		player.global_position = player_start_pos
		player.rotation = GameManager.cached_player_rotation
		player.player_camera.rotation = GameManager.cached_camera_rotation
	
	elevator_doors.open()

func _on_boss_died() -> void:
	var tween = self.create_tween()
	tween.tween_property(directional_light, "light_energy", 0, 1)

func _on_boss_defeated(_boss: BossCore) -> void:
	win_ui.win("Floor Cleared", win_subtext.pick_random())
	show_end_panel()


func _on_player_death() -> void:
	win_ui.lose(lose_tips.pick_random())
	show_end_panel()


func show_end_panel() -> void:
	win_ui.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 1.0), 1.0)
	await tween.finished
	await get_tree().create_timer(2.5).timeout
	tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 0.0), 1.0)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://src/maps/lobby/Lobby.tscn"))


func _return_to_main() -> void:
	get_tree().change_scene_to_file("res://src/ui/temp/TempMain.tscn")


func _reload_scene() -> void:
	get_tree().reload_current_scene()

func _on_boss_trigger_volume_body_entered(body: Node3D) -> void:
	if body is Player:
		boss.activate()
		boss_trigger.queue_free()
		elevator_doors.close()
