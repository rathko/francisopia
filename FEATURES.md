# Francis-opia Features

> A cozy reading adventure where words have magical power. Built for a 5-year-old learning to read.

**Art status:** All visuals are placeholder ColorRect rectangles. No sprites, textures, or final art yet.

## Core Gameplay

### Word Spelling
- A target word is shown on the HUD (e.g., "CAT")
- Letters float in the world near the player with sine-wave bobbing animation
- **Needed letters** glow golden, are larger (font 64), pulse with scale animation, and have a background glow
- **Distractor letters** are smaller (font 36) and faded
- Walk into letters in sequence to spell the word (C, then A, then T)
- HUD shows underscore slots that fill as you collect letters
- Celebration animation plays when word is complete
- Coins awarded based on word length (1-3 coins)
- Difficulty progression: CVC words -> blends -> longer words, unlocked by total words completed (10/25/40/60 thresholds)

### Word Bank
- JSON word bank (`data/words.json`) with word, level, area, and image fields
- Built-in fallback words if JSON missing or corrupt
- 17 words across 5 difficulty levels and multiple areas (meadow, castle, beach, forest, mountain)
- Random word selection within difficulty-appropriate candidates

## Movement and Physics

### Player Controller
- Smooth platformer movement (200 px/s)
- Variable jump height — release Space/A early for short hops, hold for full height
- Coyote time (0.15s) — still jump briefly after walking off a ledge
- Jump buffering (0.1s) — press jump just before landing and it registers
- Fall speed capped at 600 px/s
- Sprite flips based on facing direction

### Respawn
- Fall below Y=900 and respawn at last safe ground position
- Velocity resets on respawn

## World

### Infinite Procedural World
- Chunk-based generation (1280px wide chunks, 7 active at once)
- Chunks generate/recycle as player walks left or right — infinite in both directions
- Each chunk contains:
  - Ground with grass layer + dirt layer
  - Sky background
  - 1-3 random floating platforms at varying heights
  - 1-3 random trees (variable trunk height, canopy size, color variation)
  - 2-5 random flowers (5 color varieties)
  - 1-2 random clouds (varying opacity and size)
  - 20% chance of an archery target

### Digging
- Press Q (keyboard) or LB (gamepad) while on the ground to dig
- Creates an underground chamber (300px wide, 200px deep) with:
  - Dark dirt background with random stone texture patches
  - Walls on both sides to contain the chamber
  - Floor at the bottom
  - A step platform inside for climbing back out
  - 80% chance of a treasure chest

### Treasure Chests
- Found underground after digging
- Press E (keyboard) or X (gamepad) to open
- Awards 3-5 coins randomly
- Opening animation: lid flies up and fades, chest body dims
- Floating "+N" coin text rises and fades
- Can only be opened once

## Combat and Interaction

### Archery
- Click (mouse) or RT (gamepad) to shoot arrows
- Keyboard aim: arrows fly toward mouse cursor (with camera offset calculation)
- Gamepad aim: arrows fly in facing direction
- Arrows stick into surfaces on contact
- Arrows call `hit_by_arrow()` on anything they hit

### Archery Targets
- Standing wooden targets with red ring and white center
- Spin/shrink animation when hit, then reform
- Appear randomly in the world (20% per chunk)

### Letter Thieves (Silly Monsters)
- Cute purple blob creatures that appear when you touch a wrong letter
- Maximum 3 active at once
- Spawn off-screen (700px away) near ground level
- Move slowly (30 px/s) toward the nearest needed letter
- Wobble animation while walking
- Can be scared away by:
  - **Stomping** — jump on top of them (player bounces)
  - **Shooting** — hit with an arrow
- Scare animation: jump up, spin, shrink, vanish
- If they reach a letter, they steal it (letter disappears)

## UI

### HUD
- Target word display with hint text
- Letter slots (underscores that fill with collected letters)
- Coin counter with coin icon
- Celebration text animation on word completion

### Quest Scroll
- Toggle with Tab (keyboard) or Y (gamepad)
- Slide-in panel from the right side
- Shows active quests with descriptions
- Completed quests show strikethrough text
- Quest types: spell words, explore areas, training challenges, shop visits, action quests

## Systems

### Save/Load
- Auto-saves on area changes
- Saves to `user://save.json`
- Persists: player name, planet name, coins, words completed, quests completed, current area, items owned
- Loads on game start if save exists

### Input System
- Unified input abstraction (InputHelper autoload)
- Auto-detects keyboard vs gamepad and switches seamlessly
- Emits signal on input device change

### Quest Generator
- Template-based quest generation by area
- Quest types: spell, explore, training, shop, action
- Generates 3 quests per area on entry

### Autoload Singletons
- **GameManager** — global state, save/load, coins, progression
- **WordEngine** — word selection, letter validation, difficulty
- **AudioManager** — audio management (placeholder, no sounds yet)
- **InputHelper** — unified keyboard/gamepad input
- **QuestGenerator** — quest template system

## What's Not Done Yet

- No sprites or real art (everything is colored rectangles)
- No sound effects or music
- No character selection or customization
- No shop system
- No area transitions (castle, beach, forest, mountain)
- No NPC characters
- No story or narrative sequences
- No particle effects
- No title screen or menus
- No pause menu functionality (input mapped but no UI)
