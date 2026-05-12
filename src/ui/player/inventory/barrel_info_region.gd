extends Control
class_name BarrelInfoRegion

@export var barrel_info_icon_prefab: PackedScene
@export var rotation_speed: float = 0.2  # Radians per second

@export var info_panel: ColorRect

@export var barrel_name_label: RichTextLabel
@export var barrel_flavour_label: RichTextLabel
@export var barrel_desc_label: RichTextLabel
@export var barrel_panel_barrel_icon: TextureRect

@export var effect_name_label: RichTextLabel
@export var effect_flavour_label: RichTextLabel
@export var effect_desc_label: RichTextLabel
@export var effect_panel_barrel_icon: TextureRect

@export var barrel_effect_list_label_1: EffectInfoListUI
@export var barrel_effect_list_label_2: EffectInfoListUI
@export var barrel_effect_list_label_3: EffectInfoListUI
@export var barrel_effect_list_label_4: EffectInfoListUI
@onready var barrel_effect_list_labels = [barrel_effect_list_label_1, barrel_effect_list_label_2, barrel_effect_list_label_3, barrel_effect_list_label_4]

@export var gun_frame_icon_container: MarginContainer
@export var gun_frame_icon: TextureRect

@export var effect_detail_wheel: MarginContainer
@export var circle_ring: Control
@export var circle_ring_centerpoint: Control
const CIRCLE_RING_RADIUS_OFFSET = 166
var circle_ring_center_pos: Vector2
var circle_ring_radius: float
@export var circle_arrow_icon: TextureRect

@export var barrel_overview_detail: ScrollContainer
@export var single_effect_detail: ScrollContainer
@export var locked_barrel_overlay: MarginContainer


var barrel_data: BarrelDataResource = null

const MAX_EFFECT_COUNT: int = 4
var current_effect_count: int
var barrel_info_icon_effect_pool: Array[BarrelInfoIcon] = []
var barrel_info_icon_effect_angles: Array[float] = []
var active_detail_icon: BarrelInfoIcon

var spin_tween: Tween

var active_effect_detail_idx: int = 0


func _ready() -> void:
	circle_ring_center_pos = circle_ring_centerpoint.position
	circle_ring_radius = -(circle_ring.size.x / 2) - CIRCLE_RING_RADIUS_OFFSET
	
	_init_barrel_effect_ui()
	show_barrel_overview(false)


func _draw() -> void:
	if circle_ring.visible:
		if active_detail_icon:
			var start_global = info_panel.get_global_rect().get_center()
			var end_global = active_detail_icon.get_global_rect().get_center()
			var start_pos = get_global_transform().affine_inverse() * start_global
			var end_pos = get_global_transform().affine_inverse() * end_global
			draw_line(start_pos, end_pos, Color("#e6c600"), 5.0)


func _show_ui(show_circle: bool, show_barrel: bool, show_effect: bool) -> void:
	effect_detail_wheel.visible = show_circle
	circle_ring.visible = show_circle
	barrel_overview_detail.visible = show_barrel
	single_effect_detail.visible = show_effect
	refresh_ui()


func show_barrel_overview(show_content: bool = true, is_locked: bool = false) -> void:
	_show_ui(false, true, false)
	barrel_overview_detail.visible = show_content
	locked_barrel_overlay.visible = is_locked
	active_detail_icon = null
	active_effect_detail_idx = 0


func set_barrel_overview_data(data: BarrelDataResource, is_locked: bool = false) -> void:
	barrel_panel_barrel_icon.texture = data.barrel_image
	barrel_name_label.text = "[b]%s[/b]" % [data.barrel_name]
	barrel_flavour_label.text = "[indent][i][color=gray]%s[/color][/i][/indent]" % [data.barrel_info_summary]
	barrel_desc_label.text = "[color=gray]Not available in demo.[/color]" if is_locked else data.barrel_desc
	
	gun_frame_icon_container.visible = false
	
	if is_locked:
		show_barrel_overview(true, true)
		return
	
	for i in range(barrel_info_icon_effect_pool.size()):
		var effect_info: BarrelInfoIcon = barrel_info_icon_effect_pool[i]
		var detail_label: EffectInfoListUI = barrel_effect_list_labels[i]
		
		if not effect_info.visible:
			detail_label.visible = false
			continue
		
		detail_label.visible = true
		detail_label.icon.texture = effect_info.texture_rect.texture
		detail_label.label.text = "[b]%s[/b]" % [effect_info.barrel_roll_data.title]


