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
var force_next_spin_id: int = -1
var is_equipped = false
var last_chosen_queue = []

# TODO - reloads before spin for each barrel should be generated on save file creation, seeded
var reloads_before_spin: int
var reload_count: int = 0


func _ready() -> void:
	if owner_gun == null:
		return

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
	if force_next_spin_id >= 0:
		chosen_id = force_next_spin_id
		force_next_spin_id = -1
	else:
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


func instant_spin():
	chosen_id = randi_range(0, len(effect_list) - 1)
	get_active_effect().on_effect_set()


func get_active_effect() -> BaseBarrelEffect:
	return effect_list[chosen_id]


func get_less_used_effects() -> int:
	var effect_id: int = 0
	var chance: float = randf()
	var effect_size: int = effect_list.size()
	if effect_size <= 1:
		effect_id = 0
	else:
		match last_chosen_queue.size():
			# If we haven't chosen any effects, pick one at random
			0:
				effect_id = randi_range(0, effect_size - 1)
			# If we have chosen all effects previously, 50% pick least recent, 50% pick randomly
			effect_size:
				var same_barrel_chance = 0.5
				if GameManager.current_boss_map and GameManager.current_boss_map.is_tutorial:
					same_barrel_chance = -100
				if chance <= same_barrel_chance:
					effect_id = randi_range(0, effect_size - 1)
				else:
					effect_id = last_chosen_queue.back()
			# If we've chosen some, but not all, effects before, pick a random effect we haven't chosen yet
			_:
				# 20% chance to get same barrel, unless it tutorial room
				var same_barrel_chance = 0.2
				if GameManager.current_boss_map:
					if GameManager.current_boss_map.is_tutorial:
						same_barrel_chance = -100

				if chance <= same_barrel_chance:
					effect_id = last_chosen_queue.front()
				else:
					var unused_effects = range(0, effect_size)
					unused_effects = unused_effects.filter(
						func(id):
							return id not in last_chosen_queue
					)
					if unused_effects:
						effect_id = unused_effects.pick_random()

	return effect_id


func get_number_of_barrel_effect() -> int:
	return effect_container.get_child_count()

func get_barrel_effect_data_at(index: int) -> Dictionary:
	var barrel_effect: BaseBarrelEffect = effect_container.get_child(index)
	var is_archetype = false
	if barrel_effect.get("is_archetype") && barrel_effect.is_archetype:
		is_archetype = true
	var res = {
		"title": barrel_effect.display_text_title,
		"description": barrel_effect.display_text_tag,
		"is_archetype": is_archetype,
		"positive_desc": barrel_effect.positive_desc,
		"negative_desc": barrel_effect.negative_desc,
		"icon_id": barrel_effect.icon_id,
	 }
	return res
