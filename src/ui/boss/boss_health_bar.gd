extends HealthBar

@export var boss_name: String = ""

@onready var name_label: Label = $VBoxContainer/MarginContainer/HBoxContainer/MarginContainer2/Label
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	super()
	name_label.text = boss_name
	if health_component:
		init_health_ui(health_component.current_health)
		health_component.health_changed.connect(_on_health_changed)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.setting_ui.setting_changed.connect(check_after_setting_changed)


func check_after_setting_changed():
	visible = not GameManager.hide_ui


func show_ui() -> void:
	anim_player.play("show")


func hide_ui() -> void:
	anim_player.play("hide")
