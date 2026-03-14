# Spelling System

Core educational mechanic. Player collects letters in order to spell words.

## Current State

### Word Selection (`WordEngine.gd`)
- Autoload singleton manages all word/letter logic
- `select_word_for_area(area)` picks a word matching current difficulty + area
- Filters: `level <= current_difficulty AND area == target_area`
- Fallback chain: area match > any word at difficulty > level 1 > "cat"
- Selected word stored as UPPERCASE in `current_target_word`
- Emits `target_word_changed(word, hint_image)` on selection

### Letter Collection
- Letters must be collected **in sequence** (left to right)
- `try_collect_letter(letter)` validates against `current_target_word[next_index]`
- Correct: appends to `collected_letters`, emits `letter_collected(letter, position)`
- Wrong: emits `wrong_letter_rejected(letter)`, triggers LetterThief spawn
- Word complete when `collected_letters.size() == current_target_word.length()`
- On completion: emits `word_spelled_correctly(word)`, awards coins, checks difficulty

### Difficulty Progression
- 5 levels, unlocked by total words completed across all sessions
- Level 1: 0-9 words (CVC: cat, dog, sun)
- Level 2: 10-24 words (blends: frog, fish, star)
- Level 3: 25-39 words (long vowels: cake, moon, rain)
- Level 4: 40-59 words (complex: flower, castle)
- Level 5: 60+ words (advanced: rainbow, crystal)

### Floating Letters (`FloatingLetter.gd`)
- Area2D with Label child, sine-wave floating animation
- Needed letters: 64pt gold, pulse scale 0.8-1.0, background glow
- Distractors: 36pt gray, 50% opacity, no effects
- States: floating, collected (scale up + fade), rejected (bounce), stolen (fade)
- `_base_position` set in both `_ready()` and `setup()` to prevent position bugs

### Letter Sources
- **Treasure chests**: always drop the next needed letter (primary source)
- **Surface chests**: 1-2 per chunk sitting on ground
- **Underground chests**: 6% chance per dirt block
- LetterSpawner exists but no longer auto-spawns floating letters

## Signals

| Signal | Emitted When | Listeners |
|--------|-------------|-----------|
| `target_word_changed(word, hint)` | New word selected | HUD, LetterSpawner |
| `letter_collected(letter, pos)` | Correct letter picked up | HUD |
| `word_spelled_correctly(word)` | All letters collected | MagicSummon, GameManager, LetterSpawner |
| `wrong_letter_rejected(letter)` | Wrong letter touched | MainScene (spawns thief) |

## Known Issues

- Letters from treasure chests spawn via `add_child` before position set; `setup()` corrects `_base_position` but there's a single frame at wrong position
- No visual feedback showing which letter is needed next (only underscore slots)
- Letter Thief can steal a letter the player needs, forcing a wait for respawn
- `words.json` has words in areas (castle, beach, forest) that aren't reachable yet

## Future Work

- Phonics audio: play letter sounds when collected (`AudioManager.play_letter_sound`)
- Multi-language support (English, French, Latvian)
- Sight words at level 4 (the, was, have)
- Visual hint arrow pointing toward nearest needed letter
- Letter combining animation when word completes
