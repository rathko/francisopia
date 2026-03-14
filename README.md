# Francis-opia

A cozy 2D exploration-platformer where words have magical power. Designed for Francis (age 5) to learn reading through play.

## Prerequisites

```bash
# Arch Linux
sudo pacman -S godot
```

## Running

```bash
# Open in Godot editor
godot project.godot

# Run game directly
godot --path . --main-scene scenes/main/Main.tscn

# Run tests (headless)
godot --headless --script tests/run_tests.gd
```

## Controls

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Move | WASD / Arrows | Left Stick / D-Pad |
| Jump | Space | A |
| Interact | E | X |
| Shoot | Left Click | RT |
| Quest Scroll | Tab | Y |
| Pause | Escape | Start |

## Project Structure

See `~/Obsidian/PAI/Francis-opia/Technical-Architecture.md` for full details.

## Design Documents

All game design documentation lives in Obsidian:
- `~/Obsidian/PAI/Francis-opia/Game-Design-Document.md`
- `~/Obsidian/PAI/Francis-opia/Reading-Pedagogy.md`
- `~/Obsidian/PAI/Francis-opia/Technical-Architecture.md`
