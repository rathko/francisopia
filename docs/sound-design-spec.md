# Sound Design Spec — Francis-opia

> Evidence-based audio design for a reading/spelling game for 5-year-olds.
> Priority: **learning first**, magical feeling, never annoying.

## Core Principles (from research)

1. **Silence during novel learning.** When a child encounters a new word for the first time, background music should be absent or nearly inaudible. Reading is not yet automatized at age 5 — music competes for the same working memory. (Cognitive Load Theory; Lehmann & Seufert 2017)

2. **Sound as confirmation, not celebration.** Reward sounds should inform ("you got it right") not celebrate ("AMAZING!!!"). The overjustification effect is real and more severe in children than adults. If the jingle is more exciting than spelling the word, the child works for the jingle. (Lepper, Greene & Nisbett 1973; Deci et al. 1999)

3. **60-80 BPM, C major pentatonic, no lyrics.** Slow tempo preserves executive attention in 4-6 year olds. Fast tempo (130+ BPM) significantly disrupts it. C major pentatonic (C-D-E-G-A) has zero dissonance in any combination. (Fernandez-Prieto et al. 2022)

4. **Phoneme sounds on letter collection.** Hearing the letter sound paired with seeing the letter is "one of the most optimal predictors" of reading success. This is the single most important audio feature. (PMC 2016; Reading Rockets multisensory research)

5. **Parents are the secondary audience.** No shrill tones, no short recognizable loops, no constant feedback density, no key-clashing between UI and music. Mid-range frequencies only. Separate volume sliders mandatory.

---

## Background Music

### Architecture: Three States (Untitled Goose Game pattern)

| State | When | Music |
|-------|------|-------|
| **Silent** | Child is actively sounding out a new word | No music. Phoneme sounds only. |
| **Gentle** | Exploring, walking, digging | Slow ambient (65-75 BPM), C major, soft instruments |
| **Warm** | Word just completed, summon happening | Same key, add a layer (strings swell, chime accent) |

### Instrumentation (Ghibli + Monument Valley inspired)

- **Primary:** Soft piano, kalimba, music box — warm, simple, child-safe
- **Secondary layers:** Gentle strings (cello/viola, not violin — less shrill), wooden flute
- **Underground:** Same pentatonic material, shifted to A minor pentatonic (same notes, different root). Add soft reverb, remove bright instruments
- **Never:** Brass fanfares, electric guitar, drums with hard attacks, synth leads

### Loop Strategy (anti-annoyance)

