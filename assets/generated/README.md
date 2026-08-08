# Generated visuals

The playable project now uses the character sheet through
`player/forest_mechanic_frames.tres`, and the forest level builds its TileMap and
decorations from the forest atlas. Other biome/enemy art keeps its original
CanvasItem fallback, so the project has no third-party asset dependencies.

- `forest_mechanic_spritesheet_32px.png`: 256×192, 8 columns × 6 rows,
  transparent, with exact 32×32 frames.
- `forest_mechanic_spritesheet_32px.json`: animation row/count/FPS metadata.
- `forest_tileset_16px.png`: 256×288, transparent, aligned to 16×16 tiles.
- `forest_tileset_16px.json`: named atlas region metadata.
- `*-hires.png`: transparent high-resolution source sheets and the two generated
  supplemental animation frames used for future edits/repacking.

`tools/pack_generated_assets.py` documents the deterministic nearest-neighbor
packing, alpha hardening and limited-palette pass used for the production files.
