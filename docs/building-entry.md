# Building Entry System (Future)

> How the player enters buildings (castle, cottage, shop) and sees interiors.

**Status:** Design spec. Not yet implemented.

## Concept

When the player stands near a building door and presses Interact (E / X button):
1. Camera zooms in slightly
2. Exterior walls fade to ~30% opacity (semi-transparent)
3. Interior becomes visible (furniture, fireplace, bed, items)
4. Player can walk around inside
5. Pressing Interact on the door again (or walking out) exits

## Visual Approach: Transparency Layering

```
OUTSIDE (normal):
  [Sky] [Terrain] [Building exterior at full opacity] [Player in front]

INSIDE (entered):
  [Sky] [Terrain] [Interior bg at full opacity] [Furniture] [Player] [Exterior walls at 30% opacity]
```

### How It Works in Godot

Each building has two visual layers:
- **Exterior layer** (roof, walls, door) -- z_index = -2, modulate alpha toggles
- **Interior layer** (floor, furniture, warm glow) -- z_index = -3, hidden by default

When entering:
```gdscript
func enter_building():
    exterior_sprite.modulate.a = 0.3   # Walls become see-through
    interior_node.visible = true        # Show interior
    _is_inside = true

func exit_building():
    exterior_sprite.modulate.a = 1.0   # Walls back to solid
    interior_node.visible = false       # Hide interior
    _is_inside = false
```

### Interaction Trigger

- Area2D at the door position with collision on layer 4 (interactable)
- Player's InteractArea detects overlap
- Pressing Interact while overlapping triggers enter/exit

### Interior Contents

| Building | Interior Features |
|----------|------------------|
| Castle (home) | Bed (save point), trophy wall (completed words), chest (inventory), mirror (change character) |
| Cottage/Inn | Fireplace, two chairs, small table, warm glow, quest board |
| Shop | Counter, item display shelves, shopkeeper NPC, OPEN/CLOSED sign |

### Castle Interior Progression

The castle interior grows as the player spells more words:
- 0 words: Empty room with bed
- 10 words: Trophy wall appears with word plaques
- 25 words: Bookshelf, chest
- 50 words: Full furnishing, decorative items

This provides visual progress feedback for reading achievement.

## Implementation Steps (Future Phase)

1. Create interior sprite for each building type
2. Add Area2D door trigger to building scenes
3. Implement enter/exit toggle in building script
4. Add transparency tween for smooth fade
5. Create interior furniture sprites
6. Wire trophy wall to GameManager.words_completed

## Kingdom Inspiration

Kingdom handles buildings differently (player never enters), but the transparency approach is used in games like:
- **Stardew Valley** (roof fades when player enters)
- **Zelda: Link to the Past** (separate interior rooms)
- **Terraria** (walls become transparent background)

For Francis-opia, the Stardew approach (fade exterior, show interior in-place) is simplest and maintains the side-scrolling perspective.
