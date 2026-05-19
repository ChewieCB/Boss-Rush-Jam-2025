@tool
extends Control

signal reload_ui_animation_finished

@export var ammo_single_texture: CompressedTexture2D
#@export var radial_ui_center_node: Control

@export var max_radial_segment_count: int = 7
@export var active_radial_segment_count: int = 5:
	set(value):
		active_radial_segment_count = clamp(value, 0, max_radial_segment_count)

var is_reload_ui_anim_active: bool = false


func _draw() -> void:
	# Background
	_draw_radial_segments(max_radial_segment_count, max_radial_segment_count, 24.0, 0.0, Color("#020202"))
	# Inactive
	_draw_radial_segments(max_radial_segment_count, max_radial_segment_count, 12.0, PI / 64, Color("#2a2a2a"))
	# Active
	_draw_radial_segments(active_radial_segment_count, max_radial_segment_count, 18.0, PI / 92, Color("#C11E1E"), Color("#C1BEBE"))


func _draw_radial_segments(segment_count: int, max_segment_count: int, thickness: float, segment_padding: float, colour: Color, alternating_colour: Color = Color(), is_ccw: bool = false) -> void:
	# Draw arc segments with a small amount of padding between them
	var segment_angle: float = (TAU / float(max_segment_count))
	var init_angle: float = 0.75 * PI
	var dir: float = 1.0 if is_ccw else -1.0
	for i in range(segment_count):
		var _start_angle: float = init_angle + (i * segment_angle)
		var _end_angle: float = _start_angle + segment_angle
		
		var arc_colour: Color = colour
		if alternating_colour != Color():
			if i % 2 != 0:
				arc_colour = alternating_colour
		
		draw_arc(
			Vector2.ZERO,
			80.0,
			(_start_angle + segment_padding) * dir,
			(_end_angle - segment_padding) * dir,
			50,
			arc_colour,
			thickness,
			true
		)


func _draw_radial_icons(active_segment_count: int, max_segment_count: int, _thickness: float, segment_padding: float, is_ccw: bool = false) -> void:
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
			- ammo_single_texture.get_size() * 0.5
		)


func update(new_active_count: int, new_max_count: int) -> void:
	if is_reload_ui_anim_active:
		await reload_ui_animation_finished
	
	max_radial_segment_count = new_max_count
	active_radial_segment_count = new_active_count
	queue_redraw()


func animate_full_reload(reload_time: float) -> void:
	is_reload_ui_anim_active = true
	var segments_to_unload: int = active_radial_segment_count
	var segments_to_reload: int = max_radial_segment_count
	var reload_time_padding: float = 0.07
	var reload_time_per_segment: float = (reload_time - reload_time_padding) / (segments_to_reload + segments_to_unload)
	
	await get_tree().create_timer(reload_time_padding / 2, false).timeout
	# Unload before we reload
	#while active_radial_segment_count > 0:
	for i in range(segments_to_unload):
		active_radial_segment_count -= 1
		await get_tree().create_timer(reload_time_per_segment, false).timeout
		queue_redraw()
	
	for i in range(segments_to_reload):
		active_radial_segment_count += 1
		await get_tree().create_timer(reload_time_per_segment, false).timeout
		queue_redraw()
	
	await get_tree().create_timer(reload_time_padding / 2, false).timeout
	
	is_reload_ui_anim_active = false
	reload_ui_animation_finished.emit()
