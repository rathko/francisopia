# Testing

## Unit Tests

Headless GDScript tests. No display required.

```bash
godot --path . --headless --script tests/run_tests.gd
```

Test suites:
- `test_word_engine.gd` — word selection, letter collection, difficulty
- `test_quest_generator.gd` — quest generation, completion tracking
- `test_game_manager.gd` — save/load, coins, companions, progression
- `test_magic_summon.gd` — summon registry, companion activation
- `test_terrain_height.gd` — hill generation, stairwell flattening
- `test_input_system.gd` — input actions exist, joypad+keyboard bindings present

## Visual Smoke Test

`tests/smoke_test.sh` launches the game with a display, sends keyboard input (D key to move, Space to jump), takes screenshots at each step, and verifies the game doesn't crash.

### Quick Start

```bash
# From Radek's terminal (has display access):
./tests/smoke_test.sh

# From Claude's sandbox (needs display setup first):
./tests/smoke_test.sh --display :1
```

Screenshots are saved to `tests/screenshots/` (gitignored).

### Display Access for Claude User

Claude runs in a sandboxed user account and needs access to Radek's X11 display.

**One-time setup (managed by Ansible `--tags gaming`):**

1. Install xhost: `sudo pacman -S xorg-xhost`
2. Grant local access: `xhost +local:`
3. Share X auth cookie: `cp $XAUTHORITY /home/shared/xauth && chmod 644 /home/shared/xauth`
4. Fix socket permissions if needed: `sudo chmod 777 /tmp/.X11-unix/X1`

**Ansible automation:**

```bash
ans eos-install.yml --tags gaming
```

Deploys an autostart `.desktop` file that runs `xhost +local:` on every login. The xauth cookie copy and socket chmod are session-specific and must be done manually or scripted.

### Xvfb Mode (Virtual Display)

For headless CI or when no physical display is available:

```bash
./tests/smoke_test.sh --xvfb
```

**Requires nvidia-open-dkms <= 590.48.01.** The nvidia 595.58.03 driver (released 2026-03-28) introduced a regression that crashes Xvfb via `libnvidia-egl-gbm.so.1` during EGL initialization.

### nvidia Driver Compatibility

| nvidia-open-dkms | Xvfb  | Direct Display | Notes |
|------------------|-------|----------------|-------|
| 590.48.01        | Works | Works          | Last known good for Xvfb |
| 595.58.03        | Crash | Works          | Segfault in libnvidia-egl-gbm.so.1. Use --display instead. |

**Downgrade command** (if Xvfb is needed):
```bash
sudo pacman -U /var/cache/pacman/pkg/nvidia-open-dkms-590.48.01-*.pkg.tar.zst
```

**Environment variables used for software rendering:**
```bash
__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
__GLX_VENDOR_LIBRARY_NAME=mesa
LIBGL_ALWAYS_SOFTWARE=1
MESA_GL_VERSION_OVERRIDE=3.3
```

### What the Smoke Test Verifies

1. **Startup** — Godot loads without script parse errors, game scene initializes
2. **Movement** — D key input is received and processed (action system path)
3. **Jump** — Space key input works
4. **Stability** — Game doesn't crash during 10+ seconds of gameplay
5. **Rendering** — Screenshots are non-blank (> 1KB)

### Steam Deck Input Testing

The smoke test uses keyboard input via `xdotool`, which tests the Godot input action system path. Gamepad input (Steam Deck's built-in controls) can only be tested on the actual device.

Key input architecture decisions (see `PlayerController.gd`):
- Player 0 checks Godot input actions FIRST (works with any device via `device: -1`)
- Direct `Input.get_joy_axis()` is a secondary path for Player 0, primary for Player 2+
- Joy button "just pressed" states are cached once per physics frame to prevent double-consumption
