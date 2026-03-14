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
| Shoot arrow | Left click | RT (Right trigger axis) |
| Interact | E | X (West) |
| Dig | Q | LB (Left bumper) |
| Toggle quest scroll | Tab | Y (North) |
| Pause | Escape | Start |

## Deploying to Steam Deck

### One-time Steam Deck setup

1. Switch to **Desktop Mode** (hold Power button, select Desktop Mode)
2. Open **Konsole** terminal
3. Set a password: `passwd`
4. Enable SSH: `sudo systemctl enable --now sshd`
5. Find your IP: `ip addr show` (look for wlan0 or eth0)

### One-time setup on your dev machine

1. Edit `deploy.sh` — set `DECK_HOST` to your Steam Deck's IP address (line 38)
2. Copy your SSH key: `ssh-copy-id deck@<STEAMDECK_IP>`
3. Install Godot export templates:
   - Godot Editor -> Editor menu -> Manage Export Templates -> Download
   - Or download from https://godotengine.org/download and place in `~/.local/share/godot/export_templates/4.6.1.stable/`

### Deploy (every time)

```bash
./deploy.sh              # Export + deploy to Steam Deck
./deploy.sh --export     # Export only (build the binary)
./deploy.sh --deploy     # Transfer only (skip export)
```

### Playing on Steam Deck

After deploying, add as a non-Steam game:

1. Open Steam -> Add a Game -> Add a Non-Steam Game -> Browse
2. Navigate to `/home/deck/Games/francisopia/francisopia.x86_64`
3. Add it — now it appears in your library with full controller support in Game Mode

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
│   └── words.json         # Word bank (word, level, area, image)
├── scenes/                # .tscn scene files
│   ├── main/Main.tscn
│   ├── player/Player.tscn
│   ├── reading/FloatingLetter.tscn
│   ├── world/Arrow.tscn, ArcheryTarget.tscn, LetterThief.tscn
│   └── ui/HUD.tscn, QuestScroll.tscn
└── scripts/               # GDScript source
    ├── autoload/          # Singletons (GameManager, WordEngine, InputHelper, AudioManager)
    ├── main/              # MainScene (world generation, chunk system)
    ├── player/            # PlayerController, BowController
    ├── reading/           # FloatingLetter, LetterSpawner, QuestGenerator
    ├── ui/                # HUDController, QuestScrollController
    └── world/             # LetterThief, TreasureChest, Arrow, ArcheryTarget
```
