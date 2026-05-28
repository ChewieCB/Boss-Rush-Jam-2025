@tool
extends TextureRect
class_name AnteItem

signal ante_selected(ante_number: int)

## Max 5
@export var ante_number: int
@export_multiline var ante_name: String
@export var icon_sprite: Texture2D

@onready var ante_icon: TextureRect = $AnteIcon
@onready var ante_label: Label = $AnteLabelContainer/Panel/Label
@onready var deselected_overlay: ColorRect = $DeselectedOverlay
@onready var locked_overlay: ColorRect = $LockedOverlay
@onready var button: Button = $Button

@export var locked: bool = false

func _ready() -> void:
	ante_label.text = ante_name
	ante_icon.texture = icon_sprite
	locked_overlay.visible = locked
	button.disabled = locked

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
	ante_label.text += "\n{0}".format([content])


func set_ante_texture(tex: Texture2D) -> void:
	ante_icon.texture = tex

func _on_button_pressed() -> void:
	ante_selected.emit(ante_number)