- Minimum loop length: **90 seconds** (short loops are the #1 annoyance driver)
- Use Godot's AudioStreamSynchronized for layered music
- Use AudioStreamInteractive for state transitions (beat-synced)
- Randomize which variation plays each time a chunk loads
- Silence between phrases — ears need rest

### Format

- OGG Vorbis for all music (supports BPM metadata for beat-synced transitions)
- Quality 6-8, stereo
- Music bus at **-12 dB** relative to master

---

## Sound Effects

### Letter Collection (MOST IMPORTANT SOUND IN THE GAME)

**What plays:** The letter's phoneme sound (e.g., collecting "C" plays the /k/ sound).

- Short, clear phoneme pronunciation (~0.3-0.5s)
- Followed by a tiny ascending chime on the C major pentatonic scale
- Pitch rises with each letter collected: 1st letter = C4, 2nd = D4, 3rd = E4, etc.
- This creates a mini melody as you spell the word — the word becomes music
- The ascending pitch reinforces sequential progress (theoretically grounded, novel design)

**Format:** WAV, mono, 44100 Hz

### Word Completion

**What plays:** The ascending chime resolves to a satisfying chord (C major triad, 0.8s).

- NOT a fanfare. NOT loud. Think Duolingo's ascending Major Third, but warmer.
- Gentle, warm, brief. The magic VFX (sparkles, camera zoom) carries the visual celebration.
- If it's a first-time word: add a soft "shimmer" layer (music box arpeggio, 1.2s)
- If it's a repeated word: just the chord, no shimmer

### Wrong Letter

**NOT a buzzer.** NOT a negative sound. A gentle "not quite" sound.

- Soft descending two-note (like a gentle "mm-mm" head shake)
- Duolingo uses a tritone (F#-C) for wrong answers — too harsh for a 5-year-old
- Instead: a soft wooden "tok" sound, like a soft mallet on wood
- Duration: < 0.3s. Don't dwell on mistakes.

### Summon Sounds (per type)

| Type | Sound | Duration |
|------|-------|----------|
| Pet (green) | Soft chirp + gentle nature chime | 0.6s |
| World (gold) | Warm shimmer + music box accent | 0.8s |
| Item (blue) | Gentle metallic ring + sparkle | 0.5s |
| Cosmetic (purple) | Playful soft boing + chime | 0.4s |

All summon sounds in C major pentatonic, harmonizing with background music.

### Dig/Break

- Soft crumble sound (dirt) / gentle clink (stone)
- Short (0.2s), low-mid frequency
- Slight randomization (3 variants per type) to prevent pattern recognition

### Footsteps

- Very soft, barely audible taps
- Grass: soft swish. Stone: quiet tap. Dirt: muffled thud.
- Volume at -18 dB relative to SFX bus — felt more than heard

### Ambient World

| Location | Ambient | Volume |
|----------|---------|--------|
| Surface | Gentle wind, distant birdsong (sparse, not constant) | -15 dB |
| Underground L1 | Soft dripping water, distant rumble | -18 dB |
| Underground L2 | Low hum, crystal resonance, echo | -18 dB |

Ambient sounds must match visual context (no birds underground).

---

## Audio Bus Layout (Godot)

```
Master (HardLimiter — mandatory for kids)
  |-- Music (-12 dB, sidechain compressed by Voice bus)
  |-- SFX (-6 dB)
  |-- UI (-8 dB)
  |-- Voice (0 dB — loudest, phoneme clarity is paramount)
```

- **HardLimiter on Master** is non-negotiable. Nothing can spike above safe volume for small ears.
- **Voice bus is loudest** — letter phonemes must be clearly heard over everything else.
- **Sidechain:** Music auto-ducks when phoneme sounds play. The child must hear the letter sound.

---

## Letter-to-Pitch Mapping

C major pentatonic across the word, wrapping naturally:

| Position in word | Note |
|-----------------|------|
| 1st letter | C4 |
| 2nd letter | D4 |
| 3rd letter | E4 |
| 4th letter | G4 |
| 5th letter | A4 |
| 6th letter | C5 |
| 7th+ | Continue ascending |
| Word complete | C major chord (C4-E4-G4) |

This means "CAT" creates the melody C-D-E, and "DOG" creates C-D-E too. The melody is tied to progress, not to the specific letters. Every word ends in a satisfying resolution.

---

## Volume Controls (Pause Menu)

Four sliders:
1. **Music** (background)
2. **Sound Effects** (dig, footsteps, ambient)
3. **Voice** (letter sounds)
4. **Master** (everything)

Default: all at 70%. Mute button per category.

---

## Anti-Patterns (NEVER DO)

- No loops shorter than 60 seconds
- No frequencies above 4kHz for sustained sounds
- No constant audio feedback on every action
- No voice acting that repeats ("Great job!" on every letter = mute by day 2)
- No UI sounds that clash keys with background music
- No volume spikes (HardLimiter enforces this)
- No music during first encounter with a new word
- No celebration sounds louder than the learning sounds

---

## Implementation Tools

| Need | Tool |
|------|------|
| SFX generation | ChipTone (CC0 output), jsfxr |
| Music composition | LMMS (free DAW), MuseScore |
| Audio editing | Audacity |
| Phoneme recordings | CC0 phonics libraries, or record with Radek/Francis |
| Godot adaptive music | AudioStreamSynchronized + AudioStreamInteractive |
| Procedural chimes | AudioStreamGenerator (GDScript synth) |

---

## Research Sources

Full research reports saved to:
- `/home/shared/sound-research-learning-science.md` (25KB, peer-reviewed citations)
- `/home/shared/sound-research-game-references.md` (26KB, 8 game/app analyses)
- `/home/shared/sound-research-implementation.md` (26KB, Godot code examples)
