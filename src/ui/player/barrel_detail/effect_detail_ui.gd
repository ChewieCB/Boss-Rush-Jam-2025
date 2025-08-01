extends Control

@onready var player = get_owner()

@onready var effect_box_1: EffectInfoUI = $BarrelDetailUI/MarginContainer/HBoxContainer/VBoxContainer/Box1Padding/EffectInfoUI
@onready var effect_box_2: EffectInfoUI = $BarrelDetailUI/MarginContainer/HBoxContainer/VBoxContainer/Box2Padding/EffectInfoUI
@onready var effect_box_3: EffectInfoUI = $BarrelDetailUI/MarginContainer/HBoxContainer/Box3Padding/EffectInfoUI
@onready var effect_boxes: Array[EffectInfoUI] = [effect_box_3, effect_box_2, effect_box_1]


func _draw() -> void:
	var barrel_positions: Array[Vector2] = player.get_barrel_sprite_screen_positions()
	for i in range(barrel_positions.size()):
		var pos = barrel_positions[i]
		var ui_box = effect_boxes[i]
		if ui_box:
			if ui_box.modulate.a == 1.0:
				var ui_box_pos: Vector2 = ui_box.get_screen_position()
				var ui_box_size: Vector2 = ui_box.get_rect().size
				
				# Offset the anchor depending on the box index
				var ui_box_anchor_offset: Vector2
				match i:
					0:
						ui_box_anchor_offset = Vector2(ui_box_size.x / 2, ui_box_size.y)
					1:
						ui_box_anchor_offset = Vector2(ui_box_size.x, ui_box_size.y / 2)
					2:
						ui_box_anchor_offset = Vector2(ui_box_size.x / 2, ui_box_size.y)
				
				var ui_box_anchor: Vector2 = ui_box_pos + ui_box_anchor_offset
				
				draw_circle(pos, 10.0, Color("e6c600"))
				draw_circle(ui_box_anchor, 10.0, Color("e6c600"))
				draw_line(pos, ui_box_anchor, Color("e6c600"), 8.0)


func _process(delta: float) -> void:
	queue_redraw()
