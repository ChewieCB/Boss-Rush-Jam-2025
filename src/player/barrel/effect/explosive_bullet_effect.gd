extends BaseBarrelEffect

@export var damage: int
@export var damage_variance: int = 11
@export var range: float

@export_group("Luck Triggers")
@export_subgroup("Bada Bing, Bada Boom!")
@export var luck_trigger_indirect_damage_threshold: float = 100.0
@export var luck_gain_indirect_damage: float = 20.0

@export_group("Explsive DPS Dealt In Last X Seconds")
@export var dps_dealt_window: float = 1.8
@export var dps_dealt_window_timer: Timer
var dps_accumulated_in_window: float = 0.0:
	set(value):
		dps_accumulated_in_window = value
		if dps_dealt_window_timer.is_stopped():
			dps_dealt_window_timer.start(dps_dealt_window)



func on_projectile_impact(_projectile: BaseBullet, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	if (_has_pos):
		create_explosion(_pos, _projectile.infused_status_effect)


func create_explosion(pos: Vector3, status_effects: Array):
	randomize()
	var explosion_inst = GameManager.object_pooling_manager.get_pooled_object(ObjectPoolingManager.PooledObjectEnum.EXPLOSION)
	explosion_inst.init(damage + randf_range(-damage_variance, damage_variance))
	for i in range(status_effects.size()):
		if status_effects[i]:
			explosion_inst.add_status_effect(i + 1)
	explosion_inst.explosive_damage.connect(_on_explosive_damage)
	explosion_inst.set_damage_radius(range)
	explosion_inst.activate(pos)


func _on_explosive_damage(damage: float, body: CharacterBody3D) -> void:
	if body is not Player:
		# Don't trigger luck buff if we damage outselves
		accumulate_dps_dealt(damage)


func accumulate_dps_dealt(damage: float) -> void:
	dps_accumulated_in_window += damage


func _on_dps_dealt_window_timer_timeout() -> void:
	if dps_accumulated_in_window > luck_trigger_indirect_damage_threshold:
		# Mark the luck trigger as discovered if we haven't triggered it before
		var enum_str: String = LuckTriggerInfo.LuckTriggerIdEnum.keys()[
			LuckTriggerInfo.LuckTriggerIdEnum.EXPLOSIVE_BULLET__BADA_BING_BADA_BOOM
		]
		if LuckHandler.luck_trigger_dict[enum_str] == false:
			LuckHandler.luck_trigger_dict[enum_str] = true
			LuckHandler.trigger_discovered.emit()
		
		LuckHandler.increase_luck(luck_gain_indirect_damage, "+20 Bada Bing, Bada Boom!")
	
	dps_accumulated_in_window = 0.0
