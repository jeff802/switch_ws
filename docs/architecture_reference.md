# Architecture reference notes

Reference project: [SlayHorizon/godot-2d-platformer-demo](https://github.com/SlayHorizon/godot-2d-platformer-demo)
Reviewed commit: `6944ec4c323dcbad470ff7654fec665f010f50d1`
Source license: MIT. Asset licenses are separate; no reference-project assets
were copied into Forest Gear.

## Concept mapping

| Studied concept | Forest Gear implementation |
|---|---|
| Callback player states | `player/player_state_machine.gd` registers state entry and physics callbacks while preserving the existing momentum controller. |
| Double jump and wall movement | `player/player.gd` adds a single rechargeable air jump, wall-slide fall cap and directional wall-jump lock. |
| Event Bus autoload | `autoload/game_events.gd` carries mobility, collectible, checkpoint, platform, reload, campaign and save events. |
| Moving platform | The existing `AnimatableBody2D` platform keeps physics synchronization and now exposes motion control plus endpoint events. |
| Collectibles and HUD | Coins publish on the event bus; GameManager owns totals and HUD supplies collection, mobility and save feedback. |
| Level reload | R and the pause menu call `GameManager.reload_current_level()`, which reloads the complete scene from the saved checkpoint. |
| Transition shader | `ui/gear_wipe.gdshader` and the persistent `SceneTransition` autoload implement an original gear-tooth wipe. |
| Persistence | `autoload/save_manager.gd` uses a versioned JSON schema and backward-compatible defaults. |

The reference was used for architectural study. Names, tuning, game rules,
shader math and integration code in Forest Gear were written for this project.
