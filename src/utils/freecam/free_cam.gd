extends Node3D
class_name FreeCam

@onready var camera: Camera3D = $Camera3D

const MAX_SPEED := 4
const MIN_SPEED := 0.1
const ACCELERATION := 0.1

const MOUSE_SENSITIVITY_COEEFICIENT = 10000
const CONTROLLER_SENSITIVITY_COEEFICIENT = 10

var velocity := Vector3.ZERO
var target_speed := MIN_SPEED

var disable_input: bool = false


func _ready() -> void:
	camera.fov = GameManager.camera_fov
	GameManager.pause_ui.pause_ui_toggled.connect(
		func(): disable_input = !disable_input
	)


func _input(event: InputEvent) -> void:
	if disable_input:
		return
	
	if event is InputEventMouseMotion:
		rotate_camera(event.relative.x, event.relative.y)
	elif event is InputEventJoypadMotion:
		if not InputHelper.get_label_for_input(event).to_lower().contains("trigger"):
			# Disable joystick support to prevent PS4 touchpad triggering aim events
			# Has to check Trigger buttons first, since they are also InputEventJoypadMotion
			return


func _process(delta: float) -> void:
	if disable_input:
		return
	
	handle_controller_look(delta)
	# Local directions
	var forward := -camera.global_transform.basis.z.normalized()
	var right := camera.global_transform.basis.x.normalized()
	var up := camera.global_transform.basis.y.normalized()
	
	var input_dir := Vector3.ZERO
	input_dir += right * Input.get_axis("move_left", "move_right")
	input_dir += up * Input.get_axis("crouch", "jump")
	input_dir += forward * Input.get_axis("move_down", "move_up")
	
	var target_velocity := input_dir * target_speed
	
	if Input.is_action_pressed("dash"):
		target_velocity *= 2
	elif Input.is_action_pressed("shoot"):
		target_velocity /= 2
	
	velocity = lerp(velocity, target_velocity, ACCELERATION)
	self.global_position += velocity


func handle_controller_look(_delta):
	var look_x = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_y = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")

	if abs(look_x) > 0.01 or abs(look_y) > 0.01:
		var sensitivity = GameManager.mouse_sensitivity / CONTROLLER_SENSITIVITY_COEEFICIENT
		rotate_camera(look_x * sensitivity, look_y * sensitivity)


func rotate_camera(x: float, y: float):
	rotate_y(-x * (GameManager.mouse_sensitivity / MOUSE_SENSITIVITY_COEEFICIENT))
	camera.rotate_x(-y * (GameManager.mouse_sensitivity / MOUSE_SENSITIVITY_COEEFICIENT))
	camera.rotation.x = clamp(camera.global_rotation.x, deg_to_rad(-89), deg_to_rad(89))


func set_fov(value: float):
	camera.fov = value
