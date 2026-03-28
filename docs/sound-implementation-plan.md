# Sound Implementation Plan — Phase 8

> Procedural feedback sounds for Francis-opia. Research-backed, learning-first, not robotic.

## Decision: Hybrid Approach (Sample + Procedural)

After researching pure synthesis, pure samples, and hybrid approaches, **hybrid wins decisively:**

| Approach | Warmth | Variety | Dev Time | Tweakable |
|----------|--------|---------|----------|-----------|
| Pure GDScript synthesis | Cold without heavy work | Infinite | High | Yes |
| Pure WAV samples | Warm immediately | Need many files | Medium | No |
| **Hybrid: 1-2 WAV + pitch-shift + procedural variation** | **Warm immediately** | **Infinite** | **Low** | **Yes** |

### Why not pure synthesis?
GDScript AudioStreamGenerator is too slow for warm multi-harmonic synthesis (1-2 voices max at 22050 Hz). Getting a kalimba to sound warm from pure math requires 5+ harmonics with ADSR envelopes — that's a C++ GDExtension project, not a GDScript weekend.

### Why not pure samples?
Need 6+ notes for pentatonic scale, times 4 summon types, times variations = 50+ WAV files to manage. Brittle, not tweakable.

### Why hybrid?
One high-quality kalimba WAV sample (C4, 44100Hz, <50KB) + Godot's `AudioStreamPlayer.pitch_scale` = full pentatonic scale. Add procedural micro-randomization on top = infinite organic variation from one file. Tweakable by changing the source sample later.

**Formula:** `pitch_scale = pow(2.0, semitones / 12.0)`
- C4 to D4 = +2 semitones = pitch_scale 1.122
- C4 to E4 = +4 semitones = pitch_scale 1.260
- C4 to G4 = +7 semitones = pitch_scale 1.498
- C4 to A4 = +9 semitones = pitch_scale 1.682 (max comfortable range)

**This is how Animal Crossing and Stardew Valley do it.** Proven at scale.

---

## Sound Inventory

### Tier 1: Letter Collection Chime (highest priority)
- **Source:** 1x kalimba/music box WAV sample (C4 note, ~0.4s)
- **Behavior:** Pitch-shifts to ascending pentatonic position (C-D-E-G-A-C5)
- **Humanization:** +/- 5 cents pitch jitter, +/- 10% volume jitter, +/- 15ms timing jitter
- **Learning tie-in:** Each letter = one step up the scale = audible progress toward word completion
- **Duration:** ~0.3s (short, never outstays welcome)

### Tier 2: Word Completion Chord
- **Source:** Same kalimba sample, 3 instances pitch-shifted simultaneously (C4+E4+G4)
- **Or:** 1x dedicated chord WAV sample (~0.6s, warm C major triad)
- **Behavior:** Plays once, gentle decay. NOT a fanfare.
- **Volume:** Same as letter chimes, not louder. The VFX (sparkles, camera zoom) carries the celebration.

### Tier 3: Wrong Letter Tap
- **Source:** 1x soft wood tap WAV (~0.15s)
- **Behavior:** Fixed pitch, slight volume randomization
- **Feel:** Like tapping a wooden table gently. Not a buzzer, not a punishment.
- **Learning:** Duolingo uses a tritone (harsh) — too scary for age 5. A wood tap says "not this one" without judgment.

### Tier 4: Dig/Break Sounds
- **Source:** 1x dirt crumble WAV (~0.2s), 1x stone clink WAV (~0.2s)
- **Behavior:** Random pitch jitter (+/- 3 semitones), 3 virtual "variants" from one sample
- **Volume:** -6 dB below feedback sounds. World sounds are background, not foreground.

### Tier 5: Treasure Found
- **Source:** Kalimba sample pitch-shifted to G4 then C5 in sequence (~0.4s total)
- **Feel:** Two-note ascending "discovery" motif

### Tier 6: Summon Type Accents
- **Pet (green):** Kalimba chime at higher octave (C5) — bright, alive
- **World (gold):** Same chime with added reverb — expansive, magical
- **Item (blue):** Slightly metallic variant (could be a different source sample)
- **Cosmetic (purple):** Quick two-note playful pattern

---

## Total Asset Count

| Asset | Format | Size (est.) | Source |
|-------|--------|-------------|--------|
| Kalimba C4 note | WAV 44100Hz mono | ~40KB | Record, CC0 library, or ChipTone |
| Wood tap | WAV 44100Hz mono | ~10KB | ChipTone or Freesound CC0 |
| Dirt crumble | WAV 44100Hz mono | ~15KB | ChipTone or Freesound CC0 |
| Stone clink | WAV 44100Hz mono | ~12KB | ChipTone or Freesound CC0 |
| **Total** | | **~77KB** | |

**Four WAV files.** Everything else is pitch-shifting and parameter variation in code.

---

## Humanization System (Anti-Robotic)

Every sound play gets micro-randomization applied before playback:

```
pitch_jitter:  +/- 5 cents (0.3% frequency)     — barely perceptible, prevents mechanical feel
volume_jitter: +/- 1.5 dB (0.85x to 1.15x)       — subtle loudness variation
timing_jitter: +/- 15ms                           — tiny async feel, like a real player
```

These are the same techniques used by:
- **Monument Valley:** Every puzzle piece interaction has slight variation
- **Animal Crossing:** Animalese pitch varies per character
- **Untitled Goose Game:** Fragment selection adds natural variety

The brain detects and is annoyed by exact repetition. Even 1% randomization breaks the pattern.

---

## Audio Bus Layout

