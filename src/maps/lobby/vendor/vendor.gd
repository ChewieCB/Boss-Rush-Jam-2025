extends PhysicsBody3D
class_name Vendor

@onready var dialogue_label: Label3D = $Label3D
@onready var shop_ui: InventoryUI = $UI/ShopUI
@onready var health_component: HealthComponent = $HealthComponent
@onready var interact_area: Area3D = $InteractArea

@export var player: Player


func _ready() -> void:
	health_component.hurt.connect(_on_hurt)
	dialogue_label.text = ""
	GameManager.barrel_purchased.connect(_on_purchase)
	GameManager.barrel_too_expensive.connect(_on_too_expensive)


func interact() -> void:
	shop_ui.toggle()
	player.input_dir = Vector2.ZERO
	player.vel_horizontal = Vector2.ZERO
	player.velocity = Vector3.ZERO


func show_dialogue(dialogue: String) -> void:
	dialogue_label.modulate.a = 0.0
	dialogue_label.text = dialogue
	var tween = get_tree().create_tween()
	tween.tween_property(dialogue_label, "modulate:a", 1.0, 0.5)


func _on_hurt() -> void:
	var hurt_dialogue = [
		"Hey!",
		"Cmon now!",
		"Quit it!",
	]
	show_dialogue(hurt_dialogue.pick_random())


func _on_purchase(_data: BarrelDataResource) -> void:
	var purchase_dialogue = [
		"Excellent choice!",
		"A fine aquisition sir.",
		"A patron of taste I see!",
	]
	show_dialogue(purchase_dialogue.pick_random())


func _on_too_expensive(_data: BarrelDataResource) -> void:
	var fail_dialogue = [
		"Perhaps something a little more\nin budget, sir?",
		"Another time perhaps.",
		"Taste better than your luck, eh?",
		"Come back when you're a little \nmmmm richer!"
	]
	show_dialogue(fail_dialogue.pick_random())


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		show_dialogue("Get your barrels here!\nAll chips accepted!")


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		show_dialogue("Good luck!")
		shop_ui.close()
