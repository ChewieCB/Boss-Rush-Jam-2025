extends MarginContainer
class_name HealthBar

signal show
signal hide

@export_category("Components")
@export var health_component: HealthComponent

@export var show_on_ready: bool = true
@export var animate_show_hide: bool = true
@export var hide_ui_on_death: bool = false

@onready var timer: Timer = $VBoxContainer/MarginContainer2/MarginContainer/HealthBar/Timer
@onready var heath_bar: TextureProgressBar = $VBoxContainer/MarginContainer2/MarginContainer/HealthBar
@onready var damage_bar: TextureProgressBar = $VBoxContainer/MarginContainer2/MarginContainer/HealthBar/DamageBar
@onready var health_label: Label = $VBoxContainer/MarginContainer2/MarginContainer/Label


func _ready() -> void:
	await get_owner().ready
	#if show_on_ready:
		#show_ui()


func _process(_delta: float) -> void:
	health_label.text = "%s/%s" % [heath_bar.value, heath_bar.max_value]


func init_health_ui(_health) -> void:
	heath_bar.max_value = _health
	heath_bar.value = _health
	damage_bar.max_value = _health
	damage_bar.value = _health
	health_label.text = "%s/%s" % [heath_bar.value, heath_bar.max_value]


func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		heath_bar.value = new_health
		timer.start()
	else:
		damage_bar.value = new_health
		await get_tree().create_timer(0.3).timeout
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(heath_bar, "value", new_health, 0.4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		await tween.finished
		heath_bar.value = new_health


func _on_timer_timeout():
	damage_bar.value = health_component.current_health
