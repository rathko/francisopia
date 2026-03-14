# Terrain System

Terraria-style block-based terrain with digging and treasure.

## Current State

### Block Grid (`TerrainBlock.gd`)
- 32x32px StaticBody2D blocks arranged in a grid
- Each chunk: 40 columns x 9 rows (1 grass + 8 dirt)
- Grass row (y=0): green, sits at GROUND_Y (725px)
- Dirt rows (y=1-8): brown with slight color variation per block
- Blocks tracked in `_terrain_blocks` dict as `"chunk_idx,gx,gy"` keys

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
- Particle color matches block type (green for grass, brown for dirt)
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

- Block types: stone, ore, gem blocks at deeper levels
- Terrain regeneration on chunk recycle
- Mining tool upgrades (hammer from Francis's ideas)
- Underground biomes (caves, crystals)
- Block placement (building — "hammer to build houses" from Francis)
- Axe for cutting trees (Francis's idea)
