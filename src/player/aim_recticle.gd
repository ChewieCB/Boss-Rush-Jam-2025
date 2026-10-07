extends ColorRect

@export_group("Style")
@export var line_length: float = 9.0
@export var thickness: float = 2.0
@export var dot_size: float = 2.0
@export var outline_width: float = 1.0
@export var line_color: Color = Color.WHITE
@export var outline_color: Color = Color.BLACK

## Gap from center to the rectangle when 0 spread
const BASE_GAP: float = 4.0
## Extra gap after user shot, for the juice
const SHOT_KICK: float = 6.0
const KICK_DECAY: float = 12.0
const FOLLOW_SPEED: float = 15.0
const MAX_GAP: float = 300.0
const PADDING: float = 4.0

var shader_mat: ShaderMaterial
var current_gap: Vector2
var kick: float = 0.0
var connected_gun: Gun


func _ready() -> void:
	shader_mat = material as ShaderMaterial
	current_gap = Vector2(BASE_GAP, BASE_GAP)
	shader_mat.set_shader_parameter("line_length", line_length)
	shader_mat.set_shader_parameter("thickness", thickness)
	shader_mat.set_shader_parameter("dot_size", dot_size)
	shader_mat.set_shader_parameter("outline_width", outline_width)
	shader_mat.set_shader_parameter("line_color", line_color)
	shader_mat.set_shader_parameter("outline_color", outline_color)
	while GameManager.setting_ui == null:
		await get_tree().process_frame
	GameManager.setting_ui.setting_changed.connect(refresh_after_setting_changed)
	refresh_after_setting_changed()

func refresh_after_setting_changed():
	visible = not GameManager.hide_ui


func _process(delta: float) -> void:
	if not visible or GameManager.player == null:
		return
	var gun: Gun = GameManager.player.current_gun
	if gun == null:
		return
	if gun != connected_gun:
		connected_gun = gun
		gun.gun_shot.connect(func(): kick += SHOT_KICK)

	kick = lerpf(kick, 0.0, 1.0 - exp(-KICK_DECAY * delta))
	var target := _spread_to_gap(gun.get_preview_spread_angle(), gun.get_preview_spread_horizontal_bias())
	current_gap = current_gap.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))

	var gap := current_gap + Vector2(kick, kick)
	var half_extent := maxf(gap.x, gap.y) + line_length + outline_width + PADDING
	offset_left = - half_extent
	offset_top = - half_extent
	offset_right = half_extent
	offset_bottom = half_extent

	shader_mat.set_shader_parameter("gap", gap)
	shader_mat.set_shader_parameter("rect_size", Vector2(half_extent, half_extent) * 2.0)


func _spread_to_gap(spread_angle: float, horizontal_bias: float) -> Vector2:
	horizontal_bias = clampf(horizontal_bias, 0.0, 1.0)
	var fov: float = GameManager.player.player_camera.camera.fov
	var focal := get_viewport_rect().size.y * 0.5 / tan(deg_to_rad(fov) * 0.5)
	var h_angle := deg_to_rad(minf(spread_angle * horizontal_bias, 89.0))
	var v_angle := deg_to_rad(minf(spread_angle * (1.0 - horizontal_bias), 89.0))
	return Vector2(
		minf(BASE_GAP + focal * tan(h_angle), MAX_GAP),
		minf(BASE_GAP + focal * tan(v_angle), MAX_GAP))
