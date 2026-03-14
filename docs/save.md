# Save System

JSON-based persistence.

## Current State

### Game Manager (`GameManager.gd`)
- Save path: `user://save.json`
- Auto-saves on area transitions
- Single save slot per planet

### Saved Fields
| Field | Type | Description |
|-------|------|-------------|
| `player_name` | String | Player's chosen name |
| `planet_name` | String | World name ("Francis-opia" default) |
| `castle_style` | String | Castle customization choice |
| `character_index` | int | Selected character |
| `word_coins` | int | Total coins earned |
| `words_completed` | Array[String] | All words ever spelled |
| `quests_completed` | Array[String] | All quest IDs completed |
| `items_owned` | Array[String] | Items in inventory |
| `words_summoned` | Array[String] | Words that triggered summons |
| `current_area` | String | Last area visited |

### Coin Economy
- 3-letter word: 1 coin
- 4-letter word: 2 coins
- 5+ letter word: 3 coins
- Treasure chest: 3-5 coins

### Load Behavior
- On startup, `GameManager.load_game()` checks for save file
- If found: restores all fields, prints "Save loaded!"
- If missing: starts fresh with defaults

## Known Issues

- No save versioning — format changes could corrupt old saves
- Summoned entities not saved (pets, world objects lost on restart)
- No backup save mechanism
- Area-specific progress not tracked (which chunks explored, blocks dug)
- `words_summoned` tracked but not used for preventing duplicate summons

## Future Work

- Save versioning with migration support
- Pet persistence (save spawned pets)
- World state persistence (dug blocks, placed objects)
- Multiple save slots
- Cloud save for Steam Deck
- Auto-save on word completion (not just area change)
