# Francis-opia - Claude Code Instructions

## Project Overview

Godot 4.6 educational platformer game. GDScript only, no external dependencies. Target: Steam Deck (Linux x86_64, 1280x800, GL Compatibility renderer).

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
- Player starts at (400, 700) in Main.tscn

### Signal Bus Pattern
Cross-system communication goes through Events autoload or direct signals on source nodes. Never create hard references between unrelated systems.

### Word Engine Flow
1. `select_word_for_area()` picks a word at current difficulty
2. Letters spawn from treasure chests (not floating in world)
3. Player collects via Interact button, `try_collect_letter()` validates
4. `word_spelled_correctly` signal triggers summoning + rewards

## Testing

```bash
godot --headless --path . --script tests/run_tests.gd
```

4 test files: test_game_manager.gd, test_word_engine.gd, test_magic_summon.gd, test_quest_generator.gd. No external test framework needed.

## Common Pitfalls

1. **Adding blocks to wrong parent** - Physics bodies must be direct children of chunk, not nested under Node2D containers
2. **GDScript Variant inference** - Godot 4.6 is strict about `:=` inference. When in doubt, use explicit types
3. **Stairwell at chunk 0** - The hash function deterministically places a stairwell in chunk 0. This is by design, not a bug
4. **Letters come from chests only** - LetterSpawner exists but letters spawn from TreasureChest.dig(), not floating in the world
5. **Pet collision** - Pets have layer=0 so they don't push the player. They only collide with terrain (mask=1)

## File Ownership

This project lives at `/home/radek/src/pai/francisopia`. Files are owned by the `claude` user with group write access. Radek runs the game from his session; Claude Code edits from its session.
