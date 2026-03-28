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
| `next_weapon` | R | RB / Right Shoulder (10) | 0.5 |

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

### Input Priority (Steam Deck Fix)

For Player 0, all input helpers check the Godot **action system first** (e.g. `Input.is_action_just_pressed("jump")`), then fall back to direct joy API (`Input.is_joy_button_pressed()`). This ensures Steam Input's virtual gamepad works regardless of how Steam presents the controls (gamepad events, keyboard translation, etc.).

For Player 2+, direct joy API is the primary path since actions use `device: -1` and can't distinguish controllers.

### Joy Button Cache

`_joy_button_just_pressed()` results are computed **once per physics frame** in `_update_joy_button_cache()` and stored in a dictionary. Multiple handlers reading the same button in one frame get the same result. This prevents the old bug where `_handle_jump_buffer()` consumed the "just pressed" state before `_handle_wall_jump()` could see it.

## Known Issues

- All actions use `device: -1` which means both controllers trigger both players for non-axis inputs
- No rebinding UI
- Move deadzone (0.2) may be too sensitive for worn controllers
- No touch input support (potential for mobile/tablet port)
- Steam Deck: if controller layout is set to "Desktop" instead of "Gamepad", stick maps to mouse movement (unfixable in code — user must change layout)

## Future Work

- Input rebinding in settings
- Touch controls for mobile
- Rumble/haptic feedback on dig, collect, summon
- Controller glyph display (show Xbox/PS icons based on connected device)
