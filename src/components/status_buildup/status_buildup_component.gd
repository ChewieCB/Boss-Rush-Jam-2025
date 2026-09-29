extends BaseComponent
class_name StatusBuildupComponent

## Sends "add_status_<status_id>" / "remove_status_<status_id>" to state_chart.
signal buildup_changed(value: float, max_value: float)
signal progress_changed(ratio: float, active: bool)
signal triggered
signal ended

@export_category("Status Buildup")
@export var status_id: StringName
@export var state_chart: StateChart

@export_group("Buildup")
@export var max_buildup: float = 100.0
@export var decay_delay: float = 1.5
@export var decay_rate: float = 25.0

@export_group("Effect")
@export var effect_duration: float = 4.0
# If this true, receive a build up tick while status is active will insta refill the bar.
# Otherwise, you kinda immune to more buildup until the curreny status ended.
@export var refresh_duration_while_active: bool = true

@export_group("Display")
@export var display_name: String
@export var icon: Texture2D
@export var gauge_color: Color = Color.WHITE

var buildup: float = 0.0:
	set(value):
		value = clampf(value, 0.0, max_buildup)
		if is_equal_approx(value, buildup):
			return
		buildup = value
		buildup_changed.emit(buildup, max_buildup)
var active_duration: float = 0.0
var active_time_left: float = 0.0
var _active: bool = false
var _decay_timer: float = 0.0


func _process(delta: float) -> void:
	if not enabled:
		return

	if is_active():
		active_time_left -= delta
		if active_time_left <= 0.0:
			end()
		else:
			_emit_progress()
		return

	if buildup <= 0.0:
		return
	if _decay_timer > 0.0:
		_decay_timer -= delta
		return
	buildup -= decay_rate * delta
	_emit_progress()


func add_buildup(amount: float) -> void:
	if not enabled:
		return
	if is_active():
		if refresh_duration_while_active:
			active_time_left = active_duration
			_emit_progress()
		return

	buildup += amount
	_decay_timer = decay_delay
	if buildup >= max_buildup:
		trigger()
	else:
		_emit_progress()


func trigger(duration: float = -1.0) -> void:
	active_duration = effect_duration if duration < 0.0 else duration
	active_time_left = active_duration
	_active = true
	buildup = 0.0
	if state_chart:
		state_chart.send_event("add_status_%s" % status_id)
	triggered.emit()
	_emit_progress()


func end() -> void:
	if not is_active():
		return
	_active = false
	active_time_left = 0.0
	if state_chart:
		state_chart.send_event("remove_status_%s" % status_id)
	ended.emit()
	_emit_progress()


func clear() -> void:
	end()
	buildup = 0.0
	_decay_timer = 0.0
	_emit_progress()


func is_active() -> bool:
	return _active


func get_progress() -> float:
	if is_active():
		return active_time_left / active_duration
	return buildup / max_buildup


func _emit_progress() -> void:
	progress_changed.emit(get_progress(), is_active())
