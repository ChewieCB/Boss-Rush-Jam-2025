extends CharacterBody3D

@export var health_component: HealthComponent

@onready var damage_label: Label3D = $DamageLabel
@onready var happy_face_label: Label3D = $HappyFaceLabel
@onready var sad_face_label: Label3D = $SadFaceLabel
@onready var timer: Timer = $ResetTotalDamageTimer

var last_hit = 0
var total_damage = 0
var dps = 0
var started_calculating_dps = false
var dps_time = 0

func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	happy_face_label.visible = true
	sad_face_label.visible = false


## ======== Signal Callback Methods ========

func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		last_hit = prev_health - new_health
		total_damage += last_hit
		if dps_time <= 0:
			dps = total_damage
		else:
			dps = total_damage / dps_time
		dps = snapped(dps, 0.01)
		damage_label.text = "Last hit: {0}\nTotal damage: {1}\nDPS: {2}".format([last_hit, total_damage, dps])
		timer.start()
		started_calculating_dps = true
		happy_face_label.visible = false
		sad_face_label.visible = true

func _process(delta: float) -> void:
	if started_calculating_dps:
		dps_time += delta


func _on_died() -> void:
	health_component.current_health = health_component.max_health

func _on_reset_total_damage_timer_timeout() -> void:
	damage_label.text = "Last hit: {0}\nTotal damage: {1}\nDPS: 0".format([last_hit, total_damage, dps])
	total_damage = 0
	dps_time = 0
	started_calculating_dps = false
	happy_face_label.visible = true
	sad_face_label.visible = false
