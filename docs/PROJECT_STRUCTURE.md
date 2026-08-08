# Forest Gear — project structure

```text
forest-gear/
├── project.godot                  # Project settings and complete input map
├── export_presets.cfg             # Windows, Linux, Android and Web presets
├── autoload/
│   ├── game_manager.gd            # Run state, score, timer and level flow
│   ├── save_manager.gd            # High score, unlocks and key bindings
│   └── object_pool.gd             # Projectile and reusable-enemy pools
├── components/
│   └── pixel_art.gd               # Shared pixel drawing helpers
├── enemies/
│   ├── enemy.gd / enemy.tscn      # Three original enemy behaviours
│   ├── enemy_spawner.gd/.tscn     # Reusable pooled enemy spawn point
│   └── boss.gd / boss.tscn        # Gearheart Guardian boss
├── levels/
│   ├── level_base.gd/.tscn        # TileMap construction and level helpers
│   ├── forest_level.*             # Level 1
│   ├── cave_level.*               # Level 2
│   ├── snow_level.*               # Level 3
│   ├── boss_level.*               # Boss level
│   └── test_level.tscn            # Directly runnable entry level
├── player/
│   └── player.gd / player.tscn    # FSM, movement, combat, health and stamina
├── projectiles/
│   └── energy_ball.gd/.tscn       # Pooled energy projectile
├── ui/
│   ├── hud.gd / hud.tscn          # Health, stamina, score, timer, collectibles
│   └── virtual_button.gd/.tscn    # Android multi-touch controls
└── world/
    ├── checkpoint.gd/.tscn
    ├── collectible.gd/.tscn
    ├── falling_rock.gd/.tscn
    ├── level_exit.gd/.tscn
    ├── moving_platform.gd/.tscn
    ├── spring.gd/.tscn
    └── spike.gd/.tscn
```

The player and forest biome now use the generated original sprite sheet and
TileSet in `assets/generated/`. Remaining biome/enemy visuals use the original
low-resolution CanvasItem drawing code. No third-party character, map, music,
sound effect, or game asset is included.
