extends Node3D
class_name SpinBarrel

signal barrel_effect_changed(SpinBarrel, BaseBarrelEffect)

@onready var effect_container: Node3D = $EffectContainer

var owner_gun: Gun
var effect_list: Array[BaseBarrelEffect] = []
var spin_interval_timer = 0
var is_spinning = false
var chosen_id: int:
	set(value):
		chosen_id = value
		barrel_effect_changed.emit(self, effect_list[chosen_id])
var is_equipped = false

const SPIN_INTERVAL = 0.1

func _ready() -> void:
	for child in effect_container.get_children():
		# This help with debugging, you can show/hide barrel effect to avoid
		# spamming spin barrel when testing it
		if child.visible:
			child.owner_barrel = self
			effect_list.append(child)
	chosen_id = 0
	instant_spin()


func start_spin():
	is_spinning = true

func stop_spin():
	is_spinning = false

func _process(delta: float) -> void:
	if not is_spinning:
		return

	spin_interval_timer += delta
	if spin_interval_timer > SPIN_INTERVAL:
		spin_interval_timer = 0
		chosen_id = randi_range(0, len(effect_list) - 1)


func instant_spin():
	chosen_id = randi_range(0, len(effect_list) - 1)


func get_active_effect():
	return effect_list[chosen_id]
