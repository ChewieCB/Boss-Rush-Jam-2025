extends Control
class_name BarrelInfoRegion

@export var barrel_info_icon_prefab: PackedScene

@onready var circle_ring: Control = $CircleRing
@onready var desc_label: RichTextLabel = $PanelDescription/ScrollContainer/VBoxContainer/RichTextLabel
@onready var panel_bg_icon: TextureRect = $PanelDescription/PanelBGIcon

var barrel_data: BarrelDataResource = null

func _ready() -> void:
	if barrel_data != null:
		refresh_ui()


func set_barrel_data_resource(_barrel_data: BarrelDataResource) -> void:
	barrel_data = _barrel_data
	refresh_ui()

func refresh_ui() -> void:
	for child in circle_ring.get_children():
		child.queue_free()

	# Spawn barrel prefab to get its data
	var barrel_inst: SpinBarrel = barrel_data.barrel_prefab.instantiate()
	add_child(barrel_inst)
	barrel_inst.visible = false
	barrel_inst.global_position = Vector3(9999, 9999, 9999) # Yeet it away

	# Spawn the barrel roll effects around the circle
	var roll_effect_count = barrel_inst.get_number_of_barrel_effect()
	var positions = get_circle_positions(roll_effect_count)
	var barrel_info_icon_to_highlight: BarrelInfoIcon = null
	for i in range(roll_effect_count):
		var barrel_roll_data = barrel_inst.get_barrel_effect_data_at(i)
		var inst: BarrelInfoIcon = barrel_info_icon_prefab.instantiate()
		circle_ring.add_child(inst)
		inst.barrel_info_region = self
		inst.global_position = positions[i] - (inst.size / 2)
		inst.set_barrel_roll_data(barrel_roll_data)
		barrel_info_icon_to_highlight = inst

	# Spawn the barrel summary info at center
	var center_inst: BarrelInfoIcon = barrel_info_icon_prefab.instantiate()
	circle_ring.add_child(center_inst)
	var center = circle_ring.global_position + circle_ring.size / 2
	center_inst.global_position = center - (center_inst.size / 2)
	center_inst.texture_rect.texture = barrel_data.barrel_image
	center_inst.barrel_info_region = self
	var general_barrel_data = {
		"title": barrel_data.barrel_name,
		"description": barrel_data.barrel_info_summary,
		"is_archetype": false,
		"positive_desc": [],
		"negative_desc": [],
	}
	panel_bg_icon.texture = barrel_data.barrel_image
	center_inst.set_barrel_roll_data(general_barrel_data)
	barrel_inst.queue_free()
	if barrel_info_icon_to_highlight:
		barrel_info_icon_to_highlight.focus_entered.emit()


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


func unfocus_other_barrel_info_icon():
	for child: BarrelInfoIcon in circle_ring.get_children():
		child.focus_exited.emit()