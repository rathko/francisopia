# Francis-opia — Session Handoff (2026-06-14)

> Hand this to a fresh AI session to continue work. It captures the project, the build/verify
> pipeline, the hard-won gotchas, everything implemented recently, and the next tasks (esp. the
> house interior). Read this FIRST, then the referenced docs.

## 1. What this is

Francis-opia: a **Godot 4.6** side-scrolling **reading game for a 5-year-old** (Francis, the dev
Radek's son), played on a **Steam Deck**. Core loop: a target WORD is shown; Francis walks into
floating letters to spell it; on completion a "magic summon" appears (an animal that follows him, a
world object, a cosmetic, an effect). Reading = the verb that makes magic.

- **Canonical repo:** `/home/shared/nfs/src/pai/francisopia` (NFS-shared, both machines see it).
  **There is a STALE `~/radek/src/pai/francisopia` on framework — never use it.**
- **Engine runs on FRAMEWORK only** (Radek's laptop). The AI runs on mainframe and **cannot run
  Godot** — all in-engine verification is "Radek deploys + plays." Static checks + unit tests only.
- Style: warm pixel art. Summon sprites are 128×128 RGBA in `assets/sprites/summons/`.

## 2. Build / deploy / verify pipeline (READ THIS)

`./deploy.sh` (run on framework) is now **fully self-contained** and **self-verifying**:
1. imports assets, 2. **regenerates the word bank** (`tools/import_words.gd`), 3. exports the binary,
4. copies to the Steam Deck, 5. **checks deck file SIZE + sha256 == the build** and hard-fails if
not, printing `DEPLOY VERIFIED`. So a stale/failed deploy can no longer be silent.

- Run unit tests (on framework): `godot --headless --script tests/run_tests.gd` →
  expect e.g. `House Tests: 6 passed, 0 failed`.
- **Word bank:** `data/words.json` is the source of truth; the EXPORTED build only reads
  `data/words/word_bank.tres` (raw json isn't packed), so `deploy.sh` regenerates it every time.
- **Word audio:** `tools/gen_missing_word_audio.sh` (run on framework — needs BWS `ELEVENLABS_API_KEY`
  + egress, blocked in the sandbox) auto-detects words missing an `alice` voice clip and generates
  them via ElevenLabs (voice `Xb7hH8MSUJpSbSDYk0k2`, see `docs/voice-generation.md`).

## 3. GDScript gotchas that WILL bite (also in memory)

- **No Godot on mainframe** → can't run/parse-check here. `deploy.sh` export is the parse gate.
- **Typed-array assignment:** `gm.active_companions = ["dog"]` (untyped literal → `Array[String]`)
  **crashes at runtime**. Use `gm.active_companions.assign(["dog"])`.
- **`:=` type inference:** calling a method on a `Node`-typed var returns Variant → `var x := node.foo()`
  parse-fails. Use explicit `var x: Array = node.foo()`. (Autoloads in scene code ARE typed, fine there.)
- `abs()/round()/clamp()` return Variant → use `absi/roundf/clampi/clampf`.
- **New/changed PNG needs an editor re-import** to a `.ctex` before runtime — `deploy.sh` import pass
  handles it; never hand-author `.import` files.
- Embedded `GDScript.source_code` strings: inside a regular `"..."` string use `\"` and `\n`/`\t`;
  inside a `"""..."""` triple-quoted string, inner `"` need NO escaping.
- Forge/codex reverts uncommitted edits in the same tree — don't use it here.
- **Git:** never commit/push for Radek; stage + print commands, he runs them.

## 4. Everything implemented this session (feature log)

**Summons added / fixed (`scripts/autoload/MagicSummon.gd`):**
- **BAG → Hiking backpack** worn on Francis's back (was a coin bag). Pixel sprite `bag.png`
  (generator `tools/gen_bag_sprite.py`); `equip_backpack()` is idempotent + restored on load
  (`MainScene._ready`) so it stays forever; `z_index=1` so it's visible on the back.
- **HERO** (new word) → caped super-puppy flies across the screen, spinning, then vanishes. Sprite
  `hero.png` (`tools/gen_sprites.py`). Screen-space CanvasLayer.
- **BUNNY** (new word) → white hopping bunny companion. Sprite `bunny.png`.
- **FRIEND** (new word) → a kid companion who skips along (first taste of the friends system).
- **RAT** → already a companion; gave it a pixel sprite `rat.png`; house renders the sprite.
- **CRAB / TENT / ~85 words had NO summon** → added a **generic fallback** in `_on_word_spelled`:
  any word without a specific summon gets a big sparkle + a lingering glowing star (`_summon_generic`).
  So EVERY word now does something.
- **CAN** → now SITS on the ground; jumping on / touching it launches it at 45° spinning (kicked).
- **LIP** → was a permanent lip stuck on the face; now a brief blown-**kiss** icon that floats up and
  fades (marked `temporary`).
- **HAMMER** → fixed: builder returned null so ownership was never recorded; now `equip_hammer()`
  records `items_owned`, draws at `z_index=10` (was hidden behind the body), is restored on load, and
  HAMMER is **force-prioritized** in word selection until owned.
- **Effects** are bigger/longer: reveal sprite hangs ~5s (was ~1s); `MagicVFX.spawn_sparkle_burst`
  is larger + lingers ~2.2s (40 particles).
- **Animal voices:** `scripts/autoload/CompanionChatter.gd` (autoload) — followers chirp when Francis
  approaches + occasional background; asset-free via `SoundFX.play_critter()` (pitch-shifted samples).
  It had a `MagicSummon` identifier compile error — fixed by `get_node_or_null("/root/MagicSummon")`.

**Word selection — the "same words repeat" bug (`scripts/autoload/WordEngine.gd`):**
- Root cause: selector keyed off `words_summoned` (skips temporary-effect words like BIG) instead of
  `words_completed` (records EVERY spelled word, persists). **Fixed:** uses `words_completed`, removed
  the `repeatable` exception. A spelled word never repeats until ALL are spelled, then recycles.
- Level gate: `wl == game_level` → `wl <= max_difficulty` so reaching level 2 surfaces level-2 words.

**Letter sounds (`scripts/autoload/PhonemePlayer.gd`):** per-letter phoneme playback is HIDDEN behind
`_letter_sounds_enabled=false` (many were wrong); the wrong phoneme-stitch fallback is off
(`_spell_out_fallback=false`). Only real full-word recordings play. Code kept behind the flags.

**Tooling:** `deploy.sh` rewritten (regen word bank + import + checksum-verify deck + timestamps);
`tools/gen_missing_word_audio.sh` (auto-detect missing word audio, ElevenLabs alice). Diagnostic
scripts in `/home/shared/nfs/logs/francisopia-deploy-doctor*.sh`.

## 5. THE HOUSE feature (current focus)

**Design doc:** `docs/house-interior-architecture.md` (research-backed, 14 pre-mortem failure modes).
Key idea: the interior is a self-contained build/teardown that swaps out the overworld (no new scene,
no procedural-generator surgery). **"Following" = membership of `GameManager.active_companions`** is
the single source of truth — an animal is never both following AND shown in its room.

**State model (`scripts/autoload/GameManager.gd`) — built + UNIT-TESTED (`tests/test_house.gd`, 6 tests):**
- `housed_animals: Array[String]` (every animal that lives in the house),
  `room_index: Dict` (word→permanent room number, never reshuffles),
  `interior_props: Dict` (furniture placed — for the future furniture slice),
  `next_room_index`, `house_outdoor_x/y`, transient `in_house: bool`.
- `register_housed_animal()`, `get_room_index()`, `is_following()`, `get_home_animals()`,
  `_validate_house_state()` (clamps following ≤3, forces consistency on load). All saved/loaded.
- `MagicSummon.register_companion()` calls `register_housed_animal()` so every animal gets a room.

**Slice 1 — BUILT (`scenes/main/MainScene.gd`):** enter/exit a house interior.
- `_ensure_house_door()` — an **ENTER** door (`collision_layer 4`, `interact()`) appears in the
  overworld once Francis has a house (`home_pos` set, i.e. spelled HOUSE/HUT).
- `enter_house()` / `exit_house()` — tear down/rebuild the overworld (`_remove_chunk` / 
  `_regenerate_all_chunks`), gate `_update_chunks` with `_in_house`, gate digging with
  `GameManager.in_house` (in `PlayerController._handle_dig`).
- `_build_house_interior()` — warm interior, header, **solid floor + left/right walls + ceiling
  (Francis can't fall/jump out — just fixed)**, **3 exit doors (left end, middle, right end)**, a
  room per housed animal (name + bed; **renders the animal's sprite** via `_house_item_visual()`, or
  an empty bed + "(out with you!)" if it's currently following), a ghost "?" room.
- `_house_item_visual(word,pos,scale)` — renders a thing's `summons/<word>.png` sprite, else a shape.

**STILL TO DO on the house (the user's latest requests + planned slices):**

1. **MUSEUM REDESIGN of the entry room (requested, NOT yet built).** Target layout, left→right:
   `[left wall + exit] [TROPHY GALLERY] [big central hall + exit, Francis spawns here] [ANIMAL ROOMS + exit] [right wall]`.
   - Entry/central hall **much larger** (museum lobby feel), Francis spawns in its centre.
   - **Left wing = trophies:** one **pedestal per spelled "item"** (e.g. GEM, BED, LAMP, NUT) — a
     pedestal column + the item's sprite on top + word label. Compute trophy words as
     `words_completed` minus `housed_animals` minus effect/power-up words (BIG, RUN, HOP, ZIP, DIG,
     RED, HOT, WET, HUG, HIT, MUD, NET, WEB, JAM, FOG, MIX, MOP, etc.). Reuse `_house_item_visual()`.
   - **Right wing = animals** (already one room each).
   - Make it **beautiful**: museum-cream walls, wainscot, framed pedestals, rug, signposts
     "← Trophies / Animals →". `Francis's House & Museum` banner.
   - I have a full draft of the rewritten `_build_house_interior()` for this in the conversation
     history; it sizes the hall + wings dynamically and sets `_house_center_x` for the spawn. Re-derive
     it: floor spans `left_wall .. right_wall`; place exits at left end, `_house_center_x`, right end.
2. **Slice 2 — take/leave (the heart of it):** walk up to a home animal → `interact()` → "take with
   me" (join active group) or, if group is already 3, a **"who goes home?"** icon tap (NEVER silently
   evict — pre-mortem TOP-4). Walk up to a following animal → "leave here". New file
   `scenes/world/RoomAnimal.gd` (Area2D `collision_layer 4` + `interact()`), reusing
   `MagicSummon.activate_companion` / `_send_companion_home`. The state model already supports this.
3. **Slice 3 — furniture/trophies as functional objects** (BED you can rest on, LAMP that glows),
   `data/house_props.json` mapping word→{prop, anchor}; fixed slots, ghost silhouettes for not-yet-earned.
4. **Slice 4 — navigation:** a minimap strip + "call animal to the entrance" button (the house gets
   wide; the architecture flags this as build-before-it-grows). Performance: stream/free rooms >3
   screens away when there are many animals.

## 6. Key files

| File | What |
|---|---|
| `scripts/autoload/GameManager.gd` | save/load + house state model + `_validate_house_state` |
| `scripts/autoload/WordEngine.gd` | word selection (uses `words_completed`; HAMMER priority; level gate) |
| `scripts/autoload/MagicSummon.gd` | the summon registry + all `_summon_*` builders + companions + house helpers (`equip_hammer/equip_backpack`) |
| `scripts/autoload/CompanionChatter.gd` | animal voices (asset-free) |
| `scripts/autoload/PhonemePlayer.gd` | word/letter pronunciation (letter sounds hidden) |
| `scripts/autoload/SoundFX.gd` | SFX + `play_critter` |
| `scenes/main/MainScene.gd` | world gen + the HOUSE interior (`enter_house`/`exit_house`/`_build_house_interior`) |
| `scenes/player/PlayerController.gd` | movement, dig (gated in house), interact |
| `scenes/world/TreasureChest.gd` | dug chests (despawn after 60s) |
| `data/words.json` | word bank source of truth (168 words) |
| `data/house_props.json` | (to be created in Slice 3) |
| `tests/test_house.gd`, `tests/run_tests.gd` | unit tests |
| `tools/gen_sprites.py`, `gen_bag_sprite.py`, `gen_missing_word_audio.sh`, `import_words.gd` | generators |
| `docs/house-interior-architecture.md`, `docs/friends-system-architecture.md`, `docs/voice-generation.md` | designs |

## 7. Immediate next step

Deploy what's built (`./deploy.sh`), confirm entering the house works (spell HOUSE → stand on ENTER →
inside; can't fall out; 3 exits; animals render as sprites; following animals' rooms empty). Then
implement the **museum redesign (§5.1)** and **Slice 2 take/leave (§5.2)**. Keep writing/extending the
unit tests in `tests/test_house.gd` (the only verification available without the engine).
