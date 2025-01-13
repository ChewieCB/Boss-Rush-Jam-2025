extends Area3D

@export var data: BarrelDataResource

@onready var label: Label3D = $Model/Label3D
@onready var model: MeshInstance3D = $Model

func _ready() -> void:
	if data:
		init(data)

func init(_data: BarrelDataResource):
	data = _data
	label.text = data.barrel_name
	# Temporarily texture for easier differentiate barrels
	model.material_override.albedo_texture = data.barrel_image

func interact():
	GameManager.add_barrel_to_inventory(data)
	call_deferred("queue_free")