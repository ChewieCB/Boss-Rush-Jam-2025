@tool
extends Control
class_name AnteItem

signal ante_selected(ante_number: int)
signal ante_purchased(ante_number: int)

## Max 5
@export var ante_number: int
@export_multiline var ante_name: String
@export var icon_sprite: Texture2D

@export var ante_icon: TextureRect
@export var ante_label: Label
@onready var deselected_overlay: ColorRect = $VBoxContainer/AnteItem/DeselectedOverlay
@onready var locked_overlay: ColorRect = $VBoxContainer/AnteItem/LockedOverlay
@onready var description_overlay: MarginContainer = $VBoxContainer/AnteItem/DescriptionOverlay
@onready var description_label: RichTextLabel = $VBoxContainer/AnteItem/DescriptionOverlay/Panel/MarginContainer/Label
@export var button: Button
@onready var border: NinePatchRect = $VBoxContainer/AnteItem/BorderNormal
@onready var border_selected: NinePatchRect = $VBoxContainer/AnteItem/BorderSelected
@export var currency_ui: MarginContainer
@export var currency_label: Label


@export var scale_factor: float = 1.15

@export var locked: bool = false:
	set(value):
		locked = value
		if not is_node_ready():
			await ready
		locked_overlay.visible = locked
@export var cost: int = 2000
@export var purchased: bool = false:
	set(value):
		purchased = value
		locked = !purchased
		currency_ui.visible = !purchased


func _ready() -> void:
	ante_label.text = ante_name
	ante_icon.texture = icon_sprite
	locked_overlay.visible = locked
	deselected_overlay.visible = true
	locked = !purchased
	#button.disabled = locked
	currency_label.text = str(cost)
	currency_ui.visible = !purchased
	description_overlay.visible = false

	if not Engine.is_editor_hint():
		await get_tree().process_frame
		await get_tree().process_frame
		GameManager.risk_level_changed.connect(_on_risk_level_changed)
		_on_risk_level_changed()


func _on_risk_level_changed():
	return
	#if GameManager.boss_ante >= ante_number:
		##self_modulate = Color.WHITE
		#ante_label.add_theme_color_override("font_color", Color.BLACK)
	#else:
		#self_modulate = Color.BLACK
		#ante_label.add_theme_color_override("font_color", Color.WHITE)


func set_ante_label(content: String):
	ante_label.text = ""
	match ante_number:
		1:
			ante_label.text = "Ante I:"
		2:
			ante_label.text = "Ante II:"
		3:
			ante_label.text = "Ante III:"
		4:
			ante_label.text = "Ante IV:"
		5:
			ante_label.text = "Ante V:"
	ante_label.text += " {0}".format([content])


func set_ante_description(content: String) -> void:
	description_label.text = content


func set_ante_texture(tex: Texture2D) -> void:
	ante_icon.texture = tex


func purchase_ante(idx: int) -> void:
	if GameManager.player_currency >= cost:
		GameManager.player_currency -= cost
		purchased = true
		locked = false
		# TODO play sfx
		ante_purchased.emit(idx)
	else:
		# TODO - play sfx
		pass


func _on_button_pressed() -> void:
	if purchased:
		ante_selected.emit(ante_number)
		_on_button_focus_exited()
	else:
		purchase_ante(self.get_index())


func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()


func expand_button_size():
	#if button.disabled:
		#return
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(scale_factor, scale_factor), 0.1)


func return_button_size():
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1)

func anim_button_pressed():
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.set_parallel(false)
	tween.tween_property(self, "scale", Vector2(0.7, 0.7), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _on_button_mouse_entered() -> void:
	_on_button_focus_entered()

func _on_button_mouse_exited() -> void:
	_on_button_focus_exited()


func _on_button_focus_entered(_grab_focus: bool = true) -> void:
	play_button_hover_sfx()
	expand_button_size()
	border.modulate = Color("#e6c600")
	border_selected.visible = true
	deselected_overlay.visible = false
	description_overlay.visible = true

func _on_button_focus_exited() -> void:
	return_button_size()
	border.modulate = Color("#4f4d3f")
	border_selected.visible = false
	deselected_overlay.visible = true
	description_overlay.visible = false