```
Master
  |- HardLimiter (ceiling: -1 dB, non-negotiable for kids)
  |- EQ: boost +2 dB at 300-500 Hz (warmth), cut -3 dB above 6 kHz (anti-shrill)
  |
  |-- Voice (0 dB) — phoneme sounds (Phase 8b, loudest)
  |-- SFX (-6 dB) — letter chimes, dig sounds, summon accents
  |     |- Reverb: room_size 0.25, wet 0.15, damping 0.7
  |-- UI (-8 dB) — menu clicks, pause sounds
  |-- Music (-12 dB) — background music (Phase 13)
        |- Sidechain compressor: ducked by Voice bus
```

---

## Pre-Mortem

| What could go wrong | Likelihood | Mitigation |
|---------------------|-----------|------------|
| Kalimba sample sounds bad pitch-shifted beyond +7 semitones | Medium | Use 2 samples (C4 + C5) to split the range. Or limit to 5-note pentatonic within safe range. |
| Sounds feel disconnected from visuals (chime plays but no visual feedback) | Low | Already have MagicVFX trail particles synced to letter collection. Wire sound to same trigger. |
| HardLimiter causes audible pumping when multiple sounds overlap | Low | Set ceiling to -1 dB, use soft knee. Test with 3+ simultaneous sounds. |
| Parents mute the game entirely | Medium | Make sounds genuinely pleasant. Provide granular volume controls. Test with actual parents. |
| Procedural jitter makes sounds feel "broken" to a child | Low | Keep jitter subtle (5 cents, not 50). A/B test jittered vs non-jittered with Francis. |
| AudioStreamPlayer pool runs out during heavy dig sessions | Medium | Pre-allocate pool of 8 players, recycle oldest. Dig sounds are lowest priority — drop them first. |
| Sound design delays game development significantly | Low | Only 4 WAV files needed. Can use placeholder sine beeps for testing, swap samples later. |
| The ascending pentatonic melody becomes the child's focus instead of spelling | Medium | Keep chimes short (0.3s), soft, background-level. The word on screen and VFX should dominate attention. Monitor during playtesting with Francis. |

---

## Implementation Architecture

```
SoundFX (Autoload)
  |-- _chime_player_pool: Array[AudioStreamPlayer]  (4-6 pre-allocated)
  |-- _sfx_player_pool: Array[AudioStreamPlayer]     (4 pre-allocated)
  |
  |-- play_letter_chime(position: int)
  |     Pitch-shifts kalimba to pentatonic note at position
  |     Applies humanization jitter
  |
  |-- play_word_complete()
  |     Plays C major triad (3 simultaneous pitch-shifted kalimba)
  |
  |-- play_wrong_letter()
  |     Plays wood tap with volume jitter
  |
  |-- play_dig(block_type: String)
  |     Plays dirt or stone with pitch jitter
  |
  |-- play_treasure_found()
  |     Two-note ascending (G4, C5) with slight delay
  |
  |-- play_summon_accent(summon_type: String)
  |     Type-specific chime variation
  |
  |-- Constants exposed for tweaking:
  |     PITCH_JITTER_CENTS, VOLUME_JITTER_DB, TIMING_JITTER_MS
  |     CHIME_BASE_VOLUME, SFX_BASE_VOLUME
  |     PENTATONIC_SEMITONES: [0, 2, 4, 7, 9, 12]  # C-D-E-G-A-C5
```

### Integration Points

| Trigger | File | Signal/Method |
|---------|------|---------------|
| Letter collected | FloatingLetter.gd:collect() | `SoundFX.play_letter_chime(position)` |
| Word completed | MagicSummon.gd:_play_summon_animation() | `SoundFX.play_word_complete()` |
| Wrong letter | WordEngine.gd:try_collect_letter() | `SoundFX.play_wrong_letter()` |
| Block dug | TerrainBlock.gd:dig() | `SoundFX.play_dig(block_type)` |
| Treasure found | TerrainBlock.gd:_spawn_treasure() | `SoundFX.play_treasure_found()` |
| Summon happens | MagicSummon.gd:_play_summon_animation() | `SoundFX.play_summon_accent(type)` |

### Tweakability

All parameters are `const` at the top of `SoundFX.gd`:
- Change the source WAV: swap one file, everything re-pitches automatically
- Adjust pentatonic scale: change one array
- Tune humanization: change 3 constants
- Disable sounds per-type: set volume to 0

---

## Source Material Options

### Option A: Record ourselves
- Record Francis tapping a real kalimba/xylophone
- Authentic, personal, zero licensing concerns
- Need: any kalimba ($15), phone microphone, Audacity

### Option B: CC0 sound libraries
- **Freesound.org** — filter by CC0, search "kalimba single note"
- **Kenney.nl** — game audio pack (CC0)
- **SONNISS GameAudioGDC** — annual free bundle

### Option C: Generate with tools
- **ChipTone** (web) — CC0 output, can approximate bell/chime sounds
- **Vital** (free synth VST) — render warm tones to WAV via LMMS
- **wafxr** — web-based, best of the sfxr family for non-retro sounds

**Recommendation:** Start with Option B (CC0 kalimba from Freesound), iterate. If we want personal touch, Option A with Francis is magical — "these are sounds your son helped create."

---

## Research Sources

- `/home/shared/sound-research-procedural-synthesis.md` (35KB — synthesis formulas, bell/kalimba recipes)
- `/home/shared/sound-research-godot-tools.md` (23KB — AudioStreamGenerator, plugins, bus effects)
- `/home/shared/sound-research-educational-patterns.md` (26KB — Teach Your Monster, Endless Alphabet, Animalese)
- `/home/shared/sound-research-learning-science.md` (25KB — cognitive load, reward psychology)
- `/home/shared/sound-research-game-references.md` (26KB — Monument Valley, Journey, Duolingo)
- `/home/shared/sound-research-implementation.md` (26KB — Godot audio formats, bus layout, letter mapping)
