extends HealthBar
class_name BossHealthBar

@export var boss_name: String = "":
	set(value):
		boss_name = value
		if name_label:
			name_label.text = boss_name

@onready var name_label: Label = $VBoxContainer/MarginContainer/HBoxContainer/MarginContainer2/Label
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var status_container: Container = $VBoxContainer/StatusContainer

func _ready() -> void:
	super ()
	name_label.text = boss_name
	if health_component:
		init_health_ui(health_component.current_health)
		health_component.health_changed.connect(_on_health_changed)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.setting_ui.setting_changed.connect(check_after_setting_changed)
	check_after_setting_changed()


func check_after_setting_changed():
	visible = not GameManager.hide_ui


func show_ui() -> void:
	anim_player.play("show")


func hide_ui() -> void:
	anim_player.play("hide")


func change_status_label_visibility(status: BossCore.BossStatusEffect, set_to_visible: bool):
	var node_name: String = BossCore.BossStatusEffect.keys()[status].to_pascal_case()
	var found_node: Control = status_container.get_node(node_name)
	if found_node:
		found_node.visible = set_to_visible
