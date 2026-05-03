extends Control
class_name EquippedFrameSideViewUI

@export var frame_carousel: TextureRect
@export var frame_ui_center: TextureRect
@export var frame_ui_left: TextureRect
@export var frame_ui_right: TextureRect
@export var current_frame_label: Label


const FrameEnum := GunFrameResource.GunFrameIdEnum


func set_frame_icons(active_frame: GunFrameResource, available_frames: Array) -> void:
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
