# Audio System

Sound effects and music management.

## Current State

### Audio Manager (`AudioManager.gd`)
- Autoload singleton
- SFX pool: 8 AudioStreamPlayer nodes (round-robin allocation)
- Music player: single AudioStreamPlayer with fade in/out (1.0s default)
- Audio busses: "Music" and "SFX"

### Key Methods
- `play_sfx(stream)`: play sound effect from pool
- `play_music(stream, fade_in)`: crossfade to new music track
- `stop_music(fade_out)`: fade current music to silence
- `play_letter_sound(letter)`: placeholder — prints to console, no audio yet

### Current Usage
- `FloatingLetter.collect()` calls `AudioManager.play_letter_sound(_letter)`
- No other audio calls exist in the codebase

## Known Issues

- No audio files exist in the project (assets/ is empty)
- `play_letter_sound()` is a stub that does nothing
- No background music
- No sound effects for: digging, jumping, chest opening, summoning, walking

## Future Work

- Letter phonics audio (pronounce each letter sound on collection)
- Word pronunciation on completion
- Background music per area (meadow, castle, beach, forest, mountain)
- SFX: dig, jump, land, collect, chest open, summon, arrow shoot/hit
- Volume control in settings menu
- Spatial audio for nearby events
