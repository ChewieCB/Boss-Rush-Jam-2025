extends BaseComponent
class_name HealthComponent

signal health_changed(new_health: float, prev_health: float)
signal health_diff(diff: float)
signal died
signal hurt

@export_category("Health")
@export var max_health: float = 100
var current_health: float:
	set(value):
		if has_died or not enabled:
			return
		# Cache previous value so we can do dynamic health bars
		var prev_health = current_health
		current_health = clamp(value, 0, max_health)
		var diff = current_health - prev_health
		emit_signal("health_diff", diff)
		emit_signal("health_changed", current_health, prev_health)
		if current_health == 0:
			emit_signal("died")
			has_died = true
		if diff < 0:
			emit_signal("hurt")
var has_died: bool = false


func _ready() -> void:
	initialize_health()


func damage(_damage: float) -> void:
	if enabled:
		current_health -= _damage


func heal(health: float) -> void:
	if enabled:
		current_health += health


func initialize_health() -> void:
	current_health = max_health
