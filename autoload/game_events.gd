extends Node
## Central event bus for gameplay systems that should not own each other.

signal player_state_changed(state_name: String)
signal mobility_changed(air_jumps_remaining: int, wall_sliding: bool)
signal ability_used(ability_name: String)
signal collectible_collected(collectible_id: String, value: int, heals: bool)
signal checkpoint_activated(level_id: String, world_position: Vector2)
signal platform_endpoint_reached(platform: Node2D, at_destination: bool)
signal campaign_progressed(stage_index: int)
signal level_reload_requested(level_id: String)
signal level_reloaded(level_id: String)
signal save_completed(save_path: String)
