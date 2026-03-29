# Francis-opia Roadmap

> Goal: Steam release to help kids worldwide learn to read through play.

## Completed

### Infrastructure
- [x] **Terrain hills** - 2-octave sine height function with smooth transitions
- [x] **World persistence** - Seed + delta model with versioned saves
- [x] **Tree unlock mechanic** - Trees appear when player spells "tree"
- [x] **One-way platforms** - Jump through from below, land on top
- [x] **QA mode** - `--qa` flag pre-summons all sprites/features for testing
- [x] **Sprite checker tool** - `tools/sprite_check.py` detects and fixes artifacts
- [x] **Terrain flat zones** - Structures automatically flatten surrounding terrain
- [x] **Dark earth background** - Dug-out terrain shows dark soil, not sky
- [x] **Keyboard dig aiming** - W/S keys aim dig up/down

### Sprites (Phase 1-4)
- [x] **Phase 1: Foundation** - SpriteLoader, EntityVisual resource, pixel art settings, Andika font
- [x] **Phase 2: Player** - Explorer character (64x64, 4 animations: idle/walk/jump/fall)
- [x] **Phase 3: Companions** - Dog + cat sprites (48x48, idle/walk/bark/stretch)
- [x] **Phase 4: World** - Trees (3), flowers (5), crystals (3), mushrooms (3), castle (2 sizes)

### Phase 5: Terrain Tiles -- COMPLETE (2026-03-28)
- 4 L1 tiles: grass, dirt, deep dirt, bedrock (32x32 each)
- 3 L2 cave tiles: cave surface, cave dirt, cave bedrock (32x32 each)
- TerrainBlock.gd selects tile by type (grass/dirt/deep/cave) with sprite fallback
- Bedrock segments tiled across width
- `is_cave` flag on blocks for L2 tile selection
- Dark earth background behind terrain (visible when blocks dug out)

### Phase 6: Word Magic VFX -- COMPLETE (2026-03-28)
- MagicVFX autoload with reusable VFX functions
- GPUParticles2D sparkle bursts replace ColorRect particles (24 particles, radial spread)
- Camera zoom (1.15x) + gentle shake (3px max) on word completion
- Letter collection trail particles (5 particles float toward HUD)
- Color coding system: gold=magic/items, green=nature/pets, blue=water, purple=cosmetic
- CanvasModulate warm golden flash during summon moments
- Scale curve + color ramp for professional particle lifecycle

### Phase 7: UI Polish -- COMPLETE (2026-03-28)
- Andika font set as project-wide default theme (Regular + Bold)
- Styled letter slots with rounded panel backgrounds, dot indicators, green/gold/red state changes
- Coin display with pill-shaped background and gold styling
- Quest scroll with parchment-toned background, bold title, fade animations
- Pause menu with Andika-Bold title, slide-in animation, hover glow on buttons
- HUD hint label uses Andika-Bold for word emphasis

## Queued

### Phase 8: Feedback Sounds -- COMPLETE (2026-03-28)
- SoundFX autoload — hybrid sample + pitch-shift approach (not raw AudioStreamGenerator)
- WAV generation tool creates 4 warm samples: kalimba chime (5 harmonics + ADSR), wood tap, dirt crumble, stone clink (75KB total)
- Letter collection chime — ascending C major pentatonic (C-D-E-G-A-C5) via pitch_scale
- Warm kalimba timbre: fundamental + 4 harmonics + inharmonic overtone + metallic attack noise
- Micro-randomization: +/- 5 cents pitch, +/- 1.5 dB volume per play
- Word completion chord — C major triad (3 simultaneous pitch-shifted samples)
- Wrong letter — soft wood tap (auto-connected to WordEngine.wrong_letter_rejected signal)
- Dig sounds — dirt crumble or stone clink based on block type + pitch jitter
- Treasure found — two-note ascending (G4 -> C5) with 150ms gap
- Summon type accents — pet (C5), world (G4+reverb), item (E4->A4), cosmetic (D4->G4)
- Audio bus: Master(HardLimiter -1dB) > SFX(-6dB, reverb room_size 0.25)
- Volume sliders in pause menu (Master + SFX with percentage display)
- 8-player AudioStreamPlayer pool with round-robin recycling
- All parameters exposed as top-of-file constants for easy tweaking

