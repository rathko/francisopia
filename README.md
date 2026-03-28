# Francis-opia

A cozy 2D exploration-platformer where words have magical power. Built in Godot 4.6 for a 5-year-old (Francis) to learn reading through play. Spell words and the things they name come to life.

**Target platform:** Steam Deck (Linux x86_64, 1280x800)
**Goal:** Steam release to help kids worldwide learn to read through play
**Art status:** Pixel art sprites for player, dog, cat, trees, flowers, crystals, mushrooms, castle. Ghibli-warm style.

## Documentation

| Doc | What |
|-----|------|
| [Roadmap](docs/roadmap.md) | Full project roadmap with phases, status, and design principles |
| [Sprite Architecture](docs/sprite-architecture.md) | Visual system, asset pipeline, animation, Kingdom learnings |
| [Procedural Generation](docs/procedural-generation-plan.md) | Terrain hills, biomes, world seed system |
| [Spelling & Words](docs/spelling.md) | Word magic system, letter collection, phonics |
| [Controls](docs/controls.md) | Gamepad + keyboard input mapping |
| [Save System](docs/save.md) | Seed+delta persistence model |
| [All Docs](docs/) | Full documentation index |

## Deploy to Steam Deck

Uses Tailscale for secure connectivity. No open SSH ports, works across any network.

### One-time: Steam Deck setup (~5 minutes)

Switch to **Desktop Mode** (hold Power button on Deck, select Desktop Mode), open **Konsole**.

