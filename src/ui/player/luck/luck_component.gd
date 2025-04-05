extends BaseComponent
class_name LuckComponent

signal luck_changed(new_luck: float, prev_luck: float)
signal luck_diff(diff: float)
signal luck_maxed()

@export_category("Luck")
@export var max_luck: float = 100

var luck_loss_modifier: float = 1.0
var luck_gain_modifier: float = 1.0


var current_luck: float:
	set(value):
		if not enabled:
			return
		# Cache previous value so we can do dynamic luck bars
		var prev_luck = current_luck
		current_luck = clamp(value, 0, max_luck)
		var diff = current_luck - prev_luck
		current_luck_ratio = current_luck / max_luck
		luck_diff.emit(diff)
		luck_changed.emit(current_luck, prev_luck)
		if current_luck == 0:
			# TODO - do we want anything to trigger at 0 luck?
			pass
		elif current_luck == max_luck:
			luck_maxed.emit()
			LuckHandler.max_luck_decay_buffer()
var current_luck_ratio: float = current_luck / max_luck


func _ready() -> void:
	initialize_luck()
	LuckHandler.luck_increased.connect(increase_luck)
	LuckHandler.luck_decreased.connect(decrease_luck)


func decrease_luck(_reduction: float) -> void:
	_reduction = round(_reduction * luck_loss_modifier)
	if enabled:
		current_luck -= _reduction


func increase_luck(_luck: float) -> void:
	if enabled:
		_luck = round(_luck * luck_gain_modifier)
		current_luck += _luck


func initialize_luck() -> void:
	current_luck = 0.0