func set_gun_frame_overview_data(data: GunFrameResource, is_locked: bool = false) -> void:
	barrel_panel_barrel_icon.texture = null
	gun_frame_icon.texture = data.shop_ui_sprite
	barrel_name_label.text = "[b]%s[/b]" % [data.frame_name]
	barrel_flavour_label.text = "[indent][i][color=gray]%s[/color][/i][/indent]" % [data.flavour_text]
	barrel_desc_label.text = "[color=gray]Not available in demo.[/color]" if is_locked else data.frame_description
	
	gun_frame_icon_container.visible = true
	
	for detail_label: EffectInfoListUI in barrel_effect_list_labels:
		detail_label.visible = false
	
	if is_locked:
		show_barrel_overview(true, true)
		return


func show_effect_detail(show_content: bool = true) -> void:
	gun_frame_icon_container.visible = false
	_show_ui(true, false, true)
	grab_detail_focus(0)


func set_effect_detail_data(idx: int) -> void:
	var effect: BarrelInfoIcon = barrel_info_icon_effect_pool[idx]
	var data: Dictionary = effect.barrel_roll_data
	effect_panel_barrel_icon.texture = effect.texture_rect.texture
	effect_name_label.text = "[b]%s[/b]" % [data.title]
	effect_flavour_label.text = "[indent][i][color=gray]%s[/color][/i][/indent]" % [data.flavour_text]
	effect_desc_label.text = data.description


func grab_detail_focus(idx: int) -> void:
	var effect: BarrelInfoIcon = barrel_info_icon_effect_pool[idx]
	active_detail_icon = effect
	effect.grab_focus.call_deferred()


func _init_barrel_effect_ui() -> void:
	# Instantiate 4 barrel effect info objects to update as needed
	for i in range(MAX_EFFECT_COUNT):
		var ui: BarrelInfoIcon = barrel_info_icon_prefab.instantiate()
		circle_ring_centerpoint.add_child(ui)
		ui.barrel_info_region = self
		ui.focus_mode = Control.FOCUS_CLICK
		ui.focus_entered.connect(_on_effect_detail_focus_gained.bind(ui))
		ui.focus_exited.connect(_on_effect_detail_focus_lost.bind(ui))
		ui.clicked.connect(_on_effect_detail_clicked)
		barrel_info_icon_effect_pool.append(ui)


func populate_detail_circle_ui(barrel_data: BarrelDataResource) -> void:
	var barrel_inst: SpinBarrel = barrel_data.barrel_prefab.instantiate()
	add_child(barrel_inst)
	
	# Regen the barrel roll effects around the circle using the barrel data
	current_effect_count = barrel_inst.get_number_of_barrel_effect()
	var _wrap_focus = func(x: int): return wrapi(x, 0, current_effect_count)
	var effect_icon_nodes = barrel_info_icon_effect_pool.duplicate()
	effect_icon_nodes = effect_icon_nodes.slice(0, current_effect_count)
	
	# Instead of storing the positions of each node, place the first node at the top 
	# of the circle - Vector2(0, RADIUS) - and then rotate this vector by ROTATION_STEP for
	# each following node
	var rotation_step: float = 2 * PI / current_effect_count
	for i in range(MAX_EFFECT_COUNT):
		var ui: BarrelInfoIcon = barrel_info_icon_effect_pool[i]
		# Hide any unused efffect icon nodes
		if i >= current_effect_count:
			ui.visible = false
			continue
		
		var barrel_roll_data: Dictionary = barrel_inst.get_barrel_effect_data_at(i)
		ui.global_position = circle_ring_centerpoint.global_position + Vector2(circle_ring_radius, 0).rotated(PI/2 + (rotation_step * i))
		ui.set_barrel_roll_data(barrel_roll_data)
		ui.visible = true
	
	barrel_inst.queue_free()


func cycle_effect_detail(hide_line: bool = false) -> void:
	if is_instance_valid(spin_tween):
		return
	
	# Null active icon to disable the line during spin
	if not hide_line:
		active_detail_icon = null
	
	active_effect_detail_idx = wrapi(
		active_effect_detail_idx - 1, 
		0, 
		current_effect_count
	)
	
	await rotate_circle_one_slot()
	
	grab_detail_focus(active_effect_detail_idx)


