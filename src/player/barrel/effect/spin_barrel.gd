extends Node3D
class_name SpinBarrel

@export var barrel_name: String

@onready var effect_container: Node3D = $EffectContainer
@onready var display_label: Label3D = $Label3D

var owner_gun: Gun
var effect_list: Array[BaseBarrelEffect] = []
var spin_interval_timer = 0
var is_spinning = false
var chosen_id = 0

const SPIN_INTERVAL = 0.1

func _ready() -> void:
	for child in effect_container.get_children():
		child.owner_barrel = self
		effect_list.append(child)
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
		display_label.text = effect_list[chosen_id].display_text


func instant_spin():
	chosen_id = randi_range(0, len(effect_list) - 1)
	display_label.text = effect_list[chosen_id].display_text

func get_active_effect():
	return effect_list[chosen_id]