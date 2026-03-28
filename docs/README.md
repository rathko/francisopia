# Francis-opia Documentation

> A cozy reading adventure where words have magical power. Built for a 5-year-old learning to read.

Each doc describes **what the code currently does** (verifiable against source), known issues, and planned future work.

## Domain Docs

| Doc | Covers | Key Files |
|-----|--------|-----------|
| [spelling.md](spelling.md) | Word engine, letter collection, difficulty progression | `WordEngine.gd`, `FloatingLetter.gd`, `LetterSpawner.gd` |
| [magic.md](magic.md) | Summon system, word-to-entity registry, animations | `MagicSummon.gd` |
| [terrain.md](terrain.md) | Block-based terrain, digging, treasure chests | `TerrainBlock.gd`, `TreasureChest.gd`, `MainScene.gd` |
| [player.md](player.md) | Movement, wall mechanics, multiplayer, weapon system, bow | `PlayerController.gd`, `WeaponHolder.gd`, `BowWeapon.gd`, `Arrow.gd` |
| [pets.md](pets.md) | Pet companions, follow behavior, visual design | `Pet.gd` |
| [quests.md](quests.md) | Quest generation, tracking, completion | `QuestGenerator.gd`, `QuestScrollController.gd` |
| [ui.md](ui.md) | HUD, pause menu, quest scroll | `HUDController.gd`, `PauseMenu.gd` |
| [world.md](world.md) | Chunk generation, decorations, platforms | `MainScene.gd`, `WorldGenerator.gd` |
| [audio.md](audio.md) | Audio manager, sound pools, music | `AudioManager.gd` |
| [save.md](save.md) | Persistence, game state, save/load | `GameManager.gd` |
| [controls.md](controls.md) | Input mapping, keyboard/gamepad, multiplayer input | `InputHelper.gd`, `project.godot` |
| [words.md](words.md) | Word bank data, phonics, difficulty levels | `data/words.json` |

## Testing

### Unit Tests

Tests use a lightweight assert-based runner (no plugin required):

```bash
godot --path . --headless --script tests/run_tests.gd
```

See `tests/` for test files. Each tests a specific autoload or system.

### Visual Smoke Test

Launches the game, sends keyboard input (move, jump), takes screenshots, verifies the game doesn't crash. See [testing.md](testing.md) for full setup details.

```bash
./tests/smoke_test.sh                # Auto-detect display
./tests/smoke_test.sh --xvfb         # Xvfb (requires nvidia <= 590)
./tests/smoke_test.sh --display :1   # Use Radek's display directly
```

## Architecture

- **Autoloads** (load order): Events > GameManager > WordEngine > AudioManager > InputHelper > QuestGenerator > MagicSummon
- **Signal flow**: WordEngine emits events > HUD, MagicSummon, LetterSpawner listen
- **Scene tree**: Main > Player + Camera, LetterSpawner, HUD, QuestScroll, PauseMenu
- **Rendering**: Godot 4.2, GL Compatibility, 1280x800 (Steam Deck native)
