extends Node3D

@export var boss: BossCore
@export var player: Player

@onready var win_ui: Control = $UI/BossDefeatedUI

func _ready() -> void:
	boss.health_component.died.connect(_on_boss_defeated)
	player.health_component.died.connect(_on_player_death)


func _on_boss_defeated() -> void:
	win_ui.win()
	show_end_panel()


func _on_player_death() -> void:
	win_ui.lose()
	show_end_panel()


func show_end_panel() -> void:
	win_ui.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 1.0), 1.0)
	await tween.finished
	await get_tree().create_timer(5.0).timeout
	tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 0.0), 1.0)
	tween.tween_callback(_return_to_main)


func _return_to_main() -> void:
	get_tree().change_scene_to_file("res://src/ui/temp/TempMain.tscn")
