# Friends System — Architecture

> Status: **design, pre-build** (2026-06-13). Research-backed, pre-mortemed, VSDD/TDD-ready.
> Source of truth for the friends subsystem. Build sessions execute this; they do not redesign it.

## 1. Goal & Scope

Francis asked (verbatim): *"We need to add friends — friends will give quests and can
replace existing words. They will for example say: FOOD, HELP, or WATER, etc. if you spell
it for them and come back to them they will follow you."*

**Goal:** A data-driven friend NPC stands in the world, asks for a word (audio + image +
letter-slots), the friend's ask *replaces* the active target word, Francis spells it by
collecting letters, and on success the friend celebrates and becomes a **companion that
follows him** using the existing follow system.

**In scope:** friend NPC, the ask→spell→return→follow loop, `friends.json`, persistence.
**Out of scope (hard guards):** dialogue trees, branching choices, friendship levels/grind,
multiplayer, voice-acting, new word-bank. One ask at a time. No fail-states that punish.

## 2. First Principles — what a "friend" actually is

Decomposed against the engine, a friend is **not a new subsystem**. Every part already exists:

| Atomic part of "a friend" | Already provided by |
|---|---|
| Has a position / a body in the world | `CharacterBody2D` (same base as `Pet.gd`) |
| Emits a word to spell | `WordEngine` target word (needs a per-NPC override) |
| Validates the spelling | `WordEngine` → `Events.word_spelled_correctly(word)` (already fires) |
| Gives a quest | `QuestGenerator` `spell` template + `Events.quest_added` |
| Follows the player once earned | `Pet.gd` companion follow physics (reused as-is); friends keep their **own single active slot** — see §3 single-follower rule |
| Reveal / celebration juice | `MagicVFX` + `MagicSummon` reveal animation |

> **Key insight: a friend is a `Pet.gd` variant with a `PRE_FOLLOW` state prepended.** In
> `PRE_FOLLOW` it suppresses follow physics, shows its word ask, and overrides `WordEngine`.
> On the matching `word_spelled_correctly` **while the player is nearby**, it pops the override,
> closes its quest, and transitions to the inherited `FOLLOW` state. **~65 lines of new code
> plus one JSON file.** Most of this feature is *deletion of imagined work.*

**Genuinely new code (≈65 lines):**
1. `scripts/world/Friend.gd extends Pet.gd` — the `PRE_FOLLOW` state machine (~35 lines).
2. `WordEngine.set_override(word)` / `clear_override()` — a **single** override slot (invariant:
   depth ≤ 1; there is only ever one active ask) + an `active_friend_ask` lock (~15 lines). See
   the Override Contract in §5.
3. `scripts/autoload/FriendSpawner.gd` — reads `friends.json`, spawns the area's friend on
   `Events.area_changed`, registers its quest (~20 lines). Registered as an autoload.

**Pure composition / config (zero new code):** quest creation, follow behaviour, slot/send-home
management, notification display, reveal VFX, save plumbing shape.

## 3. The State Machine (explicit)

```
                 spawn (FriendSpawner, on area_changed)
                          │
                          ▼
   ┌────────────────  PRE_FOLLOW  ───────────────────────────────┐
   │  • follow physics OFF (stands at its spot)                   │
   │  • WordEngine.push_override(ask)  → its word shadows the area│
   │  • Events.show_notification(image+audio of ask word)         │
   │  • QuestGenerator registers a `spell` quest (source_npc=id)  │
   │  • after 8s idle near friend → highlight needed letter (hint)│
   └───────────────┬──────────────────────────────────────────────┘
                   │ word_spelled_correctly(ask) AND player within PROXIMITY_R
                   ▼
              CELEBRATE  (MagicVFX burst + friend reaction, ~0.6s)
                   │  • WordEngine.pop_override()
                   │  • Events.quest_completed(quest_id)
                   │  • GameManager.recruited_friends.append(id); save_game()
                   ▼
                FOLLOW   (inherited Pet.gd: leash + teleport-if-stuck)  ← only ONE friend here
                   │  • ACTIVE_FRIEND_CAP = 1: recruiting OR re-selecting any friend demotes the
                   │    current follower to WAIT_HERE first — never two friends following at once
                   │  • occasionally re-asks a word from its pool (replay; see §6 R-replay)
                   ▼
                WAIT_HERE  ("I'll wait for you here!" — stays put, never despawns)
                   │  • RE-SELECT: walk up to / tap a waiting recruited friend → it returns to
                   │    FOLLOW and the previous follower drops to WAIT_HERE (a clean swap)
                   └──────────────────────────► FOLLOW
```