func rotate_circle_one_slot() -> void:
	# Rotate all visible detail UI objects
	var rotation_step = 2 * PI / current_effect_count
	
	spin_tween = get_tree().create_tween()
	spin_tween.set_parallel(true)#.set_trans(Tween.TRANS_BOUNCE)#.set_ease(Tween.EASE_IN_OUT)
	spin_tween.tween_property(circle_ring_centerpoint, "rotation", circle_ring_centerpoint.rotation + rotation_step, 0.23)
	spin_tween.tween_property(circle_arrow_icon, "rotation", circle_arrow_icon.rotation + 2*PI, 0.23).set_ease(Tween.EASE_OUT)
	
	for i in range(MAX_EFFECT_COUNT):
		var barrel_info_icon: BarrelInfoIcon = barrel_info_icon_effect_pool[i]
		if not barrel_info_icon.visible:
			continue
		# TODO - tween the rotation with some bounce
		spin_tween.tween_property(barrel_info_icon, "rotation", - (circle_ring_centerpoint.rotation + rotation_step), 0.23)
	
	await spin_tween.finished
	spin_tween = null
	return


# When barrel is focused in Inventory/Shop, show the barrel overview details
# When the player holds the DETAIL input, show the effect detail ring instead


func set_barrel_data_resource(_barrel_data: BarrelDataResource) -> void:
	barrel_data = _barrel_data
	refresh_ui()


func refresh_ui() -> void:
	return
	# Empty the circle ring UI elements
	# TODO - pregen 4 UI elements (capping this to 3 makes more sense but elemental barrel has 4 effects currently)
	#  and clear them between refreshes
	#for ui in barrel_info_icon_effect_pool:
		#ui.visible = false
	
	# Spawn barrel prefab to get its data
	#var barrel_inst: SpinBarrel = barrel_data.barrel_prefab.instantiate()
	#add_child(barrel_inst)
	#barrel_inst.visible = false
	#barrel_inst.global_position = Vector3(9999, 9999, 9999) # Yeet it away
	#barrel_inst.queue_free()

	# Update Barrel Info Summary UI


func _process(delta: float) -> void:
	queue_redraw()


func get_circle_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for i in range(count):
		var angle = (TAU / count) * i # TAU = 2*PI
		var x = circle_ring_center_pos.x + (circle_ring.size.x / 2) + circle_ring_radius * cos(barrel_info_icon_effect_angles[i] + angle)
		var y = circle_ring_center_pos.y + (circle_ring.size.x / 2) + circle_ring_radius * sin(barrel_info_icon_effect_angles[i] + angle)
		positions.append(Vector2(x, y))
	
	return positions


func override_description_content(content: String):
	barrel_desc_label.text = content


#func reset_ui():
	#override_description_content("")
	#panel_barrel_icon.texture = null
	#for child in circle_ring.get_children():
		#child.queue_free()


func set_barrel_locked():
	#reset_ui()
	override_description_content("[center]Not available in demo[/center]")

#
#func unfocus_other_barrel_info_icon():
	#for child: BarrelInfoIcon in circle_ring.get_children():
		#child.focus_exited.emit()

func _on_effect_detail_focus_gained(ui: BarrelInfoIcon) -> void:
	var ui_idx: int = ui.get_index()
	if ui_idx == active_effect_detail_idx:
		ui.play_button_hover_sfx()
		return
	
	# FIXME - hovering over a new slot and cycling will set active icon to idx
	active_detail_icon._on_focus_exited()
	active_detail_icon = ui
	set_effect_detail_data(ui_idx)


func _on_effect_detail_focus_lost(ui: BarrelInfoIcon) -> void:
	if ui.get_index() == active_effect_detail_idx:
		return
	
	active_detail_icon = barrel_info_icon_effect_pool[active_effect_detail_idx]
	active_detail_icon._on_focus_entered()
	set_effect_detail_data(active_effect_detail_idx)


func _on_effect_detail_clicked(ui: BarrelInfoIcon) -> void:
	var ui_idx: int = ui.get_index()
	if ui_idx == active_effect_detail_idx:
		return
	
	var rotations: int = wrapi(
		active_effect_detail_idx - ui_idx,
		0,
		current_effect_count
	)
	
	for i in range(rotations):
		await cycle_effect_detail(true)
