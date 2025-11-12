extends Control
class_name BarrelInfoRegion

@export var barrel_info_icon_prefab: PackedScene
@export var rotation_speed: float = 0.2 # Radians per second

@onready var circle_ring: Control = $CircleRing
@onready var desc_label: RichTextLabel = $PanelDescription/ScrollContainer/VBoxContainer/RichTextLabel
@onready var panel_bg_icon: TextureRect = $PanelDescription/PanelBGIcon
@onready var select_icon_line: Line2D = $SelectIconLine

const CIRCLE_RING_RADIUS_OFFSET = 22

var barrel_data: BarrelDataResource = null
var circle_ring_center: Vector2
var circle_ring_radius: float

var barrel_info_icon_effect: Array[BarrelInfoIcon] = []
var barrel_info_icon_angle: Array[float] = []

func _ready() -> void:
	if barrel_data != null:
		refresh_ui()
	select_icon_line.visible = false
	circle_ring_center = circle_ring.global_position + circle_ring.size / 2
	circle_ring_radius = (circle_ring.size.x / 2) - CIRCLE_RING_RADIUS_OFFSET

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
	barrel_info_icon_angle = []
	barrel_info_icon_effect = []
	for i in range(roll_effect_count):
		var barrel_roll_data = barrel_inst.get_barrel_effect_data_at(i)
		var inst: BarrelInfoIcon = barrel_info_icon_prefab.instantiate()
		circle_ring.add_child(inst)
		inst.barrel_info_region = self
		inst.global_position = positions[i] - (inst.size / 2)
		inst.set_barrel_roll_data(barrel_roll_data)
		barrel_info_icon_effect.append(inst)

		# Store each icon's starting angle
		var angle = (TAU / roll_effect_count) * i
		barrel_info_icon_angle.append(angle)

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
		"icon_id": - 2 # Since -1 is the default icon for barrel effect that doesn't have custom one.
	}
	panel_bg_icon.texture = barrel_data.barrel_image
	center_inst.set_barrel_roll_data(general_barrel_data)
	barrel_inst.queue_free()
	if barrel_info_icon_effect.size() > 0:
		barrel_info_icon_effect[-1].focus_entered.emit()


func _process(delta: float) -> void:
	if not visible or barrel_info_icon_effect.size() == 0 or barrel_info_icon_angle.size() == 0:
		return

	for i in range(barrel_info_icon_effect.size()):
		var barrel_info_icon: BarrelInfoIcon = barrel_info_icon_effect[i]
		if not is_instance_valid(barrel_info_icon):
			return
		barrel_info_icon_angle[i] = barrel_info_icon_angle[i] + rotation_speed * delta
		var new_x = circle_ring_center.x + circle_ring_radius * cos(barrel_info_icon_angle[i])
		var new_y = circle_ring_center.y + circle_ring_radius * sin(barrel_info_icon_angle[i])
		barrel_info_icon.global_position = Vector2(new_x, new_y) - (barrel_info_icon.size / 2)
		if select_icon_line.visible and barrel_info_icon.is_expanded:
			select_icon_line.points[1] = barrel_info_icon.position + barrel_info_icon.size


func get_circle_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for i in range(count):
		var angle = (TAU / count) * i # TAU = 2*PI
		var x = circle_ring_center.x + circle_ring_radius * cos(angle)
		var y = circle_ring_center.y + circle_ring_radius * sin(angle)
		positions.append(Vector2(x, y))
	return positions


func set_description_content(content: String):
	desc_label.text = content
	if content == "":
		select_icon_line.visible = false

func reset_ui():
	set_description_content("")
	panel_bg_icon.texture = null
	for child in circle_ring.get_children():
		child.queue_free()


func unfocus_other_barrel_info_icon():
	for child: BarrelInfoIcon in circle_ring.get_children():
		child.focus_exited.emit()
