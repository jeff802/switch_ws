extends ForestGearLevel

var boss: GearheartGuardian


func _build_level() -> void:
	# Foundry Crown: a compact mechanical-city arena.
	solid_rect(0, 12, 72, 4, 3)
	solid_rect(8, 8, 7, 1, 2)
	solid_rect(28, 8, 7, 1, 2)
	solid_rect(49, 8, 7, 1, 2)
	add_entity(SPIKE_SCENE, Vector2(530, 184))
	add_entity(SPIKE_SCENE, Vector2(855, 184))
	add_entity(SPRING_SCENE, Vector2(265, 181), {"launch_strength": 500.0})
	add_collectible(Vector2(175, 112), true)
	add_collectible(Vector2(925, 112), true)
	boss = add_entity(BOSS_SCENE, Vector2(780, 150)) as GearheartGuardian
	hud.bind_boss(boss)
	boss.defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	GameManager.end_run()
	SaveManager.submit_score(GameManager.score)
	SaveManager.unlock_level("complete")
	hud.show_victory()

