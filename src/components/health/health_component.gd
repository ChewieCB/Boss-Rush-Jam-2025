extends BaseComponent
class_name HealthComponent

signal health_changed(new_health: float, prev_health: float)
signal max_health_changed(new_max_health: float, prev_max_health: float)
signal health_diff(diff: float)
signal died
signal hurt

@export_category("Health")
@export var is_invincible: bool = false
@export var max_health: float = 100:
	set(value):
		var prev_max_health = max_health
		max_health = value
		max_health_changed.emit(max_health, prev_max_health)
@export var show_damage_text: bool = true
@export var text_effect: PackedScene
@export var text_effect_location: Node3D

var received_dmg_multiplier = 1
var heal_multiplier = 1
var is_owned_by_player = false

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
		if current_health <= 0:
			has_died = true
			died.emit()
		if diff < 0:
			hurt.emit()
var current_health_ratio: float = current_health / max_health
var has_died: bool = false


func _ready() -> void:
	initialize_health()


func damage(_damage: float, color: Color = Color.WHITE, text_scale_pop: float = 1.3, detail_text: String = "") -> void:
	_damage = round(_damage * received_dmg_multiplier)
	if enabled:
		if not is_invincible:
			current_health -= _damage
		if show_damage_text and not is_invincible:
			if not text_effect:
				return
			
			var text_str: String = str(_damage)
			if detail_text:
				text_str = detail_text + "\n" + text_str
			
			if text_effect_location:
				create_text(text_effect_location.global_position, text_str, color, text_scale_pop)
			else:
				create_text(self.global_position, text_str, color, text_scale_pop)

func heal(health: float, color: Color = Color.GREEN, text_scale_pop: float = 1.3) -> void:
	if enabled:
		var health_amount: float = health * heal_multiplier
		if is_owned_by_player:
			health_amount *= GameManager.get_risk_healing_effectiveness_mult()
		current_health += round(health_amount)
		if show_damage_text:
			if not text_effect:
				return
			if text_effect_location:
				create_text(text_effect_location.global_position, str(health), color, text_scale_pop)
			else:
				create_text(self.global_position, str(health), color, text_scale_pop)


func initialize_health() -> void:
	current_health = max_health

func create_text(pos: Vector3, text: String, color: Color = Color.WHITE, text_scale_pop: float = 1.3, text_size: float = 92.0) -> void:
	if GameManager.hide_damage_number:
		return
	var text_inst: HitText = text_effect.instantiate()
	get_parent().add_child(text_inst)
	var variance = 1
	var rand_x = randf_range(-variance, variance)
	var rand_y = randf_range(-variance, variance)
	var rand_z = randf_range(-variance, variance)
	text_inst.text = text
	text_inst.modulate = color
	text_inst.scale_pop = text_scale_pop
	text_inst.font_size = int(text_size)
	text_inst.outline_size = round(text_size / 2.0)
	text_inst.global_position = pos + Vector3(rand_x, rand_y, rand_z)
	text_inst.activate()
