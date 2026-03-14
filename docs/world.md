# World Generation

Infinite procedural chunk-based world.

## Current State

### Chunk System (`MainScene.gd`)
- CHUNK_WIDTH: 1280px (one screen width)
- MAX_CHUNKS: 7 active (player +-3 chunks)
- Chunks generate as player moves, recycle when >3 chunks away
- Infinite in both left and right directions

### Per-Chunk Contents
- **Sky**: blue ColorRect background (z_index -10)
- **Terrain**: 40 columns x 9 rows of 32px blocks (grass + dirt)
- **Platforms**: 1-3 floating platforms at Y 450-650 (variable width 120-220px)
- **Trees**: 1-3 procedural trees (variable trunk height, canopy size, color)
- **Flowers**: 2-5 at ground level (5 color varieties)
- **Clouds**: 1-2 floating clouds (variable opacity 0.4-0.7, z_index -5)
- **Archery targets**: 20% chance per chunk
- **Surface treasure chests**: 1-2 per chunk on ground

### World Generator (`WorldGenerator.gd`)
- Utility class for procedural generation helpers
- `generate_platform_positions()`: random elevated platform placement
- `generate_decoration_positions()`: scatter decorations within bounds
- `pick_weather()`: weighted random (sunny 40%, cloudy 20%, rain 10%, sunset 20%, starry 10%)
- `should_wonder_event()`: 5% chance per area (rainbow, shooting stars, aurora, butterflies, double sun)
- Accepts seed for reproducible generation

### Letter Thief (`LetterThief.gd`)
- Spawns when player touches wrong letter
- Chases nearest needed letter at 30 px/s (very slow, child-safe)
- Max 3 active at once
- Defeat: jump on (stomp) or shoot with arrow
- Defeat animation: jump, spin 2x, shrink, vanish
- Steals letter on contact (letter disappears)

### Archery Targets
- Standing wooden targets with red ring and white center
- Spin/shrink on hit, then reform
- Optional letter display (for future Word Archery mode)

## Known Issues

- Weather and wonder events are defined but never rendered visually
- Chunk recycling doesn't clean up terrain block tracking dictionary
- No biome variation — every chunk looks the same (meadow only)
- Platforms have no visual variation (all brown rectangles)
- Trees and flowers are simple ColorRects with no animation

## Future Work

- Area transitions: meadow, castle, beach, forest, mountain (from word bank areas)
- Day/night cycle (aesthetic only, per game design doc)
- Parallax background layers for depth
- Living world: birds, butterflies, ambient particles
- Castle zone with shop (Francis's idea)
- Seasons implementation (Francis's idea: "all seasons")
- NPCs and towns
- Underground biomes (caves, crystal caverns)
