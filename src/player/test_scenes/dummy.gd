extends CharacterBody3D
class_name Dummy

@export var health_component: HealthComponent
@export var status_resist: Dictionary = {
	BossCore.BossStatusEffect.BURNING: 1000,
	BossCore.BossStatusEffect.POISONED: 1000,
	BossCore.BossStatusEffect.FROZEN: 1000,
	BossCore.BossStatusEffect.SHOCKED: 1000,
	BossCore.BossStatusEffect.BLEEDING: 1000,
}
@export var status_duration = 10

@onready var damage_label: Label3D = $DamageLabel
@onready var status_label: Label3D = $StatusLabel
@onready var happy_face_label: Label3D = $HappyFaceLabel
@onready var sad_face_label: Label3D = $SadFaceLabel
@onready var timer: Timer = $ResetTotalDamageTimer

var current_status_buildup: Dictionary = {
	BossCore.BossStatusEffect.BURNING: 0,
	BossCore.BossStatusEffect.POISONED: 0,
	BossCore.BossStatusEffect.FROZEN: 0,
	BossCore.BossStatusEffect.SHOCKED: 0,
	BossCore.BossStatusEffect.BLEEDING: 1000,
}

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
	status_label.text = "Status: "

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

func apply_status_buildup(status: BossCore.BossStatusEffect, amount: float) -> void:
	if current_status_buildup[status] < status_resist[status]:
		current_status_buildup[status] += amount
		if current_status_buildup[status] >= status_resist[status]:
			apply_status(status, status_duration)

func apply_status(status: BossCore.BossStatusEffect, duration: float) -> void:
	var status_text = BossCore.BossStatusEffect.keys()[status].to_lower() + " "
	status_label.text += status_text
	await get_tree().create_timer(duration).timeout
	remove_status(status)


func remove_status(status: BossCore.BossStatusEffect) -> void:
	var status_text = BossCore.BossStatusEffect.keys()[status].to_lower() + " "
	status_label.text = status_label.text.replace(status_text, "")
	current_status_buildup[status] = 0