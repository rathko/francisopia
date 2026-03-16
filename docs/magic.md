# Magic Summoning System

Spelling words brings things to life. The core reward loop.

## Current State

### Summon Registry (`MagicSummon.gd`)
- Autoload singleton, connects to `WordEngine.word_spelled_correctly`
- Dictionary maps word (lowercase) to summon config: `{type, builder, label, color}`
- 20+ words registered across 4 summon types

### Summon Types

| Type | Words | What Happens |
|------|-------|-------------|
| pet | cat, dog, fish, bird, frog, bug | Spawns follower pet (uses Pet.gd) |
| world | sun, tree, flower, star, rainbow, bed, cup, box, jump, leaf, hand, castle | Creates decorative/interactive world object |
| item | bow | Grants bow weapon via WeaponHolder.grant_weapon() |
| cosmetic | hat | Visual change on player character |

### Summon Animation (5 phases)
1. Golden screen flash (0.15s)
2. Letters orbit outward then spiral back to center (0.7s)
3. Sparkle burst at summon point (delayed 0.6s)
4. Entity builder method runs, creates the actual node
5. Label announcement floats upward ("A cute cat!")

### Builder Methods
- Each word has a `_summon_[name]()` method
- Pet builders use `Pet.tscn` scene with DOG/CAT enum
- World builders create StaticBody2D/CharacterBody2D with ColorRect visuals
- All summoned entities added to `get_tree().current_scene`

### HUD Integration
- `get_hint_color_for_word(word)` returns Color for HUD tinting
- `get_summon_type_for_word(word)` returns type string
- `get_hint_label_for_word(word)` returns friendly text
- HUD shows type emoji: ~ (pet), * (world), + (item), ^ (cosmetic)

## Known Issues

- Words in `words.json` not in summon registry (pig, hen, red, big, run, mud, etc.) have no summon effect
- Summoned world objects persist indefinitely (no cleanup on chunk recycle)
- No duplicate prevention — spelling "cat" twice spawns two cats
- MagicSummon may be nil during early init; HUD uses safe `get_node_or_null` cache

## Future Work

- Summon effects for all 61 words in word bank
- Summoned pets should be saveable (persist across sessions)
- "Your dreams can come true in Francis-opia" — Francis's idea for wish fulfillment
- Sword, hammer, axe summons (from Francis's ideas)
- Seasonal summons (all seasons — Francis's request)
- Light/darkness powers for characters (Francis's idea)
