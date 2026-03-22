# Francis-opia Setup

## Requirements

- Godot 4.6+ (tested with 4.6.1)
- Linux x86_64 (primary target: Steam Deck)
- Keyboard or gamepad

## Running Locally

```bash
cd ~/src/pai/francisopia
./run.sh
```

`run.sh` handles display server detection (Xwayland auth) and launches Godot with log capture to `godot.log`.

If running from a graphical desktop directly:

```bash
godot --path ~/src/pai/francisopia
```

## Controls

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Move | A/D or Arrow keys | Left stick / D-pad |
| Jump | Space | A (South) |
| Shoot / Use weapon | Left click | RT (Right trigger axis) |
| Interact | E | X (West) |
| Dig | Q | LB (Left bumper) |
| Cycle weapon | R | RB (Right bumper) |
| Toggle quest scroll | Tab | Y (North) |
| Pause | Escape | Start |

## Deploying to Steam Deck

Deploys use **Tailscale** for secure connectivity. SSH only listens on the Tailscale interface, never on WiFi. See `README.md` "Deploy to Steam Deck" for full setup steps.

### Quick reference

```bash
./deploy.sh              # Export + deploy to Steam Deck
./deploy.sh --export     # Export only (build the binary)
./deploy.sh --deploy     # Transfer only (skip re-export)
```

### Playing on Steam Deck

First time only, add as a non-Steam game:

1. Open Steam -> Add a Game -> Add a Non-Steam Game -> Browse
2. Navigate to `/home/deck/Games/francisopia/francisopia.x86_64`
3. Add it. Now it appears in your library and works in Game Mode with full controller support.

Or run from Desktop Mode terminal:

```bash
/home/deck/Games/francisopia/francisopia.x86_64
```

## Project Structure

```
francisopia/
├── project.godot          # Engine config, autoloads, input mappings
├── run.sh                 # Local launch script (display env handling)
├── deploy.sh              # Steam Deck deploy pipeline
├── export_presets.cfg     # Godot export preset (Linux x86_64)
├── data/
│   ├── words.json         # Word bank (JSON authoring format)
│   └── words/word_bank.tres  # Word bank (Godot Resource, auto-generated)
├── scenes/                # .tscn + co-located .gd scripts
│   ├── main/              # Main.tscn, MainScene.gd
│   ├── player/            # Player.tscn, PlayerController.gd, WeaponHolder.gd, BowWeapon.gd
│   ├── reading/           # FloatingLetter.tscn/.gd, LetterSpawner.gd
│   ├── world/             # Arrow.tscn/.gd, ArcheryTarget, LetterThief, Pet, TerrainBlock, etc.
│   └── ui/                # HUD.tscn, HUDController.gd, PauseMenu, QuestScroll
├── scripts/               # Non-scene scripts
│   ├── autoload/          # Singletons: Events, GameManager, WordEngine, AudioManager, InputHelper, QuestGenerator, MagicSummon
│   └── data/              # WordEntry.gd, WordBank.gd (Resource classes)
└── tools/                 # One-time scripts (import_words.gd)
```
