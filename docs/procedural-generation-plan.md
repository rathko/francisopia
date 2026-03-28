# Procedural Generation Plan

Implementation plan for biomes, terrain hills, world seeds, and auto-generated items.

## Current State

- `WorldGenerator.gd` has basic seed + RNG, platform/decoration placement, weather, wonder events
- Terrain is flat: 40 cols x 9 rows of 32px blocks per chunk, all identical meadow
- No biome variation, no height variation, no seed persistence or display
- `MagicSummon.gd` has ~20 hardcoded word builders, no fallback for unknown words
- Chunk system: 1280px wide, 7 active, infinite left/right

## Phase 1: World Seed (Foundation)

Everything depends on deterministic seeding. Do this first.

### 1.1 Store seed in GameManager save data
- `GameManager.gd` already handles saves. Add `world_seed: int` to save dict
- On new game: generate random seed via `randi()`
- On load: restore seed from save data
- Pass seed to `WorldGenerator.initialize(seed)` on game start

### 1.2 Display seed on HUD
- `HUDController.gd` manages the HUD. Add a small label (bottom-right or pause menu)
- Format: `Seed: 12345678` (human-readable int)
- Only needs to be visible, not prominent (kids won't care, parents might)

### 1.3 Seed input
- Add seed field to start screen or settings menu
- Empty field = random seed, entered value = deterministic replay
- Validate: integer only, clamp to reasonable range

### 1.4 Deterministic generation
- Currently `MainScene.gd` generates chunks with inline `randi()` calls
- Refactor: all per-chunk randomness must flow through `WorldGenerator._rng`
- Per-chunk RNG: seed each chunk as `_seed + chunk_index` so chunks generate identically regardless of visit order
- Test: same seed produces same platform positions, tree count, decoration layout

### Files to modify
- `scripts/autoload/GameManager.gd` (save/load seed)
- `scenes/world/WorldGenerator.gd` (per-chunk seeding)
- `scenes/ui/HUDController.gd` (seed display)
- `scenes/main/MainScene.gd` (wire seed through chunk generation)

## Phase 2: Biomes

Biggest visual payoff. Each chunk belongs to a biome determined by seed + chunk index.

### 2.1 Biome function
- Add `get_biome(chunk_index: int) -> String` to `WorldGenerator.gd`
- Use seeded noise or simple hash: `(seed + chunk_index * 7919) % biome_count`
- Smooth transitions: biome changes every 3-5 chunks (not every chunk)
- Approach: divide world into "biome regions" of 3-5 chunk width

### 2.2 Biome definitions (at least 4)

| Biome | Sky Color | Ground | Dirt | Trees | Flowers | Special |
|-------|-----------|--------|------|-------|---------|---------|
| Meadow | Light blue | Green grass | Brown | Oak-style, green canopy | Mixed colors | Current default |
| Desert | Pale yellow | Sandy tan | Dark sand | Cacti (tall rectangles) | None / rare | Tumbleweeds |
| Snow | Grey-white | White | Light grey | Pine-style (triangles) | Ice crystals | Snowflakes |
| Forest | Dark green-blue | Dark green | Dark brown | Tall dense trees | Mushrooms | Fireflies |

Store as a dictionary in WorldGenerator or a separate `BiomeData.gd` resource.

### 2.3 Apply biome to chunk generation
- Sky ColorRect color from biome palette
- Grass row block color from biome
- Dirt row block colors from biome (with per-block variation)
- Tree generation: shape/color/density from biome
- Flower generation: type/density from biome
- Cloud opacity/color from biome

### 2.4 Biome transitions
- Risk: hard color cut between chunks looks bad
- Solution: transition chunks blend two biome palettes (lerp colors)
- Keep it simple: if chunk is at biome boundary, mix 50/50 with neighbor biome

### Files to modify
- `scenes/world/WorldGenerator.gd` (biome function, biome data)
- `scenes/main/MainScene.gd` (pass biome to chunk generation, color blocks/sky)
- `scenes/world/TerrainBlock.gd` (accept color parameter instead of hardcoded green/brown)

## Phase 3: Terrain Hills

Adds visual interest but has the highest risk of breaking digging and block alignment.

### 3.1 Height function
- `get_terrain_height(chunk_index: int, column: int) -> int`
- Returns number of blocks to offset vertically for that column
- Use sine wave: `sin((chunk_index * 40 + column) * 0.1) * 2` gives gentle +/-2 block hills
- Seed the phase offset: `sin(... + seed * 0.001)`
- Keep amplitude small (1-3 blocks) so kids can still walk/jump across

### 3.2 Apply height to block grid
- Currently: grass at GROUND_Y (725px), 8 dirt rows below
- With hills: grass row y-position varies per column by height offset
- Dirt rows below each grass block shift accordingly
- Bedrock stays flat at the bottom (anchor point)

### 3.3 Digging compatibility
- `MainScene.gd` finds blocks by snapping cursor to 32px grid
- Block positions will vary per column now, but grid snapping still works because blocks are still on 32px grid, just at different y-offsets
- Test thoroughly: dig at hill peaks, valleys, and slopes
- Potential issue: player walking across hills needs ground detection to follow terrain surface

### 3.4 Player ground detection
- Currently player stands at GROUND_Y
- With hills: ground level varies per column
- Option A: keep existing collision (blocks are StaticBody2D, player lands on them naturally)
- Option B: query terrain height at player x-position for spawn/respawn
- Option A should work since blocks already have collision. Test first.

### Files to modify
- `scenes/world/WorldGenerator.gd` (height function)
- `scenes/main/MainScene.gd` (use height when placing blocks)
- Possibly `scenes/player/PlayerController.gd` (if ground detection needs adjustment)

## Phase 4: Auto-Generator for Unknown Words

When a player spells a word that has no hardcoded builder in MagicSummon, generate a visual item from word properties.

### 4.1 Fallback in MagicSummon
- `MagicSummon.gd` currently has `_word_builders` dictionary mapping words to functions
- Add fallback: if word not in `_word_builders`, call `_auto_generate(word)`
- Auto-generate creates a simple visual item from word hash

### 4.2 Auto-generation algorithm
- Hash the word string to get deterministic properties:
  - Color hue from `word.hash() % 360`
  - Size from word length (longer words = bigger items)
  - Shape: simple geometric (circle, square, star, diamond) from `word.hash() / 360 % 4`
  - Label: the word itself displayed on/near the item
- Keep it simple. A colored shape with the word written on it is better than nothing.
- Same word always produces same item (deterministic from word string, no seed needed)

### 4.3 Persistence
- Auto-generated items need to save/load like hardcoded ones
- Store in save data: `{ "word": "elephant", "position": Vector2(...), "auto_generated": true }`
- On load: re-generate visual from word (deterministic, so no need to store visual properties)

### 4.4 Save format versioning
- Add `save_version: int` to save data root
- Current implicit format = version 1
- New format with seed + auto-generated items = version 2
- On load: check version, migrate if needed (v1 saves get a random seed assigned)
- Forward compatible: unknown keys are ignored

### Files to modify
- `scripts/autoload/MagicSummon.gd` (fallback generator)
- `scripts/autoload/GameManager.gd` (save versioning, auto-generated item persistence)

## Implementation Order

```
Phase 1 (seed)  ->  Phase 2 (biomes)  ->  Phase 3 (hills)  ->  Phase 4 (auto-gen)
   [2-3 hrs]           [3-4 hrs]            [2-3 hrs]            [2-3 hrs]
```

Phase 1 is prerequisite for 2 and 3. Phase 4 is independent but benefits from save versioning in Phase 1.

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Hills break digging | Medium | Blocks are StaticBody2D with collision; grid snap should still work. Test early. |
| Biome transitions look jarring | Low | Color lerp at boundaries. Keep palettes in same value range. |
| Auto-generated items look bad | Low | Simple shapes with word labels. Better than "word not found" error. |
| Save migration breaks existing saves | Medium | Version field + explicit migration path. Test with real save files. |
| Per-chunk seeding produces patterns | Low | Use prime multiplier in hash. Visual inspection during testing. |
| Terrain height breaks platform/tree placement | Medium | Place platforms and trees relative to local terrain height, not GROUND_Y. |

## Testing Checklist

- [ ] Same seed produces identical world on two fresh starts
- [ ] Existing saves load without error after changes
- [ ] Digging works on hill peaks, valleys, and slopes
- [ ] All 4 biomes visually distinct
- [ ] Biome transition chunks don't have hard color seams
- [ ] Auto-generated item for "elephant" looks the same every time
- [ ] Auto-generated items survive save/load cycle
- [ ] Seed displayed on HUD matches saved seed
- [ ] Entering a seed on start screen reproduces expected world
