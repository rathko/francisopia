# Sprite & Animation Architecture

> How Francis-opia transitions from placeholder ColorRects to production pixel art,
> and how the visual system stays extensible as the game grows toward Steam release.

**Status:** Architecture spec (not yet implemented)
**Created:** 2026-03-28
**Art direction:** Ghibli-pixel blend (approved concept art in `/home/shared/`)

---

## Table of Contents

1. [Design Principles](#1-design-principles)
2. [Current State (What We're Replacing)](#2-current-state)
3. [Target Architecture](#3-target-architecture)
4. [Asset Pipeline (Aseprite to Godot)](#4-asset-pipeline)
5. [Animation System](#5-animation-system)
6. [Entity Visual Registry (Data-Driven)](#6-entity-visual-registry)
7. [World Tiles & Blocks](#7-world-tiles--blocks)
8. [Word Magic VFX](#8-word-magic-vfx)
9. [Learning-Optimized Visuals](#9-learning-optimized-visuals)
10. [Refactor Plan](#10-refactor-plan)
11. [File Structure](#11-file-structure)
12. [Steam & Localization Readiness](#12-steam--localization-readiness)
13. [Implementation Phases](#13-implementation-phases)

---

## 1. Design Principles

These govern every visual decision:

| Principle | Why | How |
|-----------|-----|-----|
| **Words are magic** | Core identity. Spelling creates reality. | Word magic VFX must be the most visually impressive thing in the game |
| **Readable at 7 inches** | Steam Deck handheld at 30cm | 32px+ characters, 48pt+ target words, high contrast |
| **Cute, not overwhelming** | 5-year-old audience | Soft round shapes, warm palette, no visual clutter |
| **Data-driven visuals** | New creatures without code changes | Entity visuals defined in Resource files, not GDScript |
| **Graceful degradation** | Art takes time to create | ColorRect fallback when sprites don't exist yet |
| **Letters are characters** | Kids memorize letter shapes | Floating letters have personality, animation, and consistent visual identity |

### Learning-Informed Visual Design

Research on early reading (ages 4-6) shows:

- **Multisensory reinforcement**: Seeing the word + hearing it + seeing the object appear strengthens memory
- **Consistent letter identity**: Each letter should look the same everywhere (floating, in UI slots, on signs)
- **Visual-semantic link**: When CAT is spelled, the cat should appear in a way that visually connects to the letters (e.g., letters dissolve into the cat shape)
- **Spaced repetition through gameplay**: Previously spelled words should reappear as environmental decorations, reinforcing recognition
- **High contrast for letter forms**: Dark letters on light backgrounds, generous spacing, one-story 'a' and 'g' (Sassoon Primary font)

---

## 2. Current State

### Visual Code Inventory

**279 `ColorRect.new()` calls across 8 files:**

| File | ColorRects | What They Draw |
|------|-----------|----------------|
| `MainScene.gd` | 49 | Trees, flowers, platforms, clouds, crystals, mushrooms, stairwell markers, bedrock, sky |
| `MagicSummon.gd` | 195 | All summoned entities (dog, cat, sun, bird, fish, house, sword, etc.) |
| `TerrainBlock.gd` | 7 | Block visual, border, treasure sparkle |
| `Pet.gd` | 19 | Dog and cat body parts (head, body, legs, tail, ears, eyes) |
| `BowWeapon.gd` | 5 | Bow and arrow visual |
| `PlayerController.gd` | 2 | Player visual adjustments |
| `HUDController.gd` | 1 | HUD element |
| `PauseMenu.gd` | 1 | Pause overlay |

**MainScene.gd is 1583 lines** with ~17 visual builder functions (`_add_tree`, `_add_flower`, `_add_platform`, etc.) totaling roughly 500 lines of pure visual code mixed into the chunk generator.

### Problems with Current Approach

1. **No animation**: Everything is static rectangles
2. **Visual code mixed with logic**: Can't change visuals without touching game systems
3. **No artist workflow**: Only a programmer can add visuals (by writing GDScript)
4. **Not Steam-ready**: ColorRect prototypes won't pass Steam review
5. **No visual consistency**: Each entity builds its own visual from scratch

---

## 3. Target Architecture

### Core Pattern: Scene Composition + Resource Registry

```
Entity (e.g., Dog)
  |
  +-- Scene file (Dog.tscn)           -- Node structure, collision, signals
  |     +-- AnimatedSprite2D           -- Loaded from SpriteFrames resource
  |     +-- CollisionShape2D           -- Physics
  |     +-- AnimationPlayer (optional) -- For syncing VFX/audio to frames
  |
  +-- SpriteFrames resource (.tres)    -- All animations for this entity
  |     +-- "idle" animation           -- Frames + timing
  |     +-- "walk" animation
  |     +-- "jump" animation
  |     +-- etc.
  |
  +-- EntityVisual resource (.tres)    -- Data-driven config
        +-- sprite_frames: SpriteFrames
        +-- default_animation: "idle"
        +-- scale: Vector2(1, 1)
        +-- color_palette: String       -- For palette swaps
```

### How Sprites Replace ColorRects

The existing ColorRect visual builders become "fallback" mode. Each visual function checks:

```gdscript
func _add_tree(chunk: Node2D, pos: Vector2) -> void:
    # Try to use sprite scene first
    var tree_scene = _try_load_scene("res://assets/sprites/world/Tree.tscn")
    if tree_scene:
        var tree = tree_scene.instantiate()
        tree.position = pos
        chunk.add_child(tree)
        return
    # Fallback: original ColorRect visual
    var tree := Node2D.new()
    # ... existing ColorRect code ...
```

This means:
- Art can be added incrementally (one entity at a time)
- Missing sprites don't crash the game
- Radek and Francis can play between art additions

---

## 4. Asset Pipeline (Aseprite to Godot)

### Recommended Workflow (Fully Automated, No Manual Art Tools)

```
AI generates sprite sheet PNG (API call)
    |
    | [PAI script slices into individual frames]
    v
Individual frame PNGs in assets/sprites/
    |
    | [PAI writes .tres SpriteFrames resource directly]
    v
SpriteFrames (.tres) with named animations + timing
    |
    | [Godot scene references the SpriteFrames]
    v
AnimatedSprite2D (in .tscn)
```

All sprite creation, slicing, and resource generation is done by PAI via CLI.
No manual art tools (Aseprite, Photoshop, etc.) are needed.
Radek reviews the output in-game and requests adjustments.

### Sprite Generation Pipeline

1. **AI generation**: GPT-image-1 API generates sprite sheet PNGs with specific frame layouts
2. **Frame slicing**: Python/ImageMagick script splits sheet into individual frame PNGs
3. **Resource creation**: PAI writes `.tres` SpriteFrames files (Godot text resource format)
4. **Scene wiring**: PAI creates/updates `.tscn` scene files with AnimatedSprite2D nodes

### Canvas Sizes

- 32x32 for characters (player, NPCs)
- 24x24 for small creatures (dog, cat, bird)
- 16x16 for items and UI elements (letters, coins)
- 32x32 for terrain tiles (grass, dirt, blocks)

### Godot Import Settings (CRITICAL for Pixel Art)

```
Project Settings:
  Rendering > Textures > Default Texture Filter = Nearest
  Display > Window > Stretch > Mode = viewport
  Display > Window > Stretch > Scale Mode = integer (Godot 4.3+)
  Rendering > 2D > Snap 2D Transforms to Pixel = On
  Rendering > 2D > Snap 2D Vertices to Pixel = On

Per-texture import (.import file):
  compress/mode = Lossless
  flags/repeat = disabled
  flags/filter = false (Nearest)
```

---

## 5. Animation System

### Player Character Animations

| Animation | Frames | FPS | Loop | Trigger |
|-----------|--------|-----|------|---------|
| `idle` | 4-6 | 6 | yes | Default when stationary |
| `walk` | 6-8 | 10 | yes | Horizontal velocity > 0 |
| `run` | 6-8 | 12 | yes | Horizontal velocity > threshold |
| `jump_up` | 2-3 | 8 | no | On jump, play once |
| `fall` | 2 | 8 | yes | Negative vertical velocity |
| `land` | 3 | 12 | no | On floor after falling |
| `dig` | 4 | 8 | no | On dig action |
| `celebrate` | 6-8 | 8 | no | On word completion |
| `wall_slide` | 2 | 6 | yes | Touching wall + falling |

**State machine (in GDScript, not AnimationTree):**

```gdscript
func _update_animation() -> void:
    if not is_on_floor():
        if velocity.y < 0:
            _play("jump_up")
        elif _touching_wall:
            _play("wall_slide")
        else:
            _play("fall")
    elif abs(velocity.x) > 10:
        _play("walk")
    else:
        _play("idle")
```

Why GDScript over AnimationTree: simpler to debug, fewer nodes, adequate for a 2D platformer with <15 states. AnimationTree is for 3D blend trees.

### Creature Animations

| Creature | Animations | Notes |
|----------|-----------|-------|
| Dog | idle, walk, run, sit, bark, wag_tail | Follow player, bark at letters |
| Cat | idle, walk, sit, stretch, pounce, purr | Follow owner, pounce at butterflies |
| Bird | idle, fly, land, sing | Circle above player |
| Fish | swim, jump, splash | In water areas only |

### Animation Principles (from Towerfall/Celeste research)

1. **Anticipation frame**: Brief opposite movement before action (squat before jump, pullback before dig)
2. **Impact hold**: Key action frame held 50% longer (150-200ms vs 80ms normal)
3. **Smear frame**: 1 frame of motion blur for fast actions (attack, jump apex)
4. **Sub-pixel animation**: Shift color values within pixel to suggest movement smaller than 1px
5. **Squash & stretch**: On land, on bounce, on collect letter

---

## 6. Entity Visual Registry (Data-Driven)

### Custom Resource: EntityVisual

```gdscript
# scripts/data/EntityVisual.gd
class_name EntityVisual
extends Resource

@export var display_name: String = ""
@export var sprite_frames: SpriteFrames = null
@export var default_animation: String = "idle"
@export var scale: Vector2 = Vector2(1, 1)
@export var offset: Vector2 = Vector2.ZERO
@export var has_shadow: bool = true
@export var shadow_scale: float = 1.0
# For creatures that follow the player
@export var follow_distance: float = 60.0
@export var follow_speed: float = 150.0
```

### How New Creatures Are Added

1. Artist creates `dog.aseprite` with animation tags
2. Aseprite Wizard auto-generates `dog_frames.tres`
3. Designer creates `dog_visual.tres` in Godot editor (no code):
   - Sets sprite_frames to dog_frames.tres
   - Sets default_animation to "idle"
   - Sets follow_distance to 50
4. Add entry to `data/creatures.json`: `{"dog": {"visual": "res://assets/visuals/dog_visual.tres", "type": "pet"}}`
5. MagicSummon registry references the creature ID: `{"dog": {"visual_id": "dog", ...}}`

**Zero code changes.** The generic creature scene loads the EntityVisual resource at runtime.

### Fallback Chain

```
1. Try: Load EntityVisual resource for this entity
2. Try: Load scene file (res://assets/sprites/{category}/{name}.tscn)
3. Fallback: Use existing ColorRect builder (current code)
```

---

## 7. World Tiles & Blocks

### Terrain Block Sprites

Current: `TerrainBlock.gd` builds visuals from 7 ColorRects (block + border + treasure sparkle).

Target: Each block type has a tile in a spritesheet.

| Block Type | Sprite Needed | Size | Variants |
|------------|--------------|------|----------|
| Grass (surface) | Top of ground with grass tufts | 32x32 | 3-4 random variants |
| Dirt (underground) | Brown earth with stone flecks | 32x32 | 3-4 random variants |
| Bedrock | Dark grey stone, unbreakable look | 32x32 | 2 variants |
| L2 surface | Twilight moss/alien grass | 32x32 | 3 variants |
| L2 dirt | Purple-grey underground | 32x32 | 3 variants |
| Stairwell stone | Grey stone blocks | 32x32 | 2 variants |

**Variant selection**: `variant_index = hash(chunk_index, gx, gy) % variant_count` -- deterministic, no RNG needed.

### Auto-Tiling (Future)

Godot 4 TileMap supports auto-tiling rules (connect edges based on neighbors). This is a future optimization for terrain. For now, individual block sprites with random variants are sufficient.

### Decorations (Trees, Flowers, Platforms)

Each becomes a prebuilt scene with AnimatedSprite2D:

| Decoration | Current | Target |
|------------|---------|--------|
| Tree | 3 ColorRects (trunk, canopy, variation) | Tree.tscn with idle sway animation, 3-4 tree variants |
| Flower | 1 ColorRect with random color | Flower.tscn with gentle bob animation, 5+ color variants |
| Platform | 2 ColorRects (base + grass) | Platform.tscn with mossy sprite, width scalable |
| Cloud | 1 ColorRect | Cloud.tscn with drift animation, 3 shapes |
| Crystal (L2) | 3 ColorRects (shard, side, glow) | Crystal.tscn with glow pulse animation |
| Mushroom (L2) | 4 ColorRects (stem, cap, dots) | Mushroom.tscn with gentle bounce, bioluminescent pulse |

---

## 8. Word Magic VFX

The visual centerpiece. When a word is spelled, the magic effect must be the most impressive thing in the game.

### Spell Completion Sequence

```
Phase 1: GATHER (0.3s)
  - All collected letter slots glow brighter
  - Camera slight zoom in
  - Background dims slightly (vignette)
  - Anticipation: player squats slightly

Phase 2: BURST (0.5s)
  - Letters fly from slots toward a point above the player
  - Golden sparkle trail from each letter
  - Letters merge in a flash of light
  - Screen shake (gentle, 2px)
  - Sound: ascending chime

Phase 3: MATERIALIZE (0.8s)
  - The summoned entity fades in from golden particles
  - Silhouette first, then color fills in
  - Radial burst of themed particles (green for tree, blue for water, etc.)
  - The word floats briefly above in golden text

Phase 4: LAND (0.3s)
  - Entity settles into final position with a soft bounce
  - Lingering sparkles fade over 1 second
  - Camera zooms back out
  - Celebration animation on player
```

### Implementation: GPUParticles2D + AnimationPlayer

- Each spell effect is a scene with a GPUParticles2D and an AnimationPlayer
- The AnimationPlayer drives the whole sequence (camera, particles, entity fade-in)
- Particle textures: soft circles, small stars, tiny sparkles (4x4 to 8x8 pixels)
- Color coding: Gold = magic, Green = nature, Blue = water, Purple = mystery

### Floating Letters VFX

Letters are characters in this game. They need personality:

| State | Visual | Animation |
|-------|--------|-----------|
| Floating (uncollected) | Soft golden glow halo | Gentle sine-wave bob + slow rotation |
| Needed next | Brighter glow, subtle pulse | Slightly faster bob, sparkle trail |
| Collected | Fly toward UI slot | Stretch in direction of travel, shrink on arrival |
| Wrong letter | Brief red tint + bounce away | Squash on contact, stretch on bounce |
| Word complete | All slots burst into entity | See spell completion sequence above |

---

## 9. Learning-Optimized Visuals

### How Visuals Reinforce Reading

| Learning Goal | Visual Strategy | Implementation |
|---------------|----------------|----------------|
| **Letter recognition** | Each letter has consistent visual identity everywhere | Single font/style for all letters: floating, UI, signs, decorations |
| **Word-object association** | Spelled word visually transforms into object | Materialize phase: letters dissolve into entity shape |
| **Phonics reinforcement** | Letters play sounds when collected | Audio cue on AnimatedSprite2D `frame_changed` signal |
| **Spaced repetition** | Previously learned words appear in world | Completed words show as golden plaques on scenery |
| **Visual memory** | Object + word shown together | Summoned entities have their word floating above briefly |
| **Progress visibility** | Trophy wall, word collection album | Castle interior scene with word plaques |
| **Motivation** | Celebration is rewarding | Full spell completion VFX sequence (most impressive moment) |

### Font for In-Game Text

**Primary**: **Andika** (SIL International, free, SIL OFL license)
- Designed specifically for literacy and beginning readers
- Single-story 'a' and 'g' (matches how children learn to write)
- Clear b/d/p/q differentiation (critical for ages 4-6, these are the most confused letters)
- Open shapes, generous spacing, high x-height
- Free for commercial use (Steam release compatible)
- Available on Google Fonts

**Why not Sassoon Primary**: Despite being the UK school standard, Wilkins et al. (2009) found it 43% slower than Verdana in visual search tasks. Convention, not evidence.
**Why not OpenDyslexic**: Multiple studies (Wery 2017, Kuster 2018) found NO benefit. Some found it slower than Arial.
**Why not Lexend**: Promising fluency data but uses double-story 'a', less suitable for beginning writers.

**Fallback**: Fredoka One (current font, round and friendly)

**Floating letter font**: Same Andika but rendered as sprites for animation (each letter is a small spritesheet with idle, glow, collected states). This ensures letter shapes are IDENTICAL everywhere the child sees them.

---

## 10. Refactor Plan

### Phase 1: Extract Visual Builders from MainScene.gd

**Goal**: Move all `_add_*` visual functions to dedicated scene files without changing behavior.

| Current Function | Lines | Extract To | Method |
|-----------------|-------|------------|--------|
| `_add_tree` | 18 | `scenes/world/decorations/Tree.tscn` | Scene with script |
| `_add_flower` | 11 | `scenes/world/decorations/Flower.tscn` | Scene with script |
| `_add_platform` | 15 | `scenes/world/Platform.tscn` | Already a scene-worthy entity |
| `_add_l2_platform` | 17 | `scenes/world/L2Platform.tscn` | Separate L2 variant |
| `_add_l2_mushroom` | 20 | `scenes/world/decorations/Mushroom.tscn` | Scene with script |
| `_add_l2_tree` | 18 | `scenes/world/decorations/GlowTree.tscn` | Scene with script |
| `_add_l2_crystal` | 18 | `scenes/world/decorations/Crystal.tscn` | Scene with script |
| `_add_archery_target` | 30 | `scenes/world/ArcheryTarget.tscn` | Already has a script |
| `_add_stairwell_marker` | 45 | `scenes/world/StairwellMarker.tscn` | Scene with script |
| `_spawn_surface_chest` | 30 | Already uses `TreasureChest.gd` | Keep, add sprite later |
| `_add_bedrock_segment` | 12 | Keep inline (simple static body) | Too simple to extract |
| `_add_stair_block` | 15 | Keep inline (simple static body) | Too simple to extract |
| `_add_teleport_pad` | 40 | `scenes/world/TeleportPad.tscn` | Scene with script |

**Estimated reduction**: MainScene.gd drops from ~1583 to ~1100 lines.

### Phase 2: Add Sprite Support to Extracted Scenes

Each extracted scene gets a `_setup_visual()` function:

```gdscript
func _setup_visual() -> void:
    var sprite_path := "res://assets/sprites/world/tree.tscn"
    if ResourceLoader.exists(sprite_path):
        var sprite_scene = load(sprite_path)
        var sprite = sprite_scene.instantiate()
        add_child(sprite)
    else:
        _build_colorect_fallback()

func _build_colorect_fallback() -> void:
    # Original ColorRect code moved here
```

### Phase 3: Replace MagicSummon Visual Builders

`MagicSummon.gd` has 195 ColorRect calls across ~20 `_summon_*` functions. These become:

```gdscript
func _summon_generic(scene: Node2D, player: Node2D, pos: Vector2, entity_id: String) -> Node:
    var visual_path := "res://assets/visuals/%s_visual.tres" % entity_id
    if ResourceLoader.exists(visual_path):
        var visual: EntityVisual = load(visual_path)
        return _create_from_visual(visual, scene, player, pos)
    # Fallback to hardcoded builder
    var builder_name := "_summon_%s" % entity_id
    if has_method(builder_name):
        return call(builder_name, scene, player, pos)
    return null
```

### Phase 4: Player & Pet Sprite Integration

Replace PlayerController.gd and Pet.gd ColorRect visuals with AnimatedSprite2D.

---

## 11. File Structure

```
assets/
  sprites/
    player/
      explorer.aseprite          # Source file (32x32, tagged animations)
      explorer_frames.tres       # Auto-generated by Aseprite Wizard
    creatures/
      dog.aseprite
      dog_frames.tres
      cat.aseprite
      cat_frames.tres
      bird.aseprite
      bird_frames.tres
    world/
      terrain_tiles.aseprite     # 32x32 tile sheet (grass, dirt, bedrock, L2)
      terrain_tiles.tres
      tree.aseprite              # Decorative tree with sway animation
      tree_frames.tres
      flower.aseprite            # 5 color variants
      flower_frames.tres
      crystal.aseprite           # Glow pulse animation
      mushroom.aseprite          # Bounce + bioluminescence
      cloud.aseprite             # 3 cloud shapes
    ui/
      letter_sprites.aseprite    # A-Z, each with idle/glow/collected states
      letter_frames.tres
      hud_elements.aseprite      # Coin icon, heart, slot frame
    vfx/
      sparkle.aseprite           # 4x4 sparkle particle
      magic_burst.aseprite       # Radial burst for spell completion
      glow_orb.aseprite          # Soft glow for letters
  visuals/                        # EntityVisual .tres resources
    dog_visual.tres
    cat_visual.tres
    bird_visual.tres
    explorer_visual.tres
  fonts/
    SassoonPrimary-Regular.ttf    # Primary reading font
    FredokaOne-Regular.ttf        # Fallback (current)
```

---

## 12. Steam & Localization Readiness

### Steam Requirements

- **Store page assets**: Capsule images (header 460x215, hero 3840x1240, etc.)
- **Achievements**: Use Godot's Steamworks GDExtension or GodotSteam
- **Controller support**: Already done (gamepad + keyboard)
- **Resolution**: Already targets 1280x800 with upscale to 1080p

### Localization

- All in-game text already uses the font system (will use Sassoon Primary)
- Word bank is data-driven (JSON/Resource), language packs are just new word files
- Future: `data/words_fr.json`, `data/words_lv.json`, etc.
- Letter sprites: Latin alphabet covers English, French, Latvian, Spanish, German
- UI text: Use Godot's built-in Translation system (CSV or PO files)

### Accessibility

- Font size already meets 32pt minimum
- Color coding uses both color AND shape (don't rely on color alone)
- Audio cues accompany all visual feedback
- Future: high-contrast mode, dyslexia-friendly font toggle

---

## 13. Implementation Phases

### Phase 1: Foundation (Next Session)
**Goal**: Extract visual code, set up asset pipeline, no new art yet.
- Extract decoration builders into scene files
- Install Aseprite Wizard plugin
- Set up Godot import settings for pixel art
- Create EntityVisual resource class
- Verify game still works identically (ColorRect fallback)

### Phase 2: Player Character
**Goal**: First real sprite in the game. Biggest visual impact.
- Create explorer character in Aseprite (32x32, 8 animation tags)
- Import via Aseprite Wizard
- Replace PlayerController visual with AnimatedSprite2D
- Implement animation state machine
- Add anticipation/impact frames

### Phase 3: Companions
**Goal**: Dog and cat become animated creatures.
- Create dog and cat sprites (24x24, 5 animation tags each)
- Replace Pet.gd ColorRects with AnimatedSprite2D
- Add follow behavior animation transitions

### Phase 4: World Decorations
**Goal**: Trees, flowers, crystals become sprites.
- Create decoration spritesheets
- Replace extracted scene visuals
- Add idle animations (tree sway, flower bob, crystal pulse)

### Phase 5: Terrain Tiles
**Goal**: Block grid becomes visually rich.
- Create terrain tile sheet (grass, dirt, bedrock variants)
- Modify TerrainBlock.gd to use Sprite2D
- Add variant selection based on position hash

### Phase 6: Word Magic VFX
**Goal**: Spell completion becomes visually stunning.
- Create particle textures (sparkles, bursts, glow orbs)
- Build spell completion sequence scene
- Replace MagicSummon visual builders
- Add camera zoom and screen shake

### Phase 7: UI Polish
**Goal**: Letter slots, HUD, and menus get pixel art treatment.
- Create letter sprites (A-Z with animation states)
- Create HUD sprite elements
- Replace UI ColorRects
- Add Sassoon Primary font

### Phase 8: Steam Release Prep
**Goal**: Store assets, achievements, final polish.
- Create Steam capsule images
- Implement achievements via GodotSteam
- Final accessibility pass
- Localization framework setup

---

## References

- [Aseprite Wizard plugin](https://godotengine.org/asset-library/asset/713)
- [Chevy Ray's Crunch (Celeste texture packer)](https://github.com/ChevyRay/crunch)
- [Pedro Medeiros pixel art tutorials (TowerFall artist)](https://saint11.art/blog/pixel-art-tutorials/)
- [Godot 4 pixel art settings guide](https://docs.godotengine.org/en/stable/tutorials/rendering/pixel_art.html)
- Francis-opia concept art: `/home/shared/` (images 01-10)
- Research findings: `~/.claude/History/research/2026-03/2026-03-28_godot4-sprite-animation-systems/`
- Learning design research: `~/.claude/History/research/2026-03/2026-03-28_visual-design-childrens-educational-games/`
