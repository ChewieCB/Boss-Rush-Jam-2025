extends Control
class_name BarrelInfoRegion

@export var barrel_info_icon_prefab: PackedScene
@export var debug_barrel_data: BarrelDataResource

@onready var circle_ring: Control = $CircleRing
@onready var desc_label: RichTextLabel = $PanelDescription/ScrollContainer/VBoxContainer/RichTextLabel
@onready var panel_bg_icon: TextureRect = $PanelDescription/PanelBGIcon

func _ready() -> void:
	# Spawn barrel prefab to get its data
	var barrel_inst: SpinBarrel = debug_barrel_data.barrel_prefab.instantiate()
	add_child(barrel_inst)
	barrel_inst.visible = false
	barrel_inst.global_position = Vector3(9999, 9999, 9999) # Yeet it away

	# Spawn the barrel roll effects around the circle
	var roll_effect_count = barrel_inst.get_number_of_barrel_effect()
	var positions = get_circle_positions(roll_effect_count)
	for i in range(roll_effect_count):
		var barrel_data = barrel_inst.get_barrel_effect_data_at(i)
		var inst: BarrelInfoIcon = barrel_info_icon_prefab.instantiate()
		circle_ring.add_child(inst)
		inst.barrel_info_region = self
		inst.global_position = positions[i] - (inst.size / 2)
		inst.set_barrel_data(barrel_data)
		if i == 0:
			inst.grab_focus()

	# Spawn the barrel summary info at center
	var center_inst: BarrelInfoIcon = barrel_info_icon_prefab.instantiate()
	circle_ring.add_child(center_inst)
	var center = circle_ring.global_position + circle_ring.size / 2
	center_inst.global_position = center - (center_inst.size / 2)
	center_inst.texture_rect.texture = debug_barrel_data.barrel_image
	center_inst.barrel_info_region = self
	var spin_barrel_data = {
		"display_text_title": debug_barrel_data.barrel_name,
		"display_text_tag": debug_barrel_data.barrel_info_summary,
		"is_archetype": false,
		"positive_desc": [],
		"negative_desc": [],
	}
	panel_bg_icon.texture = debug_barrel_data.barrel_image
	center_inst.set_barrel_data(spin_barrel_data)
	barrel_inst.queue_free()


func get_circle_positions(count: int) -> Array[Vector2]:
	const OFFSET = 22
	var center = circle_ring.global_position + circle_ring.size / 2
	var radius = (circle_ring.size.x / 2) - OFFSET
	var positions: Array[Vector2] = []
	for i in range(count):
		var angle = (TAU / count) * i # TAU = 2*PI
		var x = center.x + radius * cos(angle)
		var y = center.y + radius * sin(angle)
		positions.append(Vector2(x, y))
	return positions


func set_description_content(content: String):
	desc_label.text = content

func reset_ui():
	set_description_content("")
	panel_bg_icon.texture = null
	for child in circle_ring.get_children():
		child.queue_free()