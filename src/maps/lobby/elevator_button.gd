@tool
extends Area3D
class_name ElevatorButton

signal pushed(level_path: String, elevator_doors: ElevatorDoors, respawn_marker: Marker3D)

@export var entProperties: Dictionary = {
	"linked_level": "",
	"boss_name": "",
}
@export var boss_id: BossCore.BossIdEnum

var linked_level: String
var boss_name: String

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var label: Label3D = $Label3D
@onready var SFXButtonPress: AudioStreamPlayer3D = $SFXButtonPress
@export var disabled: bool = false
@export var linked_elevator_doors: ElevatorDoors
@export var hub_respawn_marker: Marker3D

@export var interact_dist: float = 2.5


func _ready() -> void:
	linked_level = entProperties["linked_level"]
	boss_name = entProperties["boss_name"]
	label.text = boss_name


func interact() -> void:
	if disabled:
		# TODO - locked button sfx
		return
	anim_player.play("push")
	GameManager.selected_boss_id = boss_id
	if linked_level:
		pushed.emit(linked_level, linked_elevator_doors, hub_respawn_marker)
		SFXButtonPress.play()


func get_interact_text() -> String:
	return "Select {0}".format([boss_name])


func _func_godot_apply_properties(properties: Dictionary) -> void:
	entProperties = properties
