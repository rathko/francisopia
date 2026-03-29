# Sprite Generation Plan — Level 1 Words

66 pixel art sprites needed. Style: Ghibli-warm, 48x48 or 64x64, transparent background, nearest-neighbor rendering.

## By Category (for consistent batch prompting)

### Animals/Pets (11 sprites)
bat, bug, fin, fox, hen, pet, pig, pup, rat + already have: cat, dog

### Objects — Kitchen/Food (8)
bun, can, cup, jam, jug, nut, pan, pot

### Objects — Household (10)
bag, bed, bin, box, cot, mat, mop, rug, tub, hut

### Objects — Wearables (4)
cap, hat, wig, bow

### Objects — Tools/Items (7)
fan, gem, log, map, net, pen, pin

### Vehicles (3)
bus, jet, van

### Nature/Elements (4)
fog, mud, sun, web

### Actions/Effects (8) — may not need sprites, just VFX
big, dig, dot, hit, hop, hug, run, zip

### Abstract/Numbers (4) — visual interpretation needed
six, ten, mix, zap

### Body Parts (3) — stylized
fin, leg, lip

### States (3) — visual interpretation needed
hot, red, wet, sit, pet

## Generation Strategy

### Tier 1: Concrete objects and animals (easiest, most impactful)
- Animals: pixel art, cute, facing right, idle pose
- Kitchen objects: pixel art, warm colors, recognizable silhouette
- Household objects: pixel art, cozy feel

### Tier 2: Vehicles and wearables
- Clear silhouette, bright colors

### Tier 3: Actions and effects
- These might work better as VFX animations than static sprites
- "big" = scaling effect, "run" = speed lines, "hop" = jump arc
- Could skip sprites for these and keep them as effects

### Tool: GPT-Image-1 via OpenAI API
- We have OPENAI_API_KEY in BWS
- Prompt template: "48x48 pixel art sprite, [object], Ghibli-warm color palette, transparent background, cute and friendly, game asset, no text"
- Generate in batches of 5-10
- Post-process: trim, ensure transparency, check quality
