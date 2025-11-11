extends HealthComponent

func damage(_damage: float, _color: Color = Color.WHITE, _text_scale_pop: float = 1.3) -> void:
	_damage = round(_damage * received_dmg_multiplier)

	if enabled:
		if not is_invincible:
			var player: Player = get_parent()

			# Dodge chance
			var roll = randi_range(1, 100)
			if roll <= player.current_stats[StatusEffect.PlayerStatEnum.DODGE_CHANCE] * 100:
				return

			if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.PLOT_ARMOR):
				var damage_can_be_absorbed = _damage * GameManager.PLOT_ARMOR_DAMAGE_ABSORB_PERC
				var luck_damage = damage_can_be_absorbed * GameManager.PLOT_ARMOR_LUCK_DAMAGE_MULTIPLIER
				if player.luck_component.current_luck >= luck_damage:
					player.luck_component.current_luck -= luck_damage
					_damage = _damage - damage_can_be_absorbed

			if current_health <= _damage:
				if player.check_if_has_status_effect_by_name("cheat_death_buff") and not player.cheat_death_triggered:
					player.cheat_death_triggered = true
					player.remove_status_effect_by_name("cheat_death_buff")
					current_health = 1
					player.luck_component.current_luck = 0
					return

			current_health -= _damage
