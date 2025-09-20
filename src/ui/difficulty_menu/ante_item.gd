@tool
extends TextureRect
class_name AnteItem

## Max 5
@export var ante_number: int
@export_multiline var ante_name: String
@export var icon_sprite: Texture2D

@onready var ante_label: Label = $Label

func _ready() -> void:
	ante_label.text = ante_name

	if not Engine.is_editor_hint():
		await get_tree().process_frame
		await get_tree().process_frame
		GameManager.risk_level_changed.connect(_on_risk_level_changed)
		_on_risk_level_changed()


func _on_risk_level_changed():
	if GameManager.boss_ante >= ante_number:
		self_modulate = Color.WHITE
		ante_label.add_theme_color_override("font_color", Color.BLACK)
	else:
		self_modulate = Color.BLACK
		ante_label.add_theme_color_override("font_color", Color.WHITE)

		
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