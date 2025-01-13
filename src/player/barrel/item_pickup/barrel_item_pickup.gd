extends Area3D

@export var data: BarrelDataResource

@onready var label: Label3D = $Model/Label3D

func _ready() -> void:
	if data:
		label.text = data.barrel_name

func init(_data: BarrelDataResource):
	data = _data
	label.text = data.barrel_name

func interact():
	GameManager.add_barrel_to_inventory(data)
	call_deferred("queue_free")