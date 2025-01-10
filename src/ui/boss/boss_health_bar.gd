extends MarginContainer
class_name HealthBar

@export_category("Components")
@export var health_component: HealthComponent

@export var show_on_ready: bool = true
@export var hide_ui_on_death: bool = false

@onready var timer: Timer = $VBoxContainer/MarginContainer2/MarginContainer/HealthBar/Timer
@onready var heath_bar: TextureProgressBar = $VBoxContainer/MarginContainer2/MarginContainer/HealthBar
@onready var damage_bar: TextureProgressBar = $VBoxContainer/MarginContainer2/MarginContainer/HealthBar/DamageBar
@onready var health_label: Label = $VBoxContainer/MarginContainer2/MarginContainer/Label
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	await get_owner().ready
	if health_component:
		init_health_ui(health_component.current_health)
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
	if show_on_ready:
		show_ui()


func init_health_ui(_health) -> void:
	heath_bar.max_value = _health
	heath_bar.value = _health
	damage_bar.max_value = _health
	damage_bar.value = _health
	health_label.text = "%s/%s" % [heath_bar.value, heath_bar.max_value]


func show_ui() -> void:
	anim_player.play("show")


func hide_ui() -> void:
	anim_player.play("hide")


func _on_health_changed(new_health: float, prev_health: float) -> void:
	heath_bar.value = new_health
	health_label.text = "%s/%s" % [heath_bar.value, heath_bar.max_value]
	
	if new_health < prev_health:
		timer.start()
	else:
		damage_bar.value = new_health


func _on_died() -> void:
	if hide_ui_on_death:
		hide_ui()


func _on_timer_timeout():
	damage_bar.value = health_component.current_health
	
