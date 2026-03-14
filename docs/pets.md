# Pet System

Companion animals that follow the player.

## Current State

### Pet Behavior (`Pet.gd`)
- CharacterBody2D with gravity and `move_and_slide()`
- Follows owner at 120 px/s, maintains ~50px distance
- Jumps (-320 velocity) when owner is above
- Teleports to owner if >500px away
- collision_layer = 0, collision_mask = 1 (walks on ground, doesn't block players)

### Pet Types (enum)
- **DOG**: brown body (20x16), floppy ears, wagging tail, dot eyes, nose
- **CAT**: orange body (18x14), triangle ears with pink inner, whiskers, green eyes, swaying tail

### Spawning
- Pets spawn only through magic summoning (spell "cat" or "dog")
- No auto-spawn at game start
- MagicSummon creates pet via `Pet.tscn` scene, calls `setup(owner, pet_type)`
- Pet follows whichever player triggered the summon

### Visual Design
- Built entirely from ColorRect nodes (no sprites)
- Idle animations: tail wag (dog, +-5px oscillation) or tail sway (cat)
- Sprite flips to face movement direction

## Known Issues

- Pets don't persist across sessions (lost on game restart)
- Multiple pets of same type can be summoned (no duplicate check)
- Pet can get stuck on terrain blocks and fail to follow
- No pet interaction (can't pet them, no reactions)
- Cat owner reassignment (`_reassign_cat_owner`) references removed pet variables

## Future Work

- Pet persistence in save file
- Pet abilities (dog fetches letters, cat scares thieves)
- More pet types: frog, fish (bowl), bird, bug
- Pet naming system
- Pet happiness/bond mechanic
- Pet tricks activated by spelling pet-related words
