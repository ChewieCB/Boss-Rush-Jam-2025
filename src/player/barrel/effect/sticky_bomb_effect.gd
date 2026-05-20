extends CompoundEffect


@export_group("Luck Triggers")
@export_subgroup("Cluster Bomb")
@export var luck_trigger_sticky_threshold: int = 20
@export var luck_gain_sticky: float = 25.0
#
# Track how many sticky bomb projectiles have hit the target - have a callback to update this on proj impact.
# From the first hit, track when the first sticky proj detonates and cap the window there, checking against the luck trigger and resetting the counter
var sticky_hits: int = 0

@export_subgroup("Danger Close")
@export var luck_trigger_indirect_damage_threshold: float = 100.0
@export var luck_gain_indirect_damage: float = 20.0
#
@export var explosive_dps_dealt_window: float = 2.4 
@export var explosive_dps_dealt_window_timer: Timer
var explosive_dps_accumulated_in_window: float = 0.0:
	set(value):
		explosive_dps_accumulated_in_window = value
		if explosive_dps_dealt_window_timer.is_stopped():
			explosive_dps_dealt_window_timer.start(explosive_dps_dealt_window)



func on_projectile_spawn(_projectile: BaseBullet):
	super(_projectile)
	await get_tree().physics_frame
	_projectile.before_damage_applied.connect(_update_sticky_hit_tracker)
	if "explosion_inst" in _projectile:
		_projectile.explosion_inst.explosive_damage.connect(_on_explosive_damage.bind(_projectile))


func _on_explosive_damage(damage: float, body: CharacterBody3D, _projectile: StickyBombProjectile) -> void:
	# Don't trigger luck buff if we damage outselves
	if body is not Player:
		# Only count damage from bombs NOT stuck to enemy
		if not _projectile.get_parent() is CharacterBody3D:
			accumulate_dps_dealt(damage)

## Cluster Bomb Luck Trigger

func _update_sticky_hit_tracker(_enemy: CharacterBody3D, projectile: BaseBullet) -> void:
	# If this is the first hit of a new window, track this projectile so we can callback when it detonates
	if sticky_hits == 0:
		projectile.destroyed.connect(_on_first_proj_in_window_destroyed)
	sticky_hits += 1
	
	
func _on_first_proj_in_window_destroyed(_hit_boss: bool) -> void:
	if sticky_hits >= luck_trigger_sticky_threshold:
		var enum_str: String = LuckTriggerInfo.LuckTriggerIdEnum.keys()[
			LuckTriggerInfo.LuckTriggerIdEnum.STICKY_BOMB__CLUSTER_BOMB
		]
		if LuckHandler.luck_trigger_dict[enum_str] == false:
			LuckHandler.luck_trigger_dict[enum_str] = true
			LuckHandler.trigger_discovered.emit()
		
		LuckHandler.increase_luck(luck_gain_sticky, "+25 Cluster Bomb!")
	
	sticky_hits = 0


## Danger Close Luck Trigger

func accumulate_dps_dealt(damage: float) -> void:
	explosive_dps_accumulated_in_window += damage


func _on_dps_dealt_window_timer_timeout() -> void:
	if explosive_dps_accumulated_in_window > luck_trigger_indirect_damage_threshold:
		# Mark the luck trigger as discovered if we haven't triggered it before
		var enum_str: String = LuckTriggerInfo.LuckTriggerIdEnum.keys()[
			LuckTriggerInfo.LuckTriggerIdEnum.STICKY_BOMB__DANGER_CLOSE
		]
		if LuckHandler.luck_trigger_dict[enum_str] == false:
			LuckHandler.luck_trigger_dict[enum_str] = true
			LuckHandler.trigger_discovered.emit()
		
		LuckHandler.increase_luck(luck_gain_indirect_damage, "+20 Danger Close!")
	
	explosive_dps_accumulated_in_window = 0.0
