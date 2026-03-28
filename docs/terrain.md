# Terrain System

Terraria-style block-based terrain with digging and treasure.

## Current State

### Block Grid (`TerrainBlock.gd`)
- 32x32px StaticBody2D blocks arranged in a grid
- Each chunk: 40 columns x 16+ rows (1 grass + dirt + stone)
- Grass row (y=0): green with 2-4 decorative tufts on top edge (3-8px tall, varied green)
- Dirt rows (y=1-5): brown with 4 distinct shade variations (deterministic per block)
- Stone rows (y=6+): grey palette with 3 color variants — distinct from dirt
- Blocks tracked in `_terrain_blocks` dict as `"chunk_idx,gx,gy"` keys
- Block borders have varied opacity (0.05-0.11) for natural grid feel
- Progressive underground darkening: full brightness at surface, 40% minimum at deepest

### Background Walls
- Darker semi-transparent blocks (60% opacity) behind terrain at z_index -3
- Visible when foreground blocks are dug out — gives underground depth
- Color matches block type (brown for dirt depth, grey for stone depth)
- Also darkened with depth, matching foreground block darkening

### Parallax Background
- Mountain silhouettes at z_index -9, scroll at 30% of camera speed
- Two ranges: tall back mountains (lighter) and shorter front mountains (darker)
- Cloud layer at z_index -8, scroll at 50% of camera speed
- Procedural generation using world seed for deterministic variety

### Digging (`PlayerController.gd` + `MainScene.gd`)
- Aim: right stick (gamepad) > left stick > facing direction
- Aim snaps to 32px grid (block-aligned cursor)
- Hold Q/LB to mine continuously (0.25s cooldown between breaks)
- Dig range: 96px (3 blocks from player)
- Visual cursor: crosshair + highlighted block outline
- `dig_requested(position)` signal sent to MainScene
- MainScene finds nearest block within 20px (then 40px) of cursor position

### Block Breaking
- `TerrainBlock.dig()` destroys the block
- 4 small ColorRect particles fly out with tween animation
- Particle color matches block type (green for grass, brown for dirt, grey for stone)
- If `has_treasure`: spawns TreasureChest at block position

### Treasure Chests (`TreasureChest.gd`)
- **Underground**: 6% chance per dirt block to contain treasure
- **Surface**: 1-2 chests per chunk sitting on ground (GROUND_Y - 9)
- Press E/X to open (interact action)
- Rewards: 3-5 coins (random) + 1 needed letter (always)
- Open animation: lid flies up, body dims, "+N" coin text floats up
- Single-use (cannot reopen)

### Chest Visual
- Brown body (28x18), darker lid (32x8), gold clasp (6x5)
- Built from ColorRect nodes (no sprites)
- collision_layer = 4 (interactable)

### Bedrock
- Unbreakable floor below row 8
- Full chunk width, 20px thick, dark grey
- Prevents player from falling through the world

## Known Issues

- Blocks don't regenerate — once dug, permanently gone for that chunk
- Chunk recycle doesn't clean up `_terrain_blocks` entries for removed chunks
- No visual indication of treasure blocks before digging (sparkle exists but very subtle)
- Player can get trapped if they dig straight down with no horizontal exit
- Wall slide + wall jump partially mitigates getting stuck

## Future Work

- ~~Block types: stone at deeper levels~~ (DONE — stone at row 6+)
- Ore and gem blocks at deeper levels
- Terrain regeneration on chunk recycle
- Mining tool upgrades (hammer from Francis's ideas)
- Underground biomes (caves, crystals)
- Block placement (building — "hammer to build houses" from Francis)
- Axe for cutting trees (Francis's idea)
