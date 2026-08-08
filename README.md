# Forest Gear

Forest Gear is an original 2D pixel platformer made for Godot 4 with GDScript.
It uses only programmatically drawn geometric pixel art and does not contain or
imitate characters, maps, audio, names, or other protected assets from existing
commercial platform games.

## Run

1. Open this folder in Godot 4.3 or newer.
2. Press **F6** on any level scene, or **F5** to start
   `res://levels/test_level.tscn`.
3. The test level leads to Cave, Snow and the Gearheart Guardian boss level.

Headless project validation:

```bash
godot4 --headless --path . --editor --quit
```

## Controls

| Action | Keyboard | Xbox-style pad | PlayStation-style pad |
|---|---|---|---|
| Move | A / D | Left stick / D-pad | Left stick / D-pad |
| Jump | Space | A | Cross |
| Run | K | X | Square |
| Energy orb | J | B | Circle |
| Stomp | S | Y | Triangle |
| Pause | Escape | Menu | Options |

Android uses multi-touch virtual buttons for move, run, jump, stomp, pause and
energy-orb actions. They become visible when a touchscreen/mobile platform is
detected.

## Included systems

- Seven-state player FSM: Idle, Run, Jump, Fall, Attack, Hurt and Dead.
- Health, stamina, score, timer, collectible and checkpoint state.
- The generated 16×16 forest atlas is used by the forest TileMap; the other
  biomes retain runtime-generated fallback TileSets.
- The player FSM drives an AnimatedSprite2D resource built from the generated
  32×32 forest-mechanic sprite sheet.
- Original Beetle Bot, Bouncecap, Gearwing and Gearheart Guardian designs.
- Moving platforms, springs, falling rocks, spikes and fading hidden areas.
- Pooled projectiles and pooled respawning enemies.
- JSON save data for high score, unlocked levels and keyboard bindings.
- Export presets for Windows, Linux, Android and Web.

Export templates and (for Android) a configured Android SDK are still required
in the local Godot installation before producing platform binaries.
