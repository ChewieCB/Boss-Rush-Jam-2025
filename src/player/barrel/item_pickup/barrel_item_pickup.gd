extends Area3D

signal collected(data: BarrelDataResource)

@export var data: BarrelDataResource

@onready var label: Label3D = $Model/Label3D
@onready var model: MeshInstance3D = $Model

func _ready() -> void:
	if data:
		init(data)


func _process(delta) -> void:
	model.rotation.y += delta


func init(_data: BarrelDataResource):
	data = _data
	label.text = data.barrel_name
	# Temporarily texture for easier differentiate barrels
	model.material_override.albedo_texture = data.barrel_image

func interact():
	if GameManager.inventory_barrels.size() <= 1:
		GameManager.player_gained_first_barrel = true
	GameManager.add_barrel_to_inventory(data)
	collected.emit(data)
	call_deferred("queue_free")
