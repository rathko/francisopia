# Quest System

Dynamic quest generation and tracking.

## Current State

### Quest Generator (`QuestGenerator.gd`)
- Autoload singleton with template-based quest creation
- Generates 3 quests per area on area load
- Connects to `GameManager.word_completed` to auto-complete spell quests

### Quest Types (11 templates)
1. **Spell**: "Spell CAT" — dynamic, based on current word
2. **Explore**: "Find cat", "Find fish", "Find owl"
3. **Training**: "Hit 3 targets", "Hit 5 targets"
4. **Location**: "Visit beach", "Visit forest", "Go to mountain"
5. **Shop**: "Buy a hat", "Visit shop"
6. **Action**: "Jump high"

### Quest Data Structure
```gdscript
{id: String, text: String, type: String, area: String, completed: bool}
```

### Signals

| Signal | When | Listener |
|--------|------|----------|
| `quest_added(quest)` | New quest generated | QuestScroll UI |
| `quest_completed(quest_id)` | Quest marked done | QuestScroll UI |

### Quest Scroll UI (`QuestScrollController.gd`)
- Toggle: Tab (keyboard) / Y (gamepad)
- Slide-in panel from right side
- Active quests in large readable text (36pt, ink color)
- Completed quests: grayed out (50% opacity)
- Title: "Quest Scroll" at 42pt

## Known Issues

- Only spell quests auto-complete; explore/training/shop quests have no completion logic
- Quest templates reference areas (beach, forest, mountain) that don't exist yet
- No quest rewards beyond completion tracking
- Duplicate quests possible across sessions
- Quest scroll panel positioning may overlap with HUD elements

## Future Work

- Quest rewards: coins, items, pet unlocks
- Quest chains: multi-step story quests
- Daily quests for returning players
- Quest markers on screen pointing to objectives
- NPC quest givers in towns (from Francis's shop idea)
- Quest difficulty scaling with word difficulty
