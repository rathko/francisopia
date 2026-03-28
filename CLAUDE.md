# Francis-opia - Claude Code Instructions

## Project Overview

Godot 4.6 educational platformer game. GDScript only, no external dependencies. Target: Steam Deck (Linux x86_64, 1280x800, GL Compatibility renderer).

## Engineering Process (VSDD)

All development MUST follow VSDD (Verified Spec-Driven Development) best practices:
1. **Spec before code.** Define what the feature does before implementing it. For non-trivial changes, write the test first.
2. **Tests before implementation.** New features and bug fixes must have corresponding unit tests. Update existing tests when behavior changes. No excuses.
3. **Run the game.** After any change, run `godot --path ~/src/pai/francisopia` and confirm no SCRIPT ERROR lines in output. Parse errors = broken game = not done.
4. **Run the tests.** After any change, run `godot --headless --path . --script tests/run_tests.gd` and confirm all pass. Failing tests = not done.
5. **Verify before declaring done.** Never claim a feature works without evidence. Launch the game, test the feature, check for errors.

## Critical Rules

### GDScript Type Safety (Godot 4.6)
- **Never use `:=` type inference with expressions that return Variant.** The `%` (modulo), `abs()` on mixed types, and dictionary lookups return Variant in Godot 4.6. Always use explicit type annotations: `var x: int = expr` instead of `var x := expr`.
- Test scripts parse before committing: `godot --headless --path . --check-only` (or just launch and check for SCRIPT ERROR in console output).

### Collision Layer Discipline
- All terrain StaticBody2D nodes MUST explicitly set `collision_layer = 1` and `collision_mask = 0`. Do not rely on defaults.
- Player CharacterBody2D: layer=1, mask=1 (defaults in Player.tscn)
- Letters (Area2D): layer=2, mask=0
- Chests: layer=4
- Archery targets: layer=8
- Letter Thieves: layer=16, mask=1
- Pets: layer=0, mask=1

### Scene File Integrity
- `load_steps` in .tscn files must equal `ext_resources + sub_resources + 1`. Godot tolerates mismatches but keep it correct.
- When adding ext_resources to a .tscn, always update `load_steps`.

### Terrain Block Hierarchy
- Terrain blocks are direct children of `chunk` Node2D (not nested under intermediate containers). This ensures physics registration works reliably in Godot 4.6.
- The `terrain_container` Node2D still exists in chunks but is used only for organizational purposes, not as a parent for physics bodies.

### Save System
- Atomic writes: always write to `.tmp` then rename. Never write directly to `save.json`.
- GameManager handles all persistence. Other systems emit signals, GameManager saves.
- Never store player world position in saves (procedural world makes it meaningless).

## Architecture Quick Reference

### Autoloads (process order)
Events -> GameManager -> WordEngine -> AudioManager -> InputHelper -> QuestGenerator -> MagicSummon

### Key Constants (MainScene.gd)
- CHUNK_WIDTH: 1280px
- MAX_CHUNKS: 7 active
- GROUND_Y: 725.0 (top of grass row)
- BLOCK_SIZE: 32px
- STAIRWELL_WIDTH: 4 blocks (outer 2 are walls, inner 2 are traversable)
- L2_SKY_HEIGHT: 300px (open sky space above Level 2 ground)
- Player starts at (400, 700) in Main.tscn

### Level 2 Architecture
- Level 2 is a full world below bedrock, not a cave. Has sky (twilight), ground, trees, underground.
- Stairwell connects L1 to L2 with indestructible stone walls and zigzag platforms.
- Stairwell blocks have NO `dig()` method, making them permanently solid.
- Level 2 decorations: glowing mushrooms, bioluminescent trees, floating platforms.
- Level 2 ground is mossy stone (green-tinted) with darker underground stone below.

### Signal Bus Pattern
Cross-system communication goes through Events autoload or direct signals on source nodes. Never create hard references between unrelated systems.

### Word Engine Flow
1. `select_word_for_area()` picks a word at current difficulty
2. Letters spawn from treasure chests (not floating in world)
3. Player collects via Interact button, `try_collect_letter()` validates
4. `word_spelled_correctly` signal triggers summoning + rewards

## Testing

### Running tests (from Claude user)
```bash
XDG_DATA_HOME="/tmp/claude-1001/godot_xdg" xvfb-run --auto-servernum --server-args="-screen 0 1280x800x24" godot --rendering-driver opengl3 --headless --path /home/claude/src/pai/francisopia --script tests/run_tests.gd
```
Godot crashes with signal 11 without `xvfb-run` and `XDG_DATA_HOME` in the Claude sandbox. This command works reliably.

### Running tests (from Radek)
```bash
godot --headless --path ~/src/pai/francisopia --script tests/run_tests.gd
```

5 test files: test_game_manager.gd, test_word_engine.gd, test_magic_summon.gd, test_quest_generator.gd, test_terrain_height.gd. No external test framework needed. ~130 test cases total.

### Visual smoke test (from Claude user, requires xdotool)
```bash
# Start game on virtual display, take screenshot, send inputs, verify
export DISPLAY=:99
Xvfb :99 -screen 0 1280x800x24 &
XDG_DATA_HOME="/tmp/claude-1001/godot_xdg" godot --rendering-driver opengl3 --path /home/claude/src/pai/francisopia &
sleep 4
import -window root /tmp/claude-1001/game_screenshot.png  # Take screenshot
xdotool key d d d space  # Move right + jump
sleep 2
import -window root /tmp/claude-1001/game_after_input.png
kill %2  # Stop game
kill %1  # Stop Xvfb
```
Requires: xdotool (install via `ans eos-install.yml`; listed under Game Development packages)

## Common Pitfalls

1. **Adding blocks to wrong parent** - Physics bodies must be direct children of chunk, not nested under Node2D containers
2. **GDScript Variant inference** - Godot 4.6 is strict about `:=` inference. When in doubt, use explicit types
3. **Stairwell at chunk 0** - The hash function deterministically places a stairwell in chunk 0. This is by design, not a bug
4. **Letters come from chests only** - LetterSpawner exists but letters spawn from TreasureChest.dig(), not floating in the world
5. **Pet collision** - Pets have layer=0 so they don't push the player. They only collide with terrain (mask=1)

## File Ownership

This project lives at `/home/radek/src/pai/francisopia`. Files are owned by the `claude` user with group write access. Radek runs the game from his session; Claude Code edits from its session.
