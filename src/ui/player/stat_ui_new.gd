@tool
extends Control

@export var ammo_single_texture: CompressedTexture2D
#@export var radial_ui_center_node: Control

@export var max_radial_segment_count: int = 7
@export var active_radial_segment_count: int = 5


func _draw() -> void:
	#draw_circle(Vector2.ZERO, 84.0, Color.BLACK)
	# Inactive
	_draw_radial_segments(max_radial_segment_count, max_radial_segment_count, 12.0, PI / 64, Color.DARK_GRAY)
	# Background
	_draw_radial_segments(active_radial_segment_count, max_radial_segment_count, 24.0, PI / 128, Color.DARK_GOLDENROD)
	# Active
	_draw_radial_segments(active_radial_segment_count, max_radial_segment_count, 16.0, PI / 42, Color.WHITE)
	# Icons
	_draw_radial_icons(active_radial_segment_count, max_radial_segment_count, 16.0, PI / 42)
	

func _process(_delta: float) -> void:
	queue_redraw()
	# FIXME FIXME FIXME FIXME - remove this when done testing
	#if Input.is_action_just_pressed("ui_cancel"):
		#get_tree().quit()
	#elif Input.is_action_just_pressed("input_1"):
		#if Input.is_action_pressed("dash"):
			#max_radial_segment_count -= 1
			#active_radial_segment_count -= 1
		#else:
			#active_radial_segment_count += 1
	#elif Input.is_action_just_pressed("input_2"):
		#if Input.is_action_pressed("dash"):
			#max_radial_segment_count += 1
			#active_radial_segment_count += 1
		#else:
			#active_radial_segment_count -= 1


func _draw_radial_segments(segment_count: int, max_segment_count: int, thickness: float, segment_padding: float, colour: Color, is_ccw: bool = false) -> void:
	# Draw arc segments with a small amount of padding between them
	var segment_angle: float = (TAU / float(max_segment_count))
	var init_angle: float = 0.75 * PI
	var dir: float = 1.0 if is_ccw else -1.0
	for i in range(segment_count):
		var _start_angle: float = init_angle + (i * segment_angle)
		var _end_angle: float = _start_angle + segment_angle
		draw_arc(
			Vector2.ZERO,
			80.0,
			(_start_angle + segment_padding) * dir,
			(_end_angle - segment_padding) * dir,
			50,
			colour,
			thickness,
			true
		)


func _draw_radial_icons(active_segment_count: int, max_segment_count: int, thickness: float, segment_padding: float, is_ccw: bool = false) -> void:
	var segment_angle: float = (TAU / float(max_segment_count))
	var init_angle: float = 0.75 * PI
	var dir: float = 1.0 if is_ccw else -1.0
	for i in range(active_segment_count):
		# Icon angle should be the start angle of the arc + half the angle the arc moves
		var _start_angle: float = init_angle + (i * segment_angle)
		var _end_angle: float = _start_angle + segment_angle
		
		var visible_start: float = _start_angle + segment_padding
		var visible_end: float = _end_angle - segment_padding
		var mid_angle: float = (visible_start + visible_end) * dir / 2
		
		var _texture_pos := Vector2.RIGHT.rotated(mid_angle) * (80.0)
		draw_set_transform(
			_texture_pos,
			mid_angle + PI,
			Vector2(0.25, 0.25)
		)
		draw_texture(
			ammo_single_texture,
			-ammo_single_texture.get_size() * 0.5
		)
	
