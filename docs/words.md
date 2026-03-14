# Word Bank

Content data for the spelling system.

## Current State

### Data File (`data/words.json`)
- Version: 0.1.0
- 61 total words across 5 levels and 5 areas

### Word Distribution

| Level | Count | Type | Examples |
|-------|-------|------|---------|
| 1 (CVC) | 20 | Consonant-Vowel-Consonant | cat, dog, sun, hat, bed, cup, pig, hen |
| 2 (Blends) | 15 | Consonant clusters, 4 letters | frog, tree, star, jump, fish, bird, leaf |
| 3 (Long vowels) | 8 | Magic E, vowel pairs | cake, bike, moon, boat, rain, snow |
| 4 (Complex) | 5 | Multi-syllable | flower, castle, garden, forest, island |
| 5 (Advanced) | 5 | 5+ letters | rainbow, sunset, crystal, meadow, lantern |

### Area Distribution

| Area | Level 1 | Level 2 | Level 3 | Level 4 | Level 5 |
|------|---------|---------|---------|---------|---------|
| meadow | 9 | 4 | 2 | 1 | 1 |
| castle | 7 | 4 | 2 | 1 | 0 |
| forest | 2 | 3 | 0 | 1 | 0 |
| beach | 1 | 1 | 2 | 1 | 1 |
| mountain | 0 | 2 | 2 | 0 | 1 |

### Entry Format
```json
{
  "word": "cat",
  "level": 1,
  "area": "meadow",
  "image": "cat",
  "phonics": ["c", "a", "t"]
}
```

### Phonics Data
- Each word has a `phonics` array splitting it into sound units
- Digraphs: "sh", "oo", "ea", "ai", "ow", "ir", "or", "ar", "er", "le", "al"
- Magic E patterns: "a_e", "i_e", "o_e"
- Not yet used in-game (placeholder for phonics audio)

### Builtin Fallback (`WordEngine.gd`)
- 21 words hardcoded as fallback if `words.json` fails to load
- Covers levels 1-4 in meadow area only
- Subset of the JSON word bank

## Known Issues

- Only meadow words are reachable (other areas not implemented)
- Phonics data unused — no phonics audio or visual breakdown
- `image` field unused — no image assets exist
- Some words lack summon registry entries (no magic effect on completion)
- No Francis-specific vocabulary tracking (which words he knows vs needs practice)

## Future Work

- Expand to 200+ words across all areas
- Multi-language: English, French, Latvian word banks
- Sight words at appropriate levels
- Per-child progress tracking (spaced repetition per word)
- Phonics audio integration
- Word categories: animals, colors, actions, objects, nature
