---
title: Francis-opia — AI Session Handoff
status: live
created: 2026-06-14
owner: radek
purpose: "Hand off the Francis-opia game-dev work to a fresh AI session with full state + safe next steps."
prior_session_ended: 2026-06-14
---

# Francis-opia — AI Session Handoff

## 1. TL;DR for the next model

Francis-opia is a **Godot 4.6 side-scrolling reading game for a 5-year-old** (Radek's son), played on a **Steam Deck**. This session built **Level 3 "Car Town"** (a driveable-cars street), a **friends system character**, a hardened **self-verifying deploy pipeline**, and fixed a string of regressions. **All work is committed + pushed** (HEAD `49f14fe`, branch `main`, clean tree). The very latest commits — **van 50% bigger, vehicle facing-flip, and the friend shrunk via an art-wrapper** — are committed but **NOT yet deployed to the Deck or eyeballed on device**. Your most likely first job: deploy, watch Radek test on the Deck, and fix what he reports. You CANNOT run Godot (see §7); the deploy gate is your only verification.

## 2. What was built this session (forward-looking summary)

- **Level 3 "Car Town"** — flat paved street far below L2. Reached two ways: a **checkered racing GATE** by the house (appears only after L3 is discovered) and an **L2→L3 elevator shaft**. Background houses, pavement chests, **no digging**. `_generate_car_street` in `scenes/main/MainScene.gd`.
- **Driving** — walk to a vehicle → X → Francis rides **visible** in the cab, **active animals ride the roof**, arrows drive, X exits. Van/bus use their **real sprites** (`van.png`/`bus.png`); car is drawn. `enter_vehicle` / `_drive_update` / `exit_vehicle` / `_add_street_vehicle`.
- **Cars are spell-to-unlock** — VAN / CAR / BUS only appear once spelled (`items_owned`). On reaching L3, the goal word auto-switches to **VAN** until spelled; an owned van waits parked next to him.
- **Summons added** (were silent before): `thunder`, `bike`, `vine` (grows from ground), `planet` (banded Jupiter next to the sun for ~30s), `car`. Plus a **universal "word card"** so EVERY spelled word visibly shows what was spelled even with no art.
- **Friend** — rebuilt as a detailed pixel kid (ginger pigtails, striped tee); art lives under a **0.55-scaled child node** so she's ~36px and stays small even under the BIG power-up. Preview: `docs/friend-preview.png`.
- **Deploy gate** — `deploy.sh` now: generates sprites + missing word audio, imports, runs unit tests, **boots the scene headless under `--qa`**, and **refuses to ship unless `Terrain ready: N>0` prints** and no `SCRIPT ERROR` appears. SSH steps **auto-retry 5×**.
- **Regressions fixed** — terrain builds first in `_ready`; **stable self-healing home** (no teleport-to-void); `respawn_y` pushed below L3 (no bounce-back on descent); stronger **auto-unstuck**; **shaft kept clear** of L2 platforms; HAMMER→VAN→FRIEND **word priority** with depth-based `current_level` tracking.

## 3. What is locked — do NOT re-litigate

| Decision | Why / where |
|---|---|
| **No Godot on mainframe; deploy.sh gate is the only verification** | Static + unit tests + headless smoke. The export step fails on parse errors; the smoke asserts terrain built. |
| **All code committed + pushed each session by Radek** | HEAD `49f14fe`, clean tree, 0 ahead of origin. Don't expect uncommitted diffs. |
| **Cars are spell-to-unlock, not auto-spawned** | `_generate_car_street` only spawns owned car types at the landing. |
| **VAN keyed specifically (not "any car")** for the L3 priority | `WordEngine.select_word_for_area`. |
| **Friend art under a scaled child node** (not a node-scale hack) | BIG resets the body's scale; the art node survives it. `_summon_friend` in `MagicSummon.gd`. |
| **Memory is already bounded** — chunks unload (keep_range 3, ~7 alive) | No world-loop needed regardless of drive distance. |
| **Headless `--qa` SIGSEGVs on GPUParticles** — gate WARNS (not fails) on a crash AFTER the world built | GPU-less artifact; the real device is fine. |
| **Friend quest bubble removed** | Radek said it wasn't helpful. |

## 4. Active artifacts (read first, in order)

1. `scenes/main/MainScene.gd` — world gen, Level 1/2/3, chunks, house interior, driving, gate, stairwells (~2900 lines).
2. `scripts/autoload/MagicSummon.gd` — the summon registry + every `_summon_*` builder + companions + friend.
3. `scripts/autoload/WordEngine.gd` — word selection + HAMMER/VAN/FRIEND priority.
4. `deploy.sh` — the self-verifying build/deploy pipeline (read the HEADLESS VALIDATION + retry blocks).
5. `scripts/autoload/GameManager.gd` — save/load + house/level state (`found_level3`, `housed_animals`, `current_level`).
6. `docs/house-interior-architecture.md`, `docs/friends-system-architecture.md` — design docs.
7. Previews: `docs/friend-preview.png`, `docs/cartown-gate-preview.png`.

## 5. Considered and explicitly rejected (don't re-propose)

- **Auto-spawning cars in Car Town** — rejected; cars only appear after spelling.
- **Forcing VAN re-select on every level change** — rejected (would reset letter progress when jittering across the L1/L2 boundary). Only forced on the one-way descent into L3.
- **A world-loop / teleport-back-every-5-min for memory** — unnecessary; chunk unloading already bounds memory.
- **Scaling the friend's node directly** (`friend.scale`) — rejected; BIG overrides it. Use the art-wrapper.
- **Drawing the van from ColorRects** (the ice-cream van) — rejected; Radek wants the real `van.png` sprite.
- **Hard-failing the deploy on the headless GPUParticles crash** — rejected; warn only (device unaffected).
- **A quest bubble above the friend** — rejected as unhelpful.

## 6. Next concrete actions (pick whichever is unblocked)

1. **PRIMARY: deploy the latest commit and verify on device.** Have Radek run `./deploy.sh` (from framework). Eyeball: van is ~50% bigger and faces its driving direction; friend is small (~36px); the CAR TOWN racing gate appears by the house after descending the elevator once. Fix whatever he reports.
2. **If van seating/positions look off:** Francis's seat + animals' roof use per-vehicle `seat_y`/`roof_y` metadata (`_add_street_vehicle`, read in `_drive_update`) — tune the `* 0.34` / `* 0.66` fractions.
3. **House Slice 3 (not started):** furniture/trophies as functional objects (BED to rest on, LAMP that glows); `data/house_props.json` mapping word→{prop, anchor}; ghost silhouettes for not-yet-earned. See `docs/house-interior-architecture.md`.
4. **Friends-system expansion:** the friend currently just follows. `docs/friends-system-architecture.md` has the roadmap.
5. **Long-tail summons:** keep adding specific `_summon_*` builders for common words; the universal word-card already covers the rest.

## 7. Critical preferences / gotchas (don't violate)

- **No Godot on mainframe** — never claim something renders/works; the deploy gate (on framework) is the proof. The gate's `Terrain ready: N>0` line is the regression tripwire.
- **GDScript parse traps that bit us:** `:=` cannot infer from a Variant — i.e. loop vars from untyped array literals (`for side in [-1.0, 1.0]: var x := side * 5` ❌) and `Dictionary.get()`. Use explicit `var x: float = ...` or wrap with `float()`. Indentation is **tabs**; run a space-indent check after edits.
- **NEVER commit / tag / push for Radek** — stage + print commands; he runs them. (He commits+pushes himself; tree is usually clean.)
- **`./deploy.sh` runs on FRAMEWORK only** (needs Godot + export templates + BWS ElevenLabs key for audio). It self-verifies and refuses to ship a broken build.
- **Use `bun`/TypeScript** for any tooling, never npm/Python (Python is allowed only for the existing `tools/gen_*.py` sprite/asset generators which already exist).
- Radek **dictates** prompts (tolerate transcription errors: "bike"→"bug", "front"→"friend") and is **audio-first** — every substantive reply needs a `🎧 AUDIO:` block; end with the exact run command before it.
- The canonical repo path is `/home/shared/nfs/src/pai/francisopia` (NFS-shared; the `~/radek/src/...` copy on framework is STALE — never use it).

## 8. Open questions for Radek (ask before building big)

- House **Slice 3 (furniture/trophies)** — build next, or keep polishing Level 3 / cars first?
- Should the **friend give a real quest** (spawn a reward when TOY is spelled), now that the bubble is gone?
- Any **third driveable type** beyond van/car/bus, or is three enough?
- Is the **racing gate** the right discovery gate, or should the surface portal also exist as a fallback?

## 9. How to begin

Say: *"I read `docs/SESSION-HANDOFF.md`. Picking up Francis-opia — everything's committed at HEAD `49f14fe`; the latest van/friend changes are committed but not yet deployed. Want me to (1) have you deploy + verify on the Deck and fix what you see, (2) start House Slice 3 furniture, or (3) something else?"* Then wait — do NOT run Godot, and confirm before any `git` action.
