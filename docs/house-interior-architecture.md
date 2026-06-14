# House Interior — Architecture

> Status: **design, pre-build** (2026-06-14). Research-backed, pre-mortemed, VSDD/TDD-ready.
> Source of truth for the enterable house. Build sessions execute this; they do not redesign it.

## 1. Goal & Scope

Francis stands at his house door, presses the action button, and **enters his house** — a
side-scrolling interior in the same warm pixel style. Inside: a living room with stairs near the
entrance, an **exit door on the left**, and the house **grows to the right** as he collects more.
**Every animal he has spelled lives in its own little room**; he walks up to one and chooses to
**take it with him** (active group, **max 3**) or **leave it home**. Furniture/trophies (BED, LAMP,
NUT, …) **auto-appear** inside as he spells those words. It starts mostly empty and **fills over
time**. **No digging** inside.

**In scope:** enter/exit, interior level, animal rooms + take/leave with the 3-cap, dynamic
rightward growth, auto-placed furniture/trophies, navigation for a growing house, save model.
**Out of scope (v1):** a real upstairs (stairs are visual in v1 — see §11), house *cosmetic*
customization, decorating menus, multiple houses, multiplayer-2 splitting across rooms.

## 2. First Principles — the house is mostly things we already have

| "House" part | Already provided by |
|---|---|
| The interior "level" | `current_level` drives world generation; `_regenerate_all_chunks()` rebuilds it. An interior is a **reserved level index** with a non-procedural layout. **No new scene.** |
| Enter / exit | Interact system: `collision_layer 4` + `interact()` + the "interact" action (the door). Same as existing teleport pads / stairwells. |
| Animals living at home | `MagicSummon._send_companion_home()` already parks idle companions at the house position. The interior just *renders* that fact as rooms. |
| The 3-active cap | `GameManager.active_companions` (max 3) + evict-oldest already exist. "Take/leave" calls the same add/remove. |
| Furniture from words | World-summon words (bed, lamp, hut…) already spawn persistent objects. Indoors = the same spawn at a fixed room anchor, gated on `words_completed`. |
| Persistence | `GameManager` already saves `words_completed`, `active_companions`, `items_owned`. |

> **Key insight:** The house interior is `current_level = HOUSE_LEVEL` with a hand-authored layout,
> and the **only genuinely new primitive is a per-animal STATE** (see §3). Everything else —
> transitions, cap, send-home, save, furniture spawn — already exists. Estimated genuinely-new
> code: ~150–200 lines + a small data table.

**Genuinely new:** (1) `HOUSE_LEVEL` interior generator (static rooms, no terrain/dig); (2) the
companion **STATE model** + save fields; (3) `HouseRoom` / `RoomAnimal` interactables (take/leave);
(4) furniture auto-placement table; (5) navigation aid (minimap strip + call-to-entrance).

## 3. The companion STATE model — THE load-bearing decision (do this first)

Every animal Francis has spelled has **exactly one** state (single source of truth, in `GameManager`):

```
enum AnimalState { FOLLOWING, HOME }
# FOLLOWING = in the active group (HARD cap 3), walks with Francis everywhere.
# HOME      = lives in its room; rendered in the room when Francis is inside.
var animal_state: Dictionary = {}   # "dog" -> "following" | "home"   (persisted)
var room_index:   Dictionary = {}   # "dog" -> 2   (assigned once, NEVER changes; persisted)
```

This **single enum kills the worst bugs** (pre-mortem TOP-4): no animal can be both following *and*
in its room (no duplication), and load can validate it.

**Invariants (enforced + tested):**
- An animal is in **exactly one** state.
- `count(FOLLOWING) <= 3` — always. Load **clamps** (demote extras to HOME, log).
- When Francis is **inside**: a FOLLOWING animal's room shows an **"out with Francis" placeholder**
  (empty bed + a little note), NOT the animal. The animal is physically with him.
- `active_companions` becomes a *derived view* (`[w for w,s in animal_state if s==following]`) or is
  kept in lockstep — pick one writer. Recommended: `animal_state` is the writer; `active_companions`
  is regenerated from it (keeps existing follow code working).

## 4. Enter / exit + the interior level

