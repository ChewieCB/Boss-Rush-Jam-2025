extends Node
class_name BaseComponent

signal was_enabled()
signal was_disabled()

@export_category("BaseComponent")

@export var enabled := true:
	set(enabled_):
		var previous_state := enabled
		enabled = enabled_

		# State change signals.
		if previous_state != enabled:
			if enabled:
				was_enabled.emit()
			else:
				was_disabled.emit()
	get:
		return enabled

@export_category("Logging")
@export var log_events: bool = false

func enable() -> void:
	enabled = true

func disable() -> void:
	enabled = false

func is_enabled() -> bool:
	return enabled

func _ready() -> void:
	pass

# Returns a nice smoothed value independent of frame rate.
func _smoothed(value: float, delta: float) -> float:
	return 1.0 - exp(-delta * value)
