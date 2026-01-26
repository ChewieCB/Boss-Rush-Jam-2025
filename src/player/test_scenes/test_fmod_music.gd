extends Node2D


@export var music_state_list: Array[String] = ["Menu", "Lobby", "Slotty", "Roulette", "Bartender", "GenericBossAftermath", "PitbossHallway",
	"PitbossMainfight", "ChipbossInt", "ChipbossStart", "BlackjackStart", "TutorialBossfight", "Tutorial1", "Tutorial2"]
@export var log_line_prefab: PackedScene

@onready var disc_image: TextureRect = $CanvasLayer/Disc
@onready var anim_player: AnimationPlayer = $CanvasLayer/AnimationPlayer
@onready var music_state_option_button: OptionButton = $CanvasLayer/MusicState/OptionButton
@onready var log_scroll_container: ScrollContainer = $CanvasLayer/Panel/ScrollContainer
@onready var log_container: Container = $CanvasLayer/Panel/ScrollContainer/VBoxContainer
@onready var bpm_label: Label = $CanvasLayer/BPMLabel


var tween: Tween
var original_disc_scale: Vector2
var pulse_scale: float = 1.05 # max scale factor
var pulse_duration: float = 0.1 # how fast pulse animates (seconds)

func _ready() -> void:
	for elem in music_state_list:
		music_state_option_button.add_item(elem)
	original_disc_scale = disc_image.scale
	GameManager.main_bgm_emitter.timeline_beat.connect(timeline_beat_callback)

func add_log_line(content: String):
	var log_line: RichTextLabel = log_line_prefab.instantiate()
	log_line.text = "> " + content
	log_container.add_child(log_line)
	await get_tree().process_frame
	await get_tree().process_frame
	log_scroll_container.scroll_vertical = int((log_container.get_child_count() + 1) * log_line.size.y)

	
func _on_start_button_pressed() -> void:
	GameManager.main_bgm_emitter.play()
	anim_player.play("spin_disc")
	add_log_line("Start BGM")


func _on_stop_button_pressed() -> void:
	GameManager.main_bgm_emitter.stop()
	anim_player.pause()
	add_log_line("Stop BGM")


func _on_volume_value_changed(value: float) -> void:
	GameManager.main_bgm_emitter.volume = value


func _on_option_button_item_selected(index: int) -> void:
	GameManager.change_fmod_bgm_music_state(music_state_list[index])
	add_log_line("Changed [color=yellow]MusicState[/color] param to [color=yellow]{0}[/color]".format([music_state_list[index]]))


func _on_player_in_menu_toggled(toggled_on: bool) -> void:
	GameManager.change_fmod_bgm_menu_is_up(toggled_on)
	add_log_line("Changed [color=yellow]menuIsUp[/color] param to [color=yellow]{0}[/color]".format([toggled_on]))


func _on_player_dead_toggled(toggled_on: bool) -> void:
	GameManager.change_fmod_bgm_player_is_dead(toggled_on)
	add_log_line("Changed [color=yellow]playerIsDead[/color] param to [color=yellow]{0}[/color]".format([toggled_on]))


func timeline_beat_callback(params: Dictionary) -> void:
	var beat = params['beat']
	var bar = params['bar']
	var tempo = params['tempo']
	bpm_label.text = "Beat: {0}\nBar: {1}\nBPM: {2}".format([beat, bar, tempo])
	_on_beat()

func _on_beat():
	# Cancel previous tween if still playing
	if tween and tween.is_running():
		tween.stop()
		disc_image.scale = original_disc_scale
	tween = create_tween()
	# Pulse out
	tween.tween_property(disc_image, "scale", original_disc_scale * pulse_scale, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Pulse back in
	tween.tween_property(disc_image, "scale", original_disc_scale, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
