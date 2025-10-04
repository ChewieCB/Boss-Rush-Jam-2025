extends BossCore
class_name BossBlackjack

signal hand_attack_finished(hand)
signal all_hand_attacks_finished


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
	# TODO - play a cool animation of the boss rising up from the void, 
	#  two hands grabbing the edge to wrench them upwards
	state_chart.send_event("start_targeting")
	var move_tween := get_tree().create_tween()
	var hand_l = $BlackjackHandL
	var hand_r = $BlackjackHandR
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
	move_tween.tween_interval(0.1)
	move_tween.parallel().tween_property(self, "global_position", intro_path_points[intro_path_points.size() - 1].global_position, 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	move_tween.parallel().tween_property(hand_l, "global_position", intro_path_points[intro_path_points.size() - 1].global_position + Vector3(5, 0 ,0), 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	move_tween.parallel().tween_property(hand_r, "global_position", intro_path_points[intro_path_points.size() - 1].global_position + Vector3(-5, 0 ,0), 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
		
	
