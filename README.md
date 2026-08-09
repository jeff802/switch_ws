# Forest Gear — Classic 8-Bit Platformer

Forest Gear is an original 2D pixel platformer for Godot 4 (GL Compatibility),
styled after the classic 8-bit side-scrolling platformers of the 1980s. All art,
levels and names are original and do not copy Nintendo's characters, maps,
sprites, audio or other protected assets.

## Run

1. Open this folder in Godot 4.3 or newer (project is saved as 4.7).
2. Press **F5** to start `res://levels/test_level.tscn`.
3. The test level leads to Cave, Snow and the Gearheart Guardian boss level.

Fullscreen is designed for big screens: the game renders at 640×360 and uses
integer scaling (3× at 1080p, 4× at 1440p) so pixels stay crisp.

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
| Energy bolt | J | B | Circle |
| Stomp / Ground pound | S | Y | Triangle |
| Pause / Settings | Escape | Menu | Options |

Android uses multi-touch virtual buttons for move, run, jump, stomp, pause and
energy-orb actions. They become visible when a touchscreen/mobile platform is
detected.

## Classic 8-bit features

- **Coins**: gold coins in rows and arcs; collect them for score.
- **Question blocks**: bump from below to pop a coin (or a power mushroom).
- **Bricks**: bump when small; smash them after growing.
- **Power mushroom**: grow big, take one extra hit, and break bricks.
- **Pipes**: green pipes as obstacles and platforms.
- **Flagpole**: finish the overworld level at the flag.
- **Overworld look**: blue sky, clouds, rolling hills, bushes and a distant
  castle, with a classic SCORE / COINS / TIME / WORLD HUD.
- Original hero, enemies and boss — no third-party or Nintendo assets.

## Learning the platformer feel

The project recreates the *rules and feel* of a classic momentum platformer
with original characters, art, audio and level layouts. The main tuning values
are grouped at the top of `player/player.gd` so they can be studied safely:

- `WALK_SPEED` / `RUN_SPEED`: the two horizontal speed caps.
- `GROUND_ACCELERATION` / `RUN_ACCELERATION`: how long it takes to build speed.
- `TURN_ACCELERATION`: the sharper skid used when reversing on the ground.
- `AIR_ACCELERATION`: intentionally lower than ground control.
- `RISING_GRAVITY`, `RELEASE_GRAVITY`, `FALLING_GRAVITY`: holding jump produces
  a higher arc; releasing it early produces a short hop.
- `RUN_JUMP_BONUS`: horizontal momentum adds height and distance to a jump.

Running is unlimited. The POWER display shows the current three-step upgrade
state, so a long run-up is never cancelled by an unrelated stamina system.
Touch input uses frame-to-frame action edge detection, keeping jump buffering
consistent across keyboard, controller and mobile virtual buttons.

Projectile progression is `SMALL → GEAR → BOLT`: a small character receives a
growth pickup from a power-up block, while a large character receives the
original mechanical Energy Bloom. BOLT mode enables ground-bouncing shots,
limits each player to two active shots, and downgrades to GEAR on damage.

The goal sequence in `world/flagpole.gd` is a useful example of a scripted
state transition: it freezes the timer, scores the grab height, drops the
banner, slides the player down, walks them off-screen, and only then changes
the level.

## Settings (pause menu)

Press **Escape** to open the settings menu:

- **音效开关**: toggle all synthesized 8-bit sound effects.
- **音量大小**: volume slider (0–100%).
- **角色切换**: cycle between three original characters (GEAR / BLAZE /
  FROST) with different tints and run/jump stats.
- Settings are saved automatically to `user://settings.json`.

All sound effects are generated procedurally at runtime (square waves and
noise) — no audio asset files are included.

## Included systems

- Seven-state player FSM: Idle, Run, Jump, Fall, Attack, Hurt and Dead.
- Health, three-step projectile power, score, coin, timer and checkpoint state.
- Small/big player forms (grow on mushroom, shrink on hit).
- Original Beetle Bot, Bouncecap, Gearwing and Gearheart Guardian designs.
- Moving platforms, springs, falling rocks, spikes, fading hidden areas and
  pooled projectiles/enemies.
- JSON save data for high score, unlocked levels and keyboard bindings.
- Export presets for Windows, Linux, Android and Web.