- **Door (enter):** the house's outdoor structure carries a door collider on `collision_layer 4`
  with `interact()`. When Francis's `InteractArea` overlaps and he presses action → a HUD prompt
  ("🏠 Enter") shows; pressing enters. *(User asked for an action item, not auto-enter.)* Enter =
  save outdoor position → `current_level = HOUSE_LEVEL` → fade → `_regenerate_all_chunks()` builds
  the interior → spawn Francis at the interior entrance (left). **Followers come WITH him** (they are
  FOLLOWING; they re-parent/teleport into the interior next to him — never left outside).
- **Exit (left door):** a clearly-distinct glowing door at the **far left** of the interior, plus a
  **persistent HUD "← Go Outside" button always visible indoors** (pre-mortem #2). interact() → fade
  → restore `current_level` to the overworld → spawn Francis at the saved house outdoor position.
- **No digging indoors:** the dig action is gated `if current_level == HOUSE_LEVEL: return` in the
  player dig handler. Interior floor is solid, non-diggable tiles.
- **Preload** the interior to avoid first-enter stutter (`ResourceLoader.load_threaded_request`
  pattern is moot here since it's same-scene; just pre-build the room template once).

## 5. Rooms & dynamic rightward growth

- **Layout:** Room 0 = **living room** (entrance, stairs, exit door, seed furniture). Rooms 1..N to
  the **right**, one per animal, in **`room_index` order**. A short doorway/arch separates rooms.
- **Deterministic, permanent index:** the first time an animal is summoned it is assigned the next
  free `room_index` (persisted). **It never reshuffles** (pre-mortem #10) — Cat is always in the same
  room across sessions.
- **Fill before expand** (systems L5): furniture/animals pack a room before a new room opens — keeps
  the house navigable and each room earned.
- **Ghost rooms** (research): the next 1–2 not-yet-earned rooms show as dim outlined shells with a "?"
  — telegraphs "more is coming," so an early house never reads as broken/empty (pre-mortem #6).
- **Width cap + wing** (systems L1, pre-mortem #1/#9): visible house caps at ~8 rooms; beyond that,
  a labelled "deeper wing" door fast-travels — never a 45-second empty walk.

## 6. Take / leave + the 3-cap (NO silent eviction)

- **Take a HOME animal:** interact on it → if group `< 3`: it joins (state→FOLLOWING), walks out with
  a happy animation; the room shows the "out with Francis" placeholder.
- **Group already full (3):** **never silently evict** (pre-mortem #4, the single most trust-breaking
  bug). Instead show a **friendly icon choice**: the 3 current animals' portraits + "who goes home?"
  Francis taps one → it walks back to its room (state→HOME), the new one joins. All icon/animation,
  **no text** (5yo can't read).
- **Leave an animal:** interact on a FOLLOWING animal (in the world or its placeholder) → "leave
  here" → state→HOME, it trots to its room. A wave-goodbye / curl-up micro-animation (research
  pattern 7) makes the cap feel fair, not punishing.
- Cap enforcement is the **existing** `active_companions` logic; this is UI on top of it.

## 7. Furniture & trophies (auto-placed, no menus)

- **Mapping:** a curated table maps world-object words → an interior prop + a target room + anchor
  slot. `BED → bed (living room, floor-right)`, `LAMP → lamp (living room, wall)`,
  `NUT → acorn trophy (wall plaque)`, `LOG → stool`, `TREE → potted plant`, etc.
- **Auto-placement only** (research: every successful game auto-places for young players; menus kill
  it). On spelling the word outside, the prop is queued; it appears next time Francis enters (or pops
  in if he's inside).
- **Fixed slots, no overlap** (pre-mortem #7): each room has predefined anchors (floor-left,
  floor-right, wall-A, wall-B; **max ~4 props/room**). Fill in order; overflow spills to the next
  room. No free placement, no collisions.
- **Functional > plaque where cheap** (research pattern 4): BED → tap to rest (z-z animation); LAMP →
  glows and warms the room; others → wall trophies. Each prop shows the **word that earned it** on a
  small label (literacy reinforcement, pre-mortem #14).
- **Ghost silhouettes** for not-yet-spelled furniture in the living room — the empty house is a
  *promise*, not a void (research; pre-mortem #6).

## 8. Navigation — the highest-leverage system (systems L1)

A growing house dies to the "endless corridor" (pre-mortem #1) unless navigation is solved up front:
- **Room minimap strip** at the top: a row of animal portraits = room markers; the current room is
  highlighted.
- **Call-to-entrance verb:** from the entrance, action opens a portrait picker → tap an animal → it
  **runs to the entrance** (or Francis warps to its room). One button, no walking the whole house.
- This is **build-it-before-launch** — without it the core loop stalls once the house is wide.

## 9. Empty-house seeding & "this is inside" signal

- **Seed** room 0 as a cozy living room from day 1 (rug, window light, a toy box, ghost furniture
  outlines) so the very first visit is warm, not a grey box (systems L2, pre-mortem #6).
- **Distinct interior visual** (pre-mortem #11): warmer palette, visible ceiling + wallpaper, indoor
  lighting, and a persistent friendly header "**Francis's House**". Exit door and room doorways are
  **unmistakably different shapes/colors**.

## 10. Save model & desync prevention (pre-mortem #5 — do early)

Add to `GameManager` (persisted): `animal_state` (word→following/home), `room_index` (word→int),
`interior_props` (word→placed bool), `next_room_index` (int), `house_outdoor_x/y` (return point).

**Load validation (single source, clamped):**
- Rebuild `active_companions` from `animal_state` (following only); if `count(following) > 3`, demote
  the newest extras to HOME and log.
- An animal missing from `animal_state` but present in `words_completed` defaults to HOME and gets a
  `room_index`.
- Room spawn checks `animal_state[w] == home` before instantiating a room animal (prevents the
  follow+room duplication, pre-mortem #3).

## 11. Stairs

Stairs are in the living room because the user asked for them. **v1: visual only**, drawn as
*background* so they carry **no false "interactable" affordance** (pre-mortem #8 — never a thing that
looks usable but isn't). **Deferred slice:** a real (initially-empty) **upstairs trophy hall** that
fills with wall trophies — that gives the stairs a real destination. Until built, no climb prompt.

## 12. Edge cases (from the pre-mortem — all 14 have mitigations above)

TOP-4 MUST-FIX before build (non-negotiable, baked into Slice 1–2):
1. **Companion STATE on transition** (§3) — define the enum + the FOLLOWING→placeholder rule before
   any house code. Prevents duplication/soft-lock.
2. **No silent eviction** (§6) — the "who goes home?" icon choice is mandatory.
3. **Always-visible exit** (§4) — HUD "Go Outside" + a distinct left door in the first prototype.
4. **Save desync prevention** (§10) — single state map + load-time clamp before any content work.

Also covered: dual-presence (#3), why-did-cat-leave (#4), layout reshuffle (#10), furniture overlap
(#7), sad empty house (#6), stairs-to-nowhere (#8), performance at 30+ animals (#12 → stream/free
rooms >3 screens away, cap ~15 loaded nodes), trophy-without-memory (#14 → word labels).

## 13. Integration touch-points (files to change)

| File | Change |
|---|---|
| `scripts/autoload/GameManager.gd` | add `animal_state`, `room_index`, `interior_props`, `next_room_index`, `house_outdoor_x/y` + save/load + **load validation** |
| `scenes/main/MainScene.gd` | `HOUSE_LEVEL` branch in the level generator → `_generate_interior()`; enter/exit triggers; minimap strip; furniture auto-placement; room streaming |
| `scripts/autoload/MagicSummon.gd` | `_send_companion_home` / `activate_companion` write through `animal_state`; expose take/leave helpers |
| `scenes/player/PlayerController.gd` | gate dig when `current_level == HOUSE_LEVEL`; door interact prompt |
| `scenes/world/HouseDoor.gd` *(new)* | door interactable (enter); left exit door interactable |
| `scenes/world/RoomAnimal.gd` *(new)* | per-room animal interactable → take/leave + the cap choice UI |
| `data/house_props.json` *(new)* | word → {prop, room, anchor} furniture/trophy table |
| `tests/test_house.gd` *(new)* | state-enum + save-validation + room-index tests |

## 14. VSDD — vertical slices (each shippable + demoable)

- **Slice 1 — "Enter and leave."** HOUSE_LEVEL interior, living room, enter via door action, exit via
  left door + HUD button, no digging, followers come in/out intact. Includes the **STATE enum** +
  **save validation** (TOP-4 #1,#3,#4). *Demo:* Francis walks in, looks around, walks out, group
  unchanged.
- **Slice 2 — "My animals live here."** One room per HOME animal (deterministic index), take/leave,
  the 3-cap **"who goes home?"** choice, FOLLOWING→placeholder. (TOP-4 #2.) *Demo:* take Cat, group
  full → pick who leaves; re-enter, layout identical.
- **Slice 3 — "The house fills up."** Furniture/trophy auto-placement from `house_props.json`, fixed
  slots, ghost silhouettes, seeded living room, word labels. *Demo:* spell BED/LAMP → they appear
  inside.
- **Slice 4 — "Find anyone fast."** Minimap strip + call-to-entrance, width cap + wing, growth
  polish. *Demo:* with 10 animals, call Bunny in one tap.
- **Slice 5 (deferred) — "Upstairs."** Real upstairs trophy hall via the stairs.

Build order 1→2→3→4. Do not start a slice until the previous is green + demoed.

## 15. TDD — test plan (`tests/test_house.gd`)

| Test | Asserts |
|---|---|
| `test_animal_in_exactly_one_state` | every spelled animal is FOLLOWING xor HOME |
| `test_following_cap_three` | `count(following) <= 3` always; taking a 4th requires a leave |
| `test_load_clamps_following` | save with 4 following → load demotes to 3, no crash |
| `test_room_index_stable` | an animal's `room_index` never changes across re-entry |
| `test_no_duplicate_on_enter` | a FOLLOWING animal does NOT also spawn in its room |
| `test_exit_returns_to_house_pos` | exiting restores the saved outdoor position + overworld level |
| `test_no_dig_in_house` | dig is a no-op when `current_level == HOUSE_LEVEL` |
| `test_furniture_slots_no_overlap` | props fill fixed anchors; overflow spills, never stacks |
| `test_props_gated_on_completed` | a prop only places if its word ∈ `words_completed` |
| `test_state_persists_roundtrip` | save→load preserves who-follows + who-is-home + props |

**Definition of done (per slice):** its tests green in `run_tests.gd`; demoed to Francis; TOP-4
mitigations covered by tests; no silent group changes from any transition.

## 16. References (research)

Enterable interiors — Stardew Valley ([wiki](https://stardewvalleywiki.com/Farmhouse)), Pokémon warp
tiles ([Essentials](https://essentialsdocs.fandom.com/wiki/Map_transfers)), Terraria cross-section
([wiki](https://terraria.wiki.gg/wiki/House)), Zelda Link's Awakening
([Retro Reversing](https://www.retroreversing.com/zelda-links-awakening-art-workspace)), Animal
Crossing ([Nookipedia](https://nookipedia.com/wiki/House_customization)), A Short Hike side-view
interiors ([breakdown](https://alexiamandeville.medium.com/game-design-breakdown-a-short-hike-5a7a17d740e5)),
Spiritfarer ([ship guide](https://www.switchbladegaming.com/cozy-games/spiritfarer-ship-guide/)).
Companion housing + party swap — Pokémon boxes ([Bulbapedia](https://bulbapedia.bulbagarden.net/wiki/Pok%C3%A9mon_Storage_System)),
Ooblets Oobcoop ([The Gamer](https://www.thegamer.com/ooblets-how-to-build-upgrade-use-oobcoops/)),
Stardew animals ([wiki](https://stardewvalleywiki.com/Animals)), Slime Rancher corrals, Nintendogs
3-in-house + hotel ([wiki](https://nintendogs.fandom.com/wiki/Kennel)), Spiritfarer one-room-per-spirit.
Collect→display + growth — AC museum auto-display ([Nookipedia](https://nookipedia.com/wiki/Museum)),
Viva Piñata garden color-unlock, Spiritfarer rightward boat growth
([wiki](https://spiritfarer.fandom.com/wiki/Boat_Buildings)), Terraria banners/trophies
([wiki](https://terraria.wiki.gg/wiki/Banners_(enemy))), and the "empty house reads as sad" warning
([Screen Rant](https://screenrant.com/spiritfarer-empty-house-depressing-stella-everdoor-spirit-flower/)).

**Patterns adopted:** reserved-level interior (no new scene); single STATE enum as source of truth;
action-to-enter + always-visible exit; one room per animal, deterministic index; walk-up + one-button
take/leave; **no silent eviction** (icon choice); auto-placed furniture in fixed slots; ghost
silhouettes; seeded cozy living room; minimap + call-to-entrance for a growing house; cumulative-only
growth; word labels on trophies. **Rejected:** decorating menus, free placement (Spiritfarer Tetris),
text prompts for a 5yo, silent caps, procedural interior generation, layout reshuffling.
