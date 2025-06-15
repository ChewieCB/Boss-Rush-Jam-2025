extends BaseComponent
class_name HealthComponent

signal health_changed(new_health: float, prev_health: float)
signal health_diff(diff: float)
signal died
signal hurt

@export_category("Health")
@export var is_invincible: bool = false
@export var max_health: float = 100
@export var show_damage_text: bool = true
@export var text_effect: PackedScene
@export var text_effect_location: Node3D

var received_dmg_multiplier = 1

var current_health: float:
	set(value):
		if has_died or not enabled:
			if has_died and value > 0:
				has_died = false
			else:
				return
		# Cache previous value so we can do dynamic health bars
		var prev_health = current_health
		current_health = clamp(value, 0, max_health)
		var diff = current_health - prev_health
		current_health_ratio = current_health / max_health
		health_diff.emit(diff)
		health_changed.emit(current_health, prev_health)
		if current_health == 0:
			has_died = true
			died.emit()
		if diff < 0:
			hurt.emit()
var current_health_ratio: float = current_health / max_health
var has_died: bool = false


func _ready() -> void:
	initialize_health()


func damage(_damage: float, _color: Color = Color.WHITE) -> void:
	_damage = round(_damage * received_dmg_multiplier)
	if enabled:
		if not is_invincible:
			current_health -= _damage
		if show_damage_text and not is_invincible:
			if not text_effect:
				return
			if text_effect_location:
				create_text(text_effect_location.global_position, str(_damage), _color)
			else:
				create_text(self.global_position, str(_damage), _color)

func heal(health: float, _color: Color = Color.GREEN) -> void:
	if enabled:
		current_health += health
		if show_damage_text:
			if not text_effect:
				return
			if text_effect_location:
				create_text(text_effect_location.global_position, str(health), _color)
			else:
				create_text(self.global_position, str(health), _color)


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
