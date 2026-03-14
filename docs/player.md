# Player System

Platformer character controller with local multiplayer support.

## Current State

### Movement (`PlayerController.gd`)
- CharacterBody2D with `move_and_slide()`
- Speed: 200 px/s horizontal
- Jump velocity: -350 px/s (upward)
- Gravity: default Godot gravity * 1.0 multiplier
- Fall speed capped at 600 px/s
- Sprite flips based on facing direction

### Jump Mechanics
- Variable height: release jump early for short hop, hold for full arc
- Coyote time: 0.15s grace period after walking off edge
- Jump buffer: 0.1s — press jump just before landing, still registers

### Wall Mechanics
- Wall slide: touching a wall while falling slows descent to 60 px/s
- Wall jump: press jump while wall sliding to kick off with velocity boost
- Wall detection via `move_and_slide()` collision normals

### Respawn
- Falls below Y=1200 triggers respawn
- Teleports to last recorded safe ground position
- Velocity resets to zero

### Archery (`BowController.gd`)
- Shoot: left click (mouse) or RT (gamepad)
- Aim direction from PlayerController's device-specific aim
- Arrow speed: 500 px/s
- Arrow lifetime: 3s auto-cleanup
- 0.5s cooldown between shots
- Arrows call `hit_by_arrow()` on impact targets

### Letter Collection
- LetterDetector: Area2D with 40px radius around player
- Contacts FloatingLetter Area2D nodes
- Deferred handling (`call_deferred`) to avoid physics flush errors
- Correct letter: collect animation + sound
- Wrong letter: rejection bounce + LetterThief spawn

### Interaction
- InteractArea: Area2D with 50px radius
- E/X button triggers `interact()` on nearby interactable nodes
- Used for treasure chests, future NPCs

### Local Multiplayer
- Player 1 (index 0): blue color, always present
- Player 2 (index 1): red-orange, spawns when 2nd controller detected
- Per-player device input via `Input.get_joy_axis(device, axis)`
- PlayerLabel shows "P1" / "P2" above character head
- Midpoint camera centers between both players with dynamic zoom (0.6-1.2x)

### Visual Design
- ColorRect body (32x48) + head (20x14)
- Color tinted per player
- BodyColor and HeadColor child nodes

## Known Issues

- Player 2 removal on controller disconnect doesn't clean up midpoint camera
- No animation states (idle, run, jump, dig) — just sprite flip
- Dig cursor visible even when not holding dig button in some edge cases
- Wall jump direction sometimes sends player into the wall instead of away

## Future Work

- Character selection screen (Francis's idea: "choose a character")
- Level up and skill selection (Francis's idea)
- Prince character role (Francis's idea)
- Swimming mechanic for beach areas
- Climbing mechanic for mountain areas
- Animation sprites to replace ColorRects
