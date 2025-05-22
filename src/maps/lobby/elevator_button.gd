@tool
extends Area3D
class_name ElevatorButton

signal pushed(level_path: String)

@export var entProperties: Dictionary = {
	"linked_level": "",
	"boss_name": "",
}

var linked_level: String
var boss_name: String

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var label: Label3D = $Label3D
@onready var SFXButtonPress: AudioStreamPlayer3D = $SFXButtonPress


func _ready() -> void:
	linked_level = entProperties["linked_level"]
	boss_name = entProperties["boss_name"]
	label.text = boss_name


func interact() -> void:
	anim_player.play("push")
	if linked_level:
		pushed.emit(linked_level)
		SFXButtonPress.play()


func _func_godot_apply_properties(properties: Dictionary) -> void:
	entProperties = properties
