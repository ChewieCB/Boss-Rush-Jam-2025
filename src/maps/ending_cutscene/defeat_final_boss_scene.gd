extends Control

@export var gun_shot_sfx: AudioStream
@export var fire_sfx: AudioStream
@export var credit_scene: PackedScene

@onready var continue_prompt: Control = $ContinuePrompt

var cutscene_finished = false

func _ready() -> void:
	continue_prompt.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if cutscene_finished:
			go_to_credit_scene()


func play_gun_shot_sfx():
	SoundManager.play_sound(gun_shot_sfx, "SFX")

func play_fire_sfx():
	SoundManager.play_sound(fire_sfx, "SFX")

func go_to_credit_scene():
	get_tree().change_scene_to_packed(credit_scene)

func set_cutscene_finished():
	cutscene_finished = true
	continue_prompt.visible = true