extends BaseComponent
class_name HealthComponent

signal health_changed(new_health: float, prev_health: float)
signal health_diff(diff: float)
signal died
signal hurt

@export_category("Health")
@export var max_health: float = 100
@export var text_effect: PackedScene
@export var text_effect_location: Node3D


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


func damage(_damage: float, _color: Color = Color.WHITE) -> void:
	if enabled:
		current_health -= _damage
		if text_effect_location:
			create_text(text_effect_location.global_position, str(_damage), _color)
		else:
			create_text(self.global_position, str(_damage), _color)

func heal(health: float) -> void:
	if enabled:
		current_health += health


func initialize_health() -> void:
	current_health = max_health

func create_text(pos: Vector3, text: String, color: Color = Color.WHITE, size: float = 92.0) -> void:
	var text_inst = text_effect.instantiate()
	get_parent().add_child(text_inst)
	var variance = 1
	var rand_x = randf_range(-variance, variance)
	var rand_y = randf_range(-variance, variance)
	var rand_z = randf_range(-variance, variance)
	text_inst.text = text
	text_inst.modulate = color
	text_inst.font_size = size
	text_inst.outline_size = size / 2
	text_inst.global_position = pos + Vector3(rand_x, rand_y, rand_z)