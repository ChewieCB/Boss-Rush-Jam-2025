extends BossCore
class_name BossBlackjack

signal hand_attack_finished(hand)
signal all_hand_attacks_finished

@onready var hand_anchor: Marker3D = $HandAnchor
@export var hand_spawn_pos: Marker3D
@export var hand_scene: PackedScene
@export var hand_spacing: float = 5.0
var spawned_hands = []
var finished_hands = []
var last_hand

# Intro
@export var intro_path_points: Array[Marker3D] = []


func _ready() -> void:
	super()
	self.global_position = intro_path_points[0].global_position


func activate() -> void:
	super()
	navigation_component.follow_target = false
	navigation_component.enable()
	if not self.is_node_ready():
		await self.ready
	state_chart.send_event("start_intro")


## HAND HELPER METHODS
# Since the floating hands are CharacterBody3D instances
# with their own state charts, we direct them here.
#
# Spawn/despawn methods
func spawn_hand(is_instant: bool = false) -> BlackjackHand:
	var new_hand := hand_scene.instantiate()
	spawned_hands.append(new_hand)
	scene_root.add_child(new_hand)
	
	# Set hand spawn position
	new_hand.position = Vector3.ZERO
	new_hand.global_position = hand_spawn_pos.global_position
	
	var args = [new_hand, 0.0] if is_instant else [new_hand]
	await _anchor_hand.bind(args)
	
	return new_hand


# Move the hand scene to a child of the boss so they can move together
func _anchor_hand(hand: BlackjackHand, move_time: float = 0.6) -> void:
	# Hands are placed alternating left to right from the center, spaced evenly from the nearest hand.
	# So we can work out the spacing by setting a hand spacing variable and determining
	# the sign of the X pos offset by using the modulo operator to check even/odd indexes
	# in the array of spawned hands.
	var hand_idx = spawned_hands.find(hand)
	var lr_sign: int = 1 if hand_idx % 2 == 0 else -1
	var idx_spacing = ceil(float(hand_idx + 1) / 2)
	var hand_offset := Vector3(hand_spacing * idx_spacing * lr_sign, 2.0 * (idx_spacing - 1), 0)
	
	var spawn_tween := get_tree().create_tween()
	spawn_tween.tween_property(hand, "global_position", self.global_position + hand_offset, move_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await spawn_tween.finished
	
	# Move the hand node inside of the boss to anchor
	var hand_parent: Node3D = hand.get_parent()
	if hand_parent:
		hand_parent.remove_child(hand)
	
	hand_anchor.add_child(hand)
	# Position needs to be flipped for some reason, relative rotation issue?
	hand.position = hand_offset * Vector3(-1, 1, 1)
	
	# TODO - over scoping, come back to this if we need it. Having hands undock and return is the basic behaviour.
	# An exception to this is when a hand has undocked, if we undock a hand and immediately spawn
	# another - we could want the spawned hand to take the place of the undocked one for a quick reload
	# type behaviour.
	

# Move the new hand to the scene root so it can move independently
func _release_hand(hand: BlackjackHand) -> void:
	var hand_parent: Node3D = hand.get_parent()
	if hand_parent:
		hand_parent.remove_child(hand)
	
	scene_root.add_child(hand)


# General event handler methods
func _hand_on_event_received(event: String, hand: BossCore) -> void:
	if event == "end_recovery":
		hand.state_chart.send_event("end_attack")
		_hand_finished(hand)

func _hand_finished(hand: BossCore) -> void:
	finished_hands.append(hand)
	hand_attack_finished.emit(hand)
	if finished_hands.size() == spawned_hands.size():
		last_hand = hand
		all_hand_attacks_finished.emit()
		finished_hands = []

func _hand_hurt(health_diff: float) -> void:
	health_component.damage(abs(health_diff))

func _hand_dead(stack: CharacterBody3D) -> void:
	_hand_finished(stack)

# Attack trigger methods
func _start_hand_attack() -> void:
	state_chart.send_event("start_attack")

func trigger_all_hand_attacks_sim(attack_event: String, hand_delay: float = 0.0) -> void:
	for hand in spawned_hands:
		hand.state_chart.send_event(attack_event)
		if hand_delay:
			await get_tree().create_timer(hand_delay).timeout

	await all_hand_attacks_finished

	state_chart.send_event("finish_attack")

func trigger_all_hand_attacks_seq(activate_event: String, attack_event: String) -> void:
	for hand in spawned_hands:
		hand.state_chart.send_event(activate_event)
	for hand in spawned_hands:
		hand.state_chart.send_event(attack_event)
		await hand_attack_finished

	state_chart.send_event("finish_attack")

func cancel_active_hand_attacks() -> void:
	for hand in spawned_hands:
		hand.state_chart.send_event("end_attack")



## PHASE STATES

## INTRO
func _on_intro_state_entered() -> void:
	# Play an animation of the boss rising up from the void,
	# two hands grabbing the edge to wrench them upwards.
	state_chart.send_event("start_targeting")
	
	# Spawn two initial hands
	for i in range(2):
		await spawn_hand()
	
	var move_tween := get_tree().create_tween()
	var hand_l = spawned_hands[0]
	var hand_r = spawned_hands[1]
	self.global_position = intro_path_points[0].global_position
	for point in intro_path_points.slice(1, intro_path_points.size() - 1):
		move_tween.tween_property(hand_l, "global_position", point.global_position + Vector3(5, -1 ,0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		move_tween.parallel().tween_property(hand_r, "global_position", point.global_position + Vector3(-5, -1, 0), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		move_tween.tween_interval(0.25)
		move_tween.chain().tween_property(self, "global_position", point.global_position, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		move_tween.parallel().tween_property(hand_l, "global_position", point.global_position + Vector3(5, 0.5, 2), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		move_tween.parallel().tween_property(hand_r, "global_position", point.global_position + Vector3(-5, 0.5, 2), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hand_l.position = Vector3(5, 0, 0)
	hand_r.position = Vector3(-5, 0, 0)
	#move_tween.tween_interval(0.1)
	move_tween.parallel().tween_property(self, "global_position", intro_path_points[intro_path_points.size() - 1].global_position, 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	move_tween.parallel().tween_property(hand_l, "global_position", intro_path_points[intro_path_points.size() - 1].global_position + Vector3(5, 0 ,0), 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	move_tween.parallel().tween_property(hand_r, "global_position", intro_path_points[intro_path_points.size() - 1].global_position + Vector3(-5, 0 ,0), 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	
	await move_tween.finished
