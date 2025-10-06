extends Node3D
class_name SpinBarrel

signal barrel_effect_changed(SpinBarrel, BaseBarrelEffect)

@onready var effect_container: Node3D = $EffectContainer

const SPIN_INTERVAL = 0.1

var owner_gun: Gun
var effect_list: Array[BaseBarrelEffect] = []
var spin_interval_timer = 0
var is_spinning = false
var chosen_id: int:
	set(value):
		chosen_id = value
		barrel_effect_changed.emit(self, effect_list[chosen_id])
var is_equipped = false
var last_chosen_queue = []


func _ready() -> void:
	for child in effect_container.get_children():
		# This help with debugging, you can show/hide barrel effect to avoid
		# spamming spin barrel when testing it
		if child.visible:
			child.owner_barrel = self
			effect_list.append(child)
	chosen_id = 0
	effect_list.shuffle()
	instant_spin()


func start_spin():
	is_spinning = true


func stop_spin():
	is_spinning = false
	#prevent_roll_same_effect()
	chosen_id = get_less_used_effects()
	# When we pick a new effect, move it to the front of the last used queue
	# so we can deprioritise it next spin
	if chosen_id in last_chosen_queue:
		last_chosen_queue.pop_at(last_chosen_queue.find(chosen_id))
	last_chosen_queue.push_front(chosen_id)


func _process(delta: float) -> void:
	if not is_spinning:
		return

	spin_interval_timer += delta
	if spin_interval_timer > SPIN_INTERVAL:
		spin_interval_timer = 0
		chosen_id = randi_range(0, len(effect_list) - 1)
		#chosen_id = get_less_used_effects()


func instant_spin():
	chosen_id = randi_range(0, len(effect_list) - 1)


func get_active_effect():
	return effect_list[chosen_id]


func get_less_used_effects() -> int:
	var effect_id: int = -1
	var chance: float = randf()
	var max_idx: int = effect_list.size() - 1
	if max_idx == 0:
		effect_id = 0
	else:
		match last_chosen_queue.size():
			# If we haven't chosen any effects, pick one at random
			0:
				effect_id = randi_range(0, len(effect_list) - 1)
			# If we have chosen all effects previously, pick the least recent effect
			max_idx:
				# 20% chance to get same barrel
				if chance <= 0.4:
					effect_id = last_chosen_queue.front()
				elif chance <= 0.7:
					effect_id = last_chosen_queue[1]
				else:
					effect_id = last_chosen_queue.back()
			# If we've chosen some, but not all, effects before, pick a random effect we haven't chosen yet
			_:
				# 20% chance to get same barrel
				if chance <= 0.2:
					effect_id = last_chosen_queue.front()
				else:
					var unused_effects = range(0, len(effect_list))
					unused_effects = unused_effects.filter(
						func(id):
							return id not in last_chosen_queue
					)
					if unused_effects:
						if chance <= 0.6:
							effect_id = unused_effects.front()
						else:
							effect_id = unused_effects.back()
					#effect_id = unused_effects.pick_random()
	
	return effect_id


func get_number_of_barrel_effect() -> int:
	return effect_container.get_child_count()

func get_barrel_effect_data_at(index: int) -> Dictionary:
	var barrel_effect: BaseBarrelEffect = effect_container.get_child(index)
	var is_archetype = false
	if barrel_effect.get("is_archetype") && barrel_effect.is_archetype:
		is_archetype = true
	var res = {
		"display_text_title": barrel_effect.display_text_title,
		"display_text_tag": barrel_effect.display_text_tag,
		"is_archetype": is_archetype,
		"positive_desc": barrel_effect.positive_desc,
		"negative_desc": barrel_effect.negative_desc,
	 }
	return res