**Single-active-follower rule (Francis's instruction):** at most **one** friend follows at any
moment (`GameManager.active_friend: String` holds the id, or "" for none). Recruiting a new
friend, or re-selecting an already-recruited one, makes *that* friend the active follower and
sends whoever was following to WAIT_HERE. This is a swap, not an eviction — no friend is ever
lost or despawned, and any old friend can be re-activated simply by selecting them again. This
single-slot pool is for friends specifically and is independent of word-summoned pets; if you
later want a global "only one companion of any kind" rule, it is a one-line change in the swap
check.

**Edge rules (from pre-mortem + advisor):**
- If `word_spelled_correctly` fires for the ask word but the player is *not* near the friend,
  the override still clears (the word was completed) but the friend is recruited at distance with
  a soft "thank you!" ping rather than failing — completion must never be lost.
- `area_changed` must NOT silently change the word during an active ask — see `active_friend_ask`
  lock (§5, FM-2) — but it DOES `clear_override()` if the player leaves the area entirely.
- **Single source of truth:** following is derived from `GameManager.active_friend` (the friend's
  id, or "" for none), never from per-node booleans — this is what makes "only one follows"
  impossible to desync.
- **Self-select is a no-op:** re-selecting the *currently active* friend does nothing (it must not
  demote the friend you just tapped). Define dismiss as a separate, explicit action if wanted.
- **Re-select precondition:** the swap applies only to friends already **recruited** (in
  `recruited_friends`). A friend whose word you haven't spelled yet cannot be made the follower.
- **WAIT_HERE position on reload:** waiting friends respawn at their area anchor (simplest; fine
  for age 5) — saved coordinates are out of scope.

## 4. Data model — `data/friends.json`

Mirrors the `words.json` contract (data-driven, hot-swappable, same load/staleness pattern).
Schema is deliberately wider than v1 needs, so content never forces code changes (pre-mortem FM-4):

```jsonc
{
  "version": "0.1.0",
  "friends": [
    {
      "id": "mossy",                 // unique key; used in save + prerequisite refs
      "name": "Mossy",               // spoken/displayed name
      "area": "meadow",              // where it can appear (matches words.json areas)
      "color": [0.4, 0.7, 0.4],      // placeholder tint until art exists
      "sprite": "mossy",             // optional summons-style sprite id (falls back to color)
      "asks": ["FOOD", "HELP"],      // word pool; first ask = asks[0], rest fuel replay re-asks
      "level": 1,                    // phonics gate (CVC=1) — cold-start friends MUST be level 1
      "reward_type": "companion",    // companion | cosmetic | unlock  (extensible)
      "reward": null,                // payload for cosmetic/unlock types; null for companion
      "prerequisite_id": null,       // null, or another friend's id that must be recruited first
      "follow": true                 // whether recruitment makes it follow (vs stay put)
    }
  ]
}
```

**Contract rules**
- Ask-words are a **curated, validated subset of the global word bank** — never free text. Each
  `asks[i]` MUST (a) exist in `words.json` with phonics so letters spawn + audio plays, AND (b)
  have a summon/reveal mapping in `MagicSummon` (or a defined generic reveal) so the reward
  celebration never breaks at runtime. Both are enforced by red tests (§9). Area-independence is
  fine (the friend supplies its own word); the *coverage* is what matters.
- The **first friend in the first area is level 1 (CVC) and a word Francis already knows** —
  this is the single highest-leverage decision (§6 LP1). Treat it as the tutorial friend.
- `reward_type` is bounded to **existing systems** — `companion` (Pet follow), `cosmetic`
  (existing summon cosmetic), or `unlock` (existing portal/area unlock). No new inventory stack.
  For the first build, `companion` only; `cosmetic`/`unlock` are schema-ready but deferred.
- Load order mirrors WordEngine: prefer `friends.json` if newer than any cache, else builtin
  emergency list of 1 tutorial friend. Never hard-fail to empty.

> **Pet vs friend coexistence:** the single-follower cap is **friends-only**. A word-summoned pet
> (e.g. spelling DOG) may still follow alongside the one active friend — that is intended. "Only
> one friend follows" governs the friend pool; it is not a global one-companion rule (making it
> global is a one-line change in the swap check if ever wanted).

## 5. Integration touch-points (files to change)