1. **Install Tailscale** using [deck-tailscale](https://github.com/tailscale-dev/deck-tailscale) (handles SteamOS read-only filesystem, survives updates):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/tailscale-dev/deck-tailscale/main/install.sh | sh
   ```

2. **Authenticate and enable Tailscale SSH** (no sshd needed, no SSH keys to manage):
   ```bash
   sudo tailscale up --ssh --operator=deck
   sudo tailscale set --hostname=steamdeck
   ```
   This starts Tailscale with its built-in SSH server. The `tailscaled` daemon handles SSH
   on the Tailscale IP (100.x.x.x) using your Tailscale identity for auth. No OpenSSH sshd,
   no `ssh-copy-id`, no password setup needed.

3. **Disable key expiry** so the Deck stays authenticated forever:
   - Open [Tailscale admin console](https://login.tailscale.com/admin/machines) > Machines
   - Find the Steam Deck row, click the three-dot menu
   - Select "Disable key expiry"

   That's it. The Deck stays connected permanently. No re-authentication, no Desktop Mode
   visits. (WireGuard keys still rotate automatically for security.)

4. **Add Tailscale SSH ACL rule** (one-time, in [admin console ACLs](https://login.tailscale.com/admin/acls/file)):
   ```json
   "ssh": [
     {
       "action": "accept",
       "src": ["autogroup:member"],
       "dst": ["autogroup:self"],
       "users": ["deck"]
     }
   ]
   ```

5. **Install Godot export templates on your laptop** (if not already):
   ```bash
   # Option A: via Godot UI
   godot --path ~/src/pai/francisopia
   # Then: Editor menu -> Manage Export Templates -> Download

   # Option B: via CLI (no GUI needed)
   mkdir -p ~/.local/share/godot/export_templates/4.6.1.stable/
   cd ~/.local/share/godot/export_templates/4.6.1.stable/
   wget https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz
   unzip Godot_v4.6.1-stable_export_templates.tpz && mv templates/* . && rmdir templates && rm *.tpz
   ```

6. **Verify from your laptop:**
   ```bash
   ssh deck@steamdeck echo "connected"
   ```

**After SteamOS updates:** Tailscale login persists (stored in `/var/lib/tailscale/`), but you
may need to re-run the deck-tailscale installer if the sysext version no longer matches.
Just run step 1 again. Do not use `pacman -S tailscale` directly as SteamOS wipes pacman
installs on major updates.

### Deploy (every time)

```bash
./deploy.sh
```

That's it. Exports the game binary and rsyncs it to the Deck over Tailscale. Takes ~10 seconds.

First time on the Deck, add it as a non-Steam game:
- Steam -> Add a Game -> Add a Non-Steam Game -> Browse
- Path: `/home/deck/Games/francisopia/francisopia.x86_64`
- Now it shows in your library and works in Game Mode with full controller support

### Deploy options

```bash
./deploy.sh              # Export + deploy (normal workflow)
./deploy.sh --export     # Export only (build the binary)
./deploy.sh --deploy     # Transfer only (skip re-export)
```

### Alternative: Godot one-click deploy

Godot 4.1+ has built-in SSH remote deploy that exports, uploads, and launches the game
on the Deck with remote debugging attached. In the Godot editor:

1. Project > Export > Linux preset > Options tab > enable "SSH Remote Deploy"
2. Set Host to `deck@steamdeck`, leave port 22
3. Use the "Run on Remote" button in the editor toolbar

This works over Tailscale SSH. Note: use standalone Godot, not the Steam version
(Steam Runtime containerization can break SSH commands).

## Quick Start (local development)

```bash
# Run from Godot editor
godot --path ~/src/pai/francisopia

# Run game directly
godot --path ~/src/pai/francisopia --main-scene scenes/main/Main.tscn

# Run tests (headless)
godot --headless --path ~/src/pai/francisopia --script tests/run_tests.gd
```

## Core Loop

1. Target word appears on HUD (e.g., "CAT")
2. Explore the world, dig underground, open treasure chests to find letters
3. Collect letters in order (C, then A, then T) via the Interact button
4. Wrong letter = lose last collected letter + a Letter Thief spawns
5. Complete word = magic summoning animation + reward (pet, world object, coins)
6. Difficulty auto-increases after milestones (10/25/40/60 words)

## Controls

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Move | A/D or Arrows | Left Stick / D-Pad |
| Jump | Space | A (South) |
| Dig (hold) | Q | LB |
| Aim cursor | Movement dir | Right Stick |
| Shoot arrow | Left Click | RT |
| Interact | E | X (West) |
| Quest scroll | Tab | Y (North) |
| Pause | Escape | Start |

## Architecture

### Tech Stack

- **Engine:** Godot 4.6+ (GL Compatibility renderer)
- **Language:** GDScript (no external dependencies)
- **Data:** JSON word bank + Godot Resources (.tres)
- **Build:** Godot export pipeline, SSH deploy to Steam Deck

### Directory Layout

```
scenes/
  main/       MainScene.gd    Chunk generation, camera, input wiring
  player/     PlayerController.gd, WeaponHolder.gd, BowWeapon.gd
  reading/    FloatingLetter.gd, LetterSpawner.gd
  world/      TerrainBlock.gd, TreasureChest.gd, Arrow.gd, Pet.gd, LetterThief.gd
  ui/         HUDController.gd, PauseMenu.gd, QuestScrollController.gd

scripts/
  autoload/   Events, GameManager, WordEngine, AudioManager, InputHelper,
              QuestGenerator, MagicSummon (7 singletons)
  data/       WordEntry.gd, WordBank.gd

data/         words.json (61 words, 5 levels, 5 areas)
tests/        run_tests.gd + 4 test files
docs/         12 domain-specific design docs
```

### Autoload Singletons (load order)

1. **Events** - Central signal bus for cross-system communication
2. **GameManager** - Global state, save/load, coins, progression
3. **WordEngine** - Word selection, validation, difficulty progression
4. **AudioManager** - Audio playback (placeholder, no sounds yet)
5. **InputHelper** - Unified keyboard/gamepad abstraction
6. **QuestGenerator** - Template-based quest system
7. **MagicSummon** - Word-to-entity spawning with 5-phase animations

### Signal Flow (word completion example)

```
Player presses Interact near letter
  -> PlayerController._try_pick_letter()
    -> WordEngine.try_collect_letter()
      -> WordEngine.word_spelled_correctly.emit()
        -> GameManager.complete_word()        (coins + save)
        -> MagicSummon._on_word_spelled()     (summon animation)
        -> LetterSpawner._on_word_completed() (next word after 2s)
        -> HUDController._on_word_complete()  (celebration text)
```

### World Generation

- **Chunk-based:** 1280px wide chunks generated on demand, max 7 active
- **Block terrain:** 32px grid of StaticBody2D blocks (grass + 8 underground dirt rows)
- **Stairwells:** Deterministic zone-based placement every ~12 chunks
- **Cave Level 2:** Below bedrock, darker stone, richer treasure (10% vs 6%)
- **Decorations:** Platforms, trees, flowers, clouds, archery targets per chunk

### Persistence

- Auto-save every 2 minutes + on area change + on quit
- Atomic writes (temp file then rename) with one backup
- Location: `user://save.json`
- Saves: coins, words completed, quests, summoned entities, difficulty, equipped weapon

## Word Bank

61 words across 5 difficulty levels:
- **Level 1** (20 words): CVC - cat, dog, sun, hat, bed...
- **Level 2** (15 words): Blends - frog, tree, star, fish...
- **Level 3** (8 words): Long vowels - cake, moon, rain...
- **Level 4** (5 words): Complex - flower, castle, garden...
- **Level 5** (5 words): Advanced - rainbow, crystal, meadow...

Starter sequence: dog, sun, tree, rainbow (always plays first).

## What's Working

- Core spelling loop with letter collection and validation
- Terraria-style platformer movement (coyote time, wall jump, variable jump height)
- Block-based digging with aim cursor and treasure chests
- Infinite procedural world with chunk recycling
- Magic summoning (20+ word-to-entity mappings)
- Bow weapon with gravity arc arrows
- Letter Thieves (enemies scared by stomping or arrows)
- Quest system with template-based generation
- Local multiplayer (Player 2 auto-spawns with second controller)
- Pause menu with controls reference and restart option
- Save/load with backup recovery

## What's Not Done

- All art (sprites, textures, animations)
- All audio (music, SFX, phonics sounds)
- Area transitions (castle, beach, forest, mountain worlds)
- NPC characters and story
- Shop system
- Title/main menu screen
- Particle effects

## Design Documents

- `docs/` - 12 domain-specific docs (spelling, magic, player, world, terrain, etc.)
- `~/Obsidian/PAI/Francis-opia/` - Game design document, reading pedagogy, technical architecture
