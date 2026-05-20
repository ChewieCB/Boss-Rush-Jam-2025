extends MarginContainer
class_name HealthBar

signal show
signal hide

@export_category("Components")
@export var health_component: HealthComponent

@export var show_on_ready: bool = true
@export var animate_show_hide: bool = true
@export var hide_ui_on_death: bool = false

@export var timer: Timer
@export var health_bar: TextureProgressBar
@export var damage_bar: TextureProgressBar
@export var health_label: Label

func _ready() -> void:
	await get_owner().ready
	#if show_on_ready:
		#show_ui()


func init_health_ui(_health) -> void:
	health_bar.max_value = _health
	health_bar.value = _health
	damage_bar.max_value = _health
	damage_bar.value = _health
	health_label.text = "%s/%s" % [health_bar.value, health_bar.max_value]


func _on_health_changed(new_health: float, prev_health: float) -> void:
	health_label.text = "%s/%s" % [health_bar.value, health_bar.max_value]
	if new_health < prev_health:
		health_bar.value = new_health
		timer.start()
	else:
		damage_bar.value = new_health
		await get_tree().create_timer(0.3).timeout
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(health_bar, "value", new_health, 0.4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		await tween.finished
		health_bar.value = new_health

func _on_max_health_changed(new_max_health: float, _prev_max_health: float) -> void:
	damage_bar.max_value = new_max_health
	health_bar.max_value = new_max_health


func _on_timer_timeout():
	damage_bar.value = health_component.current_health
