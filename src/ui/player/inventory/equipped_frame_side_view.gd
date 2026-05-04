extends Control
class_name EquippedFrameSideViewUI

@export var frame_carousel: TextureRect
@export var frame_ui_center: TextureRect
@export var frame_ui_left: TextureRect
@export var frame_ui_right: TextureRect
@export var current_frame_label: Label
@export var current_frame_panel: ColorRect


const FrameEnum := GunFrameResource.GunFrameIdEnum


func anim_frame_icon_size(icon: TextureRect) -> void:
	icon.pivot_offset = icon.size / 2
	current_frame_panel.pivot_offset = current_frame_panel.size / 2
	var tween = get_tree().create_tween()
	tween.tween_property(icon , "scale", Vector2(0.7, 0.7), 0.05)
	tween.chain().tween_property(icon , "scale", Vector2(1.2, 1.2), 0.05)
	tween.chain().tween_property(icon , "scale", Vector2(1, 1), 0.05)
	#var panel_tween = get_tree().create_tween()
	#panel_tween.tween_property(current_frame_panel, "scale", Vector2(1.1, 1.1), 0.15)
	#panel_tween.chain().tween_property(current_frame_panel, "scale", Vector2(1, 1), 0.25)


func anim_frame_icon_slide(icon: TextureRect, dir: Vector2, offset: float) -> void:
	icon.pivot_offset = icon.size / 2
	var cached_pos: Vector2 = icon.position
	icon.position += dir * offset
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(icon , "position", cached_pos, 0.15)
	#tween.parallel().tween_property(icon , "scale", Vector2(0.7, 0.7), 0.15)
	#tween.chain().tween_property(icon , "scale", Vector2(1, 1), 0.15)


func set_frame_icons(active_frame: GunFrameResource, available_frames: Array, move_dir: Vector2 = Vector2.ZERO) -> void:
	# Change center frame to active frame
	frame_ui_center.texture = active_frame.shop_ui_sprite
	current_frame_label.text = active_frame.frame_name
	# Change left and right frames to available inventory frames either side
	var active_idx: int = available_frames.find(active_frame)
	
	# Wrap around so if we only have one frame available, thats the only one displayed
	var left_idx: int = wrapi(active_idx - 1, 0, available_frames.size())
	frame_ui_left.texture = available_frames[left_idx].shop_ui_sprite
	frame_ui_left.modulate.a = 0.0 if left_idx == active_idx else 1.0
	
	var right_idx: int = wrapi(active_idx + 1, 0, available_frames.size())
	frame_ui_right.texture = available_frames[right_idx].shop_ui_sprite
	frame_ui_right.modulate.a = 0.0 if right_idx == active_idx else 1.0
	
	if move_dir == Vector2.ZERO:     
		return
	
	anim_frame_icon_size(frame_ui_center)
	
	anim_frame_icon_slide(
		frame_ui_left, 
		move_dir, 
		frame_ui_center.position.distance_to(frame_ui_left.position)
	)
	anim_frame_icon_slide(
		frame_ui_right, 
		move_dir, 
		frame_ui_center.position.distance_to(frame_ui_right.position)
	)
