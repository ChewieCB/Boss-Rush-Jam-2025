extends Node

signal luck_increased(value: float)
signal luck_decreased(value: float)
signal modifier_message(text: String, is_gain: bool, luck_type: LuckTriggerType)
signal trigger_discovered()

enum LuckTriggerType {
	NONE,
	NORMAL,
	RARE, # Give more luck
	NEGATIVE, # Doesn't alway mean decrease luck
	DEVIL # Increase luck a lot, much more than Rare, but it probably cost something else...
}

# Populate a dict of luck triggers, tracking the ID, name, description, message, and is_discovered values
@export var luck_triggers: Array[LuckTriggerInfo] = []
var luck_trigger_dict: Dictionary = {}

# TODO - default to false and enable on the boss trigger
@export var enabled: bool = false

# Luck decay per second
@export_group("Luck Loss Over Time")
@export_subgroup("Luck Decay")
@export var luck_decay_enabled: bool = true
@export var luck_decay: float = 0.15
@export var max_luck_decay_buffer_time: float = 2.0
@onready var luck_decay_timer: Timer = $LuckDecayTimer
#
@export_subgroup("Auto Spin Luck Cost")
@export var luck_cost_per_auto_spin: float = 10.0

@export_subgroup("No Damage Taken For X Seconds")
@export var no_damage_taken_threshold: float = 5.0
@export var no_damage_taken_luck_gain: float = 10.0
@export var no_damage_taken_mult_cap: int = 3
var time_since_last_hurt: float = 0.0
var last_hurt_mult: int = 0

@export_subgroup("DPS Dealt In Last X Seconds")
@export var dps_dealt_window: float = 1.8
@export var dps_dealt_threshold: float = 80.0
@export var dps_dealt_luck_gain: float = 10.0
@export var dps_dealt_mult_cap: int = 5
@onready var dps_dealt_window_timer: Timer = $DPSWindowTimer
var dps_accumulated_in_window: float = 0.0:
	set(value):
		dps_accumulated_in_window = value
		if dps_dealt_window_timer.is_stopped():
			dps_dealt_window_timer.start(dps_dealt_window)


func reset_luck_triggers() -> void:
	for trigger in luck_triggers:
		var enum_str: String = LuckTriggerInfo.LuckTriggerIdEnum.keys()[trigger.id]
		luck_trigger_dict[enum_str] = false
	trigger_discovered.emit()


func update_luck_triggers_from_new_patch() -> void:
	for trigger in luck_triggers:
		var enum_str: String = LuckTriggerInfo.LuckTriggerIdEnum.keys()[trigger.id]
		if enum_str not in luck_trigger_dict:
			luck_trigger_dict[enum_str] = false


## Modify luck
func increase_luck(amount: float, message: String = "", type = LuckTriggerType.NORMAL) -> void:
	amount *= GameManager.get_risk_luck_buildup_mult()
	luck_increased.emit(amount)
	modifier_message.emit(
		message,
		true,
		type
	)

func decrease_luck(amount: float, message: String = "", type = LuckTriggerType.NORMAL) -> void:
	luck_decreased.emit(amount)
	modifier_message.emit(
		message,
		false,
		type
	)


func _physics_process(_delta: float) -> void:
	if not enabled:
		return

	# TODO - store all per-physics-tick luck trigger checks as an array of callables to be called here
	# TODO - move this to a specific barrel, a healing/defensive one
	#track_no_damage_taken(delta)


func check_discover_luck_trigger(luck_trigger_id: LuckTriggerInfo.LuckTriggerIdEnum):
	var enum_str: String = LuckTriggerInfo.LuckTriggerIdEnum.keys()[
		luck_trigger_id
	]
	if luck_trigger_dict[enum_str] == false:
		luck_trigger_dict[enum_str] = true
		trigger_discovered.emit()


##
## LUCK TRIGGER: Take no damage for X seconds
##
func track_no_damage_taken(delta: float) -> void:
	time_since_last_hurt += delta

	# var threshold = no_damage_taken_threshold
	var current_mult = int(time_since_last_hurt / no_damage_taken_threshold)

	if current_mult > last_hurt_mult and current_mult <= no_damage_taken_mult_cap:
		LuckHandler.gain_no_damage_taken(current_mult)
		last_hurt_mult = current_mult


func gain_no_damage_taken(threshold_mult: int) -> void:
	# Gain luck from not taking damage in the last X seconds
	increase_luck(
		no_damage_taken_luck_gain * threshold_mult,
		"No damage taken for %s seconds!" % [
			no_damage_taken_threshold * threshold_mult
		],
	)

##
## LUCK TRIGGER: Deal at least X damage in Y seconds
##
func accumulate_dps_dealt(damage: float) -> void:
	if not enabled:
		return
	dps_accumulated_in_window += damage


func gain_dps_dealt(dps_dealt: float) -> void:
	var mult = int(dps_dealt / dps_dealt_threshold)
	if mult > dps_dealt_mult_cap:
		mult = dps_dealt_mult_cap
	increase_luck(
		dps_dealt_luck_gain * mult,
		"%s damage in %s seconds!" % [
			dps_dealt,
			dps_dealt_threshold
		],
	)
	print("Gained %s luck, did %s damage in %s seconds!" % [
		dps_dealt_luck_gain * mult,
		dps_dealt,
		dps_dealt_threshold
	])


func max_luck_decay_buffer() -> void:
	# When we max out luck, stop the decay for a short time
	# to make sure we can cash it in.
	luck_decay_timer.stop()
	await get_tree().create_timer(max_luck_decay_buffer_time).timeout
	luck_decay_timer.start()


# Deprecated - for use with manual spin DEBUG
# Old luck system decayed over time, new luck system decays per auto-spin
func _on_luck_decay_timer_timeout() -> void:
	if luck_decay_enabled:
		luck_decreased.emit(luck_decay)


func _on_dps_dealt_window_timer_timeout() -> void:
	if not enabled:
		dps_accumulated_in_window = 0.0
		return
	# TODO - move this to a barrel
	#if dps_accumulated_in_window > dps_dealt_threshold:
		#gain_dps_dealt(dps_accumulated_in_window)
	#dps_accumulated_in_window = 0.0