### Phase 8b: Phoneme Sounds -- COMPLETE (2026-03-29)
- 48 phoneme audio files generated with ElevenLabs Alice voice (not just 26 letters)
- Full 44-phoneme coverage: single letters + digraphs (sh, ch, th, ng, ck) + vowel teams (ee, oo, ai, oa, ow, ou) + r-controlled (ar, or, er, ir) + split digraphs (a_e, i_e, o_e, u_e)
- phoneme_map.json with correct phoneme segmentation for all 161 words (e.g., "fish" -> ["f","i","sh"])
- PhonemePlayer autoload loads phonemes + word pronunciations from swappable voice directory
- Plays correct phoneme-in-context on letter collection (not just the letter sound)
- 28 starter word full pronunciations generated
- Phonetic spelling displayed in HUD below letter slots (e.g., "f - i - sh")
- Voice bus at 0 dB (loudest), volume slider in pause menu
- Voice generation guide at docs/voice-generation.md for adding new personas
- Licensing note: free tier = dev only; Starter tier ($5/mo) needed for commercial release

### Phase 9: Terrain Edge Darkening (Terraria)
- [ ] Exposed block faces get 2-4px darker border on air-facing edges
- [ ] 4-bit cardinal bitmask per block (N/E/S/W neighbor detection)
- [ ] Corner rounding where two edges meet air
- [ ] Updates dynamically when adjacent blocks are dug
- **Impact:** Transforms flat colored grid into shaped, readable terrain. Single biggest visual leap remaining.
- **Ref:** Terraria research report `/home/shared/terraria-terrain-rendering-research.md` Section 1

### Phase 10: Day/Night Cycle (Kingdom)
- [ ] CanvasModulate shifts world color over real time (warm gold dawn, cool blue night)
- [ ] Cycle duration configurable (default ~5 minutes per full day)
- [ ] Underground levels unaffected (already dark)
- [ ] Stars appear in sky at night, fade at dawn
- [ ] Gentle — no gameplay impact, purely atmospheric
- **Impact:** Kingdom's golden-hour atmosphere is iconic. Low effort, transforms mood.

### Phase 11: Water System (Kingdom)
- [ ] Water areas with animated sine-wave surface edge
- [ ] Semi-transparent blue fill below surface line
- [ ] Faded mirror reflection of nearby objects (simplified)
- [ ] Player can swim (slow movement, no drowning — kid-friendly)
- [ ] Spelling "POND", "LAKE", "RAIN" could summon water features
- **Impact:** Kingdom's water is its visual signature. Brings world to life.

### Phase 12: Remaining Summon Sprites
- [ ] Pixel art sprites for all other MagicSummon words still using ColorRect
- [ ] Batch by category: animals, objects, nature, effects
- [ ] Priority: most-common starter words first (sun, cat, dog, tree already done)
- [ ] Each sprite: 32x32 or 48x48, Ghibli-warm palette, nearest-neighbor filtering
- **Impact:** A kid spelling "DRAGON" and seeing a pixel dragon materialize instead of a colored rectangle is the difference between magic and disappointment.

### Phase 13: Background Music
- [ ] Adaptive layered system using AudioStreamSynchronized + AudioStreamInteractive
- [ ] Three states: Silent (active spelling), Gentle (exploring, 65-75 BPM), Warm (summon)
- [ ] C major pentatonic, piano/kalimba/music box instrumentation
- [ ] Underground: same notes shifted to A minor root, added reverb
- [ ] Minimum 90-second loops, randomized variation
- **Impact:** Sets emotional tone. But feedback sounds come first — music is enhancement, not core.

### Phase 14: Title Screen & Menus
- [ ] Title screen with game logo, "Press any key" prompt
- [ ] New Game / Continue / Settings flow
- [ ] Character name entry (simple keyboard for kids)
- [ ] Settings: volume, difficulty, language selector
- **Impact:** Currently drops straight into gameplay. Needs a front door.

### Phase 15: Steam Release Prep
- [ ] Steamworks developer account ($100)
- [ ] Store capsule images (header, hero, screenshots)
- [ ] Achievements via GodotSteam
- [ ] Localization framework (English first, then Latvian, French)
- [ ] Accessibility pass (contrast, font toggle, audio cues)
- [ ] Performance profiling on Steam Deck

### Future Features (Post-Launch)
- [ ] Biome system (different palettes per world region)
- [ ] NPC behavior trees (Kingdom-inspired companion AI)
- [ ] Multiplayer (couch co-op already scaffolded)
- [ ] Community word packs
- [ ] Level editor

## Design Principles (Non-Negotiable)

1. **Reading and spelling are THE purpose.** Every decision supports literacy learning.
2. **Words are magic.** Spelling creates reality. This is the core visual identity.
3. **No visual clutter.** Screen must feel calm. Kids can't learn if overwhelmed.
4. **60 FPS, zero stutters.** Steam Deck is the target. Performance is non-negotiable.
5. **Structures own their ground.** Any large structure registers a terrain flat zone.
6. **Consistent pixel palette.** Ghibli-warm colors everywhere. No style drift.
7. **Store semantics, not pixels.** Saves record what the player did, not what things look like.
