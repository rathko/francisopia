# Controls

Input mapping for keyboard and gamepad.

## Current State

### Input Actions (`project.godot`)

| Action | Keyboard | Gamepad | Deadzone |
|--------|----------|---------|----------|
| `move_left` | A / Left Arrow | Left Stick X- / D-pad Left | 0.2 |
| `move_right` | D / Right Arrow | Left Stick X+ / D-pad Right | 0.2 |
| `jump` | Space | A Button (0) | 0.5 |
| `interact` | E | X Button (2) | 0.5 |
| `shoot` | Left Click | RT / Right Trigger (axis 5) | 0.5 |
| `toggle_scroll` | Tab | Y Button (3) | 0.5 |
| `pause` | Escape | Start / Menu (11) | 0.5 |
| `dig` | Q | LB / Left Shoulder (9) | 0.5 |

All actions have `device: -1` (respond to any controller).

### Input Helper (`InputHelper.gd`)
- Auto-detects keyboard vs gamepad from input events
- Emits `input_device_changed(device)` on switch
- Methods: `get_movement()`, `is_jumping()`, `is_shooting()`, etc.
- Aim: mouse position (keyboard) or right stick (gamepad)

### Per-Player Input (Multiplayer)
- Player 1: device 0 (first connected controller) or keyboard
- Player 2: device 1 (second controller)
- `PlayerController` reads per-device input via `Input.get_joy_axis(device, axis)`
- Keyboard always controls Player 1

### Aim System
- Priority: right stick > left stick > facing direction
- Aim snaps to 32px grid for block-aligned digging
- Visual dig cursor shows targeted block

## Known Issues

- All actions use `device: -1` which means both controllers trigger both players for non-axis inputs
- No rebinding UI
- Move deadzone (0.2) may be too sensitive for worn controllers
- No touch input support (potential for mobile/tablet port)

## Future Work

- Input rebinding in settings
- Touch controls for mobile
- Rumble/haptic feedback on dig, collect, summon
- Controller glyph display (show Xbox/PS icons based on connected device)