| File | Change | Why |
|---|---|---|
| `scripts/world/Friend.gd` *(new)* | `extends Pet.gd`; PRE_FOLLOW/CELEBRATE/FOLLOW/WAIT_HERE | the friend itself |
| `scripts/autoload/FriendSpawner.gd` *(new)* | read json, spawn on `area_changed`, register quest | data-driven spawning |
| `project.godot` | add `FriendSpawner` to `[autoload]` | activate spawner |
| `scripts/autoload/WordEngine.gd` | add `push_override`/`pop_override` + `active_friend_ask` lock | **word replacement** (Francis's ask) + FM-2 guard |
| `scripts/autoload/QuestGenerator.gd` | check `WordEngine.active_friend_ask` before issuing a quest; open-quest cap = 2 | FM-11 race + FM-3 attention |
| `scripts/autoload/GameManager.gd` | add `recruited_friends: Array[String]` **and `active_friend: String`** to save schema | FM-8 persistence + single-follower choice (day 1) |
| `scripts/world/Friend.gd` | own the swap: on recruit/RE-SELECT set `active_friend`, demote prior follower to WAIT_HERE | single-active-follower rule |
| `data/friends.json` *(new)* | friend definitions | content |
| `tests/test_friends.gd` *(new)* | red→green suite | TDD |
| `tests/run_tests.gd` | register `test_friends.gd` | run the suite |

**Word-replacement note (Francis's literal ask):** "replace existing words" is implemented as
`WordEngine.set_override(word)` — a **single** slot (NOT a stack; cap=1 means only one ask is
ever active) that shadows the area word; `clear_override()` restores normal area selection.
The `active_friend_ask` boolean blocks `area_changed` and `QuestGenerator` from overwriting the
friend's word mid-ask.

**Override Contract (must be in the build, with red tests):**
- **Invariant:** at most one override active at a time (depth ≤ 1). A swap *replaces* the slot, it
  does not stack. A "forgot to clear" leak = the area permanently demanding the friend's word.
- **`clear_override()` MUST fire on every one of:** (a) correct spell + recruit, (b) friend swap,
  (c) friend dismissed → WAIT_HERE, (d) `area_changed`, (e) save-load restore. Missing any one =
  stuck override.
- **Timing:** an override takes effect at the **next word boundary**, never mid-spell — it must not
  yank a word Francis is part-way through collecting.
- **Selection suppression:** while an override is active, area random/sequential word selection is
  suppressed and restored on clear (override and picker must not fight).

## 6. Systems analysis — loops & leverage

**Reinforcing loop R1 (the one we want):**
`read word → spell correctly → friend appears & follows → Francis shows Inta → pride → wants
another friend → reads next word`. Social reward amplifies intrinsic reading motivation.

**Balancing loops:** B1 single-follower swap (only one friend follows; picking another swaps —
keeps the screen calm for a 5yo and makes "who comes with me?" a real choice), B2 phonics difficulty
(level gate throttles runaway), B3 **attention drain** (too many open quests collapses R1 —
hence the open-quest cap of 2).

**Replay loop R-replay:** once recruited, a companion occasionally re-asks a word from its `asks`
pool ("I'm hungry — find me FOOD"), keeping the mechanic alive without friendship levels (FM-6).

**Leverage points (ranked):**
1. **LP1 — Guarantee the first friend.** Seed area 1 with one CVC word Francis already decodes,
   as a hardcoded tutorial friend. One success ignites R1. *If this is missed, nothing else
   matters.* **← single highest-leverage intervention.**
2. **LP2 — Followers stay visible & animated** (the "show Inta" moment is load-bearing reward).
3. **LP3 — Open-quest ceiling = 2** in QuestGenerator (prevents B3 collapse).
4. **LP4 — Phonics-fidelity gate:** recruitment requires correct *sequential* letter collection,
   never button-mashing into letters (FM-7), so skill actually transfers.
5. **LP5 — The swap as an emotional beat** — when a new friend joins, the previous one waves
   "I'll wait for you here!" and stays put; re-selecting it later brings it straight back. The
   single-follower limit reads as *choosing a buddy for the journey*, never as losing one.

## 7. Pre-mortem (imagined 6 months out, feature abandoned)

| # | Failure mode | Cat | Sev | Mitigation |
|---|---|---|---|---|
| FM-1 | Ask too hard → Francis quits cold | Child/UX | High | 8s-idle letter-highlight + audio nudge; first friend = known CVC; **playtest with a real 5yo before full build** |
| FM-2 | `area_changed` overwrites the friend's word → spelling does nothing | Tech | High | `active_friend_ask` lock blocks area/quest word changes until completion or dismiss; unit test fires area transition mid-ask |
| FM-3 | A friend silently despawns / two friends clutter the screen → child cries or confused | Child/UX | High | **Exactly one** active follower; recruiting/selecting another **swaps** (old one says "I'll wait here" and stays, never despawns); HUD shows the single active friend |
| FM-4 | `friends.json` too thin → every new friend needs code | Scope | Med | Schema carries `reward_type` + `prerequisite_id` from v1; draft 10 hypothetical friends before coding |
| FM-5 | 3 followers clip/teleport → looks broken | Tech | Med | Radial follow offset (index×angle around player) + max-speed clamp; stress-test 3 followers on cluttered map |
| FM-6 | Fun once, no replay | Scope | Med | R-replay: recruited friends re-ask from `asks` pool; no friendship grind |
| FM-7 | Social pull > reading → letter-mashing, accuracy drops | Pedagogy | Med | Require correct *sequential* collection (LP4); if session accuracy <70%, reduce ask frequency |
| FM-8 | Recruited friends don't persist across sessions | Tech | Med | `GameManager.recruited_friends` in save schema **day 1**; round-trip save/load test |
| FM-9 | Art gap → friends are colored boxes forever | Scope | Med | Minimum-art bar: each friend a unique silhouette before release; no plain rectangles in normal play |
| FM-10 | Non-reader has no "where do I go" | Child/UX | Low | Friend ambient audio ping at its name; idle particle trail toward nearest un-recruited friend |
| FM-11 | QuestGenerator double-ask race | Integration | Low | QuestGenerator checks `active_friend_ask` before issuing (one guard clause) + integration test |

**TOP 3 MUST-FIX BEFORE BUILD**
1. **FM-2 word-lock** — without the area-transition guard the core mechanic is broken by design.
   Write the lock and its test *first*.
2. **FM-1 cold-start** — playtest the first-friend recruitment with Francis (2h, watch where he
   sticks) before implementing the rest.
3. **FM-8 persistence** — `recruited_friends` in the save schema on day 1; retrofitting later is a
   refactor, doing it first is ~20 lines.

## 8. VSDD — vertical slices (each independently shippable & demoable)

Each slice cuts top-to-bottom (data → logic → on-screen behaviour) and is demoable to Francis.

- **Slice 1 — "A friend asks, I spell, it follows" (tutorial friend).**
  One hardcoded level-1 friend in the meadow. `friends.json` (1 entry) → `FriendSpawner` spawns it
  → `WordEngine.push_override` shows its word → spell it → `pop_override` + companion follow.
  Includes FM-2 lock + FM-8 persistence (the TOP-3 baked in). *Demo:* Francis recruits Mossy.
- **Slice 2 — "One buddy at a time, swap by re-selecting."** Multiple friends across areas, but
  `ACTIVE_FRIEND_CAP = 1`: recruiting or re-selecting a friend makes it the sole follower and the
  previous one walks to WAIT_HERE (FM-3). `GameManager.active_friend` persists the choice. HUD
  shows the one active friend. *Demo:* Francis has Mossy following, walks to Pip and picks him —
  Pip now follows, Mossy waits; Francis walks back to Mossy, picks him, and they swap back.
- **Slice 3 — "They keep asking" (replay + nudges).** R-replay re-asks (FM-6), open-quest cap = 2
  (FM-3/B3), 8s idle hint + ambient ping (FM-1/FM-10), accuracy gate (FM-7). *Demo:* a recruited
  friend asks for a new word days later; Francis is gently guided when stuck.
- **Slice 4 (optional) — "Rewards & gates."** `reward_type: cosmetic|unlock` + `prerequisite_id`
  chains. Only if content needs it; schema already supports it.

Build order: Slice 1 → 2 → 3. Do not start a slice until the previous one is green and demoed.

## 9. TDD — test plan (`tests/test_friends.gd`)

Headless GUT-style suite matching the existing `test_*.gd` pattern (`extends Node`,
`run_all_tests()`, `assert_true`). Authored **red first**; each maps to a behaviour above.
Engine run is a framework handoff (no Godot on mainframe).

| Test | Asserts | Guards |
|---|---|---|
| `test_friends_json_loads` | `friends.json` parses; ≥1 friend; required keys present | schema |
| `test_first_friend_is_level_1` | the tutorial/first friend's `level == 1` | LP1 / FM-1 |
| `test_asks_words_exist_in_wordbank` | every `asks[]` word exists in the word bank | data integrity |
| `test_asks_words_have_summon` | every `asks[]` word has a summon/reveal mapping (reward never breaks) | advisor #3 |
| `test_wordengine_set_clear_override` | `set_override` shadows target; `clear_override` restores; depth ≤ 1 | word replacement |
| `test_override_cleared_on_swap_and_abandon` | override clears on swap AND on dismiss/area-leave (no stuck override) | advisor #1 |
| `test_area_change_blocked_during_ask` | with `active_friend_ask=true`, area change does NOT change target | FM-2 |
| `test_questgen_respects_friend_lock` | QuestGenerator issues no quest while `active_friend_ask` | FM-11 |
| `test_open_quest_cap_two` | QuestGenerator never exceeds 2 open quests | FM-3/LP3 |
| `test_recruit_requires_proximity_or_completes_soft` | recruit on `word_spelled_correctly`; never lost | state machine |
| `test_recruited_friends_persist` | save → load round-trip keeps `recruited_friends` + `active_friend` | FM-8 |
| `test_only_one_active_friend` | recruiting/selecting a 2nd friend leaves exactly one following | single-follower rule |
| `test_reselect_old_friend_reactivates` | selecting a WAIT_HERE friend makes it the sole follower; **prior one demoted to WAIT_HERE** | swap |
| `test_reselect_active_friend_is_noop` | re-selecting the already-active friend does NOT demote it | advisor #2 |
| `test_friend_is_pet_subclass` | `Friend.gd` extends `Pet.gd` (composition, not duplication) | Anti-dup |

**Definition of done (per slice):** its tests green in `run_tests.gd`; demoed to Francis;
no plain rectangles visible (FM-9); the TOP-3 mitigations covered by tests.

## 10. References (research)

Cozy/companion mechanics — A Short Hike ([Shacknews](https://www.shacknews.com/article/127854/a-short-hike-review-a-slice-of-animal-life)),
Stardew companion mods ([Nexusmods](https://www.nexusmods.com/stardewvalley/mods/3175), [PCGamesN](https://www.pcgamesn.com/stardew-valley/stardew-squad-mod)),
Spiritfarer ([Indie Game Culture](https://indiegameculture.com/guides/spiritfarer-spirits-guide/)),
Ooblets follow/recruit ([Ooblets Wiki](https://ooblets.fandom.com/wiki/How_To_Play_Guide_For_Ooblets)),
Animal Crossing favors ([Nookipedia](https://nookipedia.com/wiki/Favor)),
Pokémon HGSS walking companion ([Screen Rant](https://screenrant.com/pokemon-yellow-best-feature-heartgold-soulsilver-follow-walking/)),
Yoshi's Island recovery-window ([Wikipedia](https://en.wikipedia.org/wiki/Yoshi%27s_Island)).

Early-literacy character design — Teach Your Monster to Read ([phonics.org](https://www.phonics.org/teach-your-monster-to-read-review/)),
Endless Alphabet ([Originator](https://www.originatorkids.com/endless-alphabet/)),
Khan Academy Kids ([characters](https://khankids.zendesk.com/hc/en-us/articles/360049358751-Learn-more-about-the-characters-inside-Khan-Academy-Kids)),
Duolingo ABC Elkonin boxes ([Common Sense](https://www.commonsensemedia.org/app-reviews/duolingo-abc-learn-to-read)),
Reading Eggs ([science](https://readingeggs.com/articles/science-behind-reading-eggs/)),
Sago Mini friendship-as-mechanic ([Common Sense](https://www.commonsensemedia.org/app-reviews/sago-mini-friends)),
characters-as-scaffolds + age-5 attention span (~10–15 min) ([PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC7818392/), [readykids](https://readykids.com.au/average-attention-span-by-age/)).

**Patterns adopted:** one-sentence spoken ask + icon; spell = recruitment gate (no grind);
conga/radial follow + teleport fallback; active-follower cap with visible slots; recovery window
not hard-fail; emotion bubble on tap; triple-layer word presentation (audio→image→letters);
letters announce their phoneme; celebration = the friend's reaction; collect-the-friend not a score.
**Patterns rejected:** friendship/heart grind, branching dialogue, no-waypoint naturalism, fail timers,
punishing errors, words before their phonemes are taught.
