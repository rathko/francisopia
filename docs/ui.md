# UI System

All user interface elements. CanvasLayer-based, camera-independent.

## Current State

### HUD (`HUDController.gd`, layer 10)
- **Hint label** (top center): "Spell: CAT ~ cat" with summon type emoji and color
  - Font size 40, colored by summon type
  - Position: centered at Y=12
- **Word display** (below hint): HBoxContainer with letter slot Labels
  - Each slot: 48pt, underscore when empty, letter when collected
  - Collected letters colored by summon type (green fallback)
  - Scale pulse animation on collect (1.0 > 1.3 > 1.0)
  - Dark semi-transparent background panel for contrast
  - Position: centered at Y=60
- **Coin counter** (top left): "coins" icon + count at 32pt
- On word complete: all letter slots pulse with summon color

### MagicSummon Safety
- HUD caches MagicSummon via `get_node_or_null("/root/MagicSummon")`
- All MagicSummon calls guarded with `if _magic_summon:`
- Falls back to default colors (warm white, green) if MagicSummon unavailable

### Pause Menu (`PauseMenu.gd`, layer 100)
- Toggle: Escape (keyboard) / Start (gamepad)
- `process_mode = PROCESS_MODE_ALWAYS` (works while paused)
- Dark overlay + centered 700x500 panel with rounded corners
- **Main page**: title, Controls button, Resume button
- **Controls page**: two-column layout
  - Keyboard column: A/D, Space, Q, E, Tab, Escape
  - Controller column: Left Stick, A, LB, Right Stick, RT, X, Y, Start
  - 4 gameplay tips at bottom
- Button styling: dark blue normal, lighter hover, yellow focus border
- Auto-focus first button for gamepad navigation

### Quest Scroll (`QuestScrollController.gd`)
- Toggle: Tab / Y button
- Slide-in panel from right
- Quest list with large readable text
- Completed quests grayed out

## Scene Hierarchy

```
HUD (CanvasLayer, layer 10)
  TopBar (HBoxContainer)
  HintLabel (Label)
  WordDisplay (HBoxContainer)
  CoinIcon (Label)
  CoinLabel (Label)

PauseMenu (CanvasLayer, layer 100)
  [built programmatically in _build_ui()]

QuestScroll (CanvasLayer)
  [built programmatically]
```

## Known Issues

- Word display dark background is positioned with absolute offsets — may misalign on different resolutions
- No font specified (uses Godot default) — should use child-friendly font like Fredoka One
- Coin icon is just the text "coins" — needs proper icon
- HUD elements may overlap at narrow viewports or with zoom changes
- No transition animations on pause menu open/close

## Future Work

- Custom font (Fredoka One or similar sans-serif)
- Health/stamina bars (if combat expands)
- Minimap for larger world exploration
- Settings menu (volume, difficulty, language)
- Title screen / main menu
- Character selection screen
- Shop UI (from Francis's castle shop idea)
