# Level 1 Word Summon Designs

> Design principles: Each summon should be SURPRISING, FUNNY, and MEMORABLE.
> A child should think "I want to spell THAT word again!" after seeing it.
>
> Key techniques (from learning science):
> - **Exaggerated scale** — things that are too big/small are hilarious to 5-year-olds
> - **Unexpected behavior** — a hat that falls from the sky, a mop that sweeps by itself
> - **Movement** — animated summons are remembered better than static ones
> - **Sound + visual** — multi-sensory encoding doubles retention
> - **Emotional surprise** — the "wow!" moment burns the word into memory

## Pets (already have sprites — just need fun animations)

| Word | Current | Improved Design |
|------|---------|----------------|
| **cat** | Pet follows player | KEEP — already good. Cat purrs, follows, curls up |
| **dog** | Pet follows player | KEEP — wags tail, follows. Maybe add bark on summon |
| **pig** | Pet follows | Add: pig snorts, rolls in mud, leaves muddy prints |
| **hen** | Pet follows | Add: hen clucks, occasionally lays an egg (coin!) |
| **bug** | Pet follows | Add: bug buzzes in circles, lands on player's head |
| **bat** | Pet follows | Add: bat hangs upside down from platforms |
| **rat** | Pet follows | Add: rat scurries fast, hides behind objects, peeks out |
| **fox** | Pet follows | Add: fox is sneaky, sometimes steals a letter from thieves |
| **pup** | Pet follows | Add: puppy bounces, barks tiny barks, chases its tail |
| **pet** | MISSING | Touch any companion and hearts float up |
| **fin** | Fish-like | Fin sticks up from ground like a shark, cruises around |

## Objects (need visual + funny behavior)

| Word | Current | Improved Design |
|------|---------|----------------|
| **hat** | Cosmetic on player | KEEP — giant hat falls from sky, lands on player's head |
| **cap** | Cosmetic | Add: baseball cap flies in like a frisbee, lands on head |
| **wig** | Cosmetic | Add: crazy colorful wig, hair bounces when jumping |
| **bag** | Just coins | A bulging bag drops from sky, coins spill out, bag sits on ground |
| **box** | Has visual | Box drops from sky, bounces, lid pops open with sparkles, coins inside |
| **cup** | Has visual | Giant teacup appears, player can sit inside it |
| **pot** | Just coins | Pot of gold! Rainbow arcs from sky into a bubbling pot |
| **pan** | Just coins | Frying pan appears, sizzles, flips a pancake into the air and player eats it |
| **jug** | Has visual | Jug tips over, water pours out creating a small puddle |
| **can** | Has visual | Tin can tower — 3 cans stack up, wobble, player can knock them |
| **bin** | Has visual | Bin appears, funny eyes peek out from inside |
| **tub** | Has visual | Bathtub appears with bubbles floating up |
| **cot** | Has visual | Cozy cot with blanket, pet comes and sleeps in it |
| **bed** | Has visual | Bouncy bed appears, player bounces if they jump on it |
| **mat** | Has visual | Welcome mat unrolls toward player |
| **rug** | MISSING | Magic carpet! Rug floats up and the player rides it briefly |
| **net** | Catches thief | KEEP — net catches a letter thief, good mechanic |
| **web** | Spider web | KEEP — web catches things, good mechanic |
| **map** | Shows map | Add: treasure map unrolls in the air, X marks a nearby chest |
| **pen** | Has visual | Pen draws a squiggly line in the air that stays for a moment |
| **pin** | Has visual | Pin pops a balloon that appears (confetti!) |
| **gem** | Just coins | Huge sparkling gem rises from ground, shoots rainbow light, then 5 coins |
| **nut** | Has visual | Nut cracks open, surprises inside (maybe a tiny pet?) |
| **bun** | Just coins | Tasty bun appears, steam rising, player "eats" it (heals/coins) |
| **gum** | Has visual | Bubble gum! Player blows a huge pink bubble that floats up and pops |
| **jam** | Has visual | Jam jar tips, sticky jam spreads — funny sliding for anyone walking on it |
| **dot** | Has visual | A single glowing dot appears... then HUNDREDS cascade down like confetti |
| **bow** | MISSING (weapon exists) | Decorative bow (ribbon) wraps around nearest tree/object |
| **log** | Has visual | Log rolls in from off-screen, bounces, settles |

## Nature / Elements

| Word | Current | Improved Design |
|------|---------|----------------|
| **sun** | World effect | KEEP — sky brightens, warm golden glow |
| **fog** | World effect | KEEP — mist rolls in, mysterious, fades |
| **mud** | Slippery zone | FIXED — now terrain-hugging, sliding |
| **hot** | World effect | Everything turns orange/warm, wavy heat lines rise |
| **wet** | World effect | Rain briefly falls on player area, puddles form |
| **red** | World effect | KEEP — everything turns red briefly |
| **six** | Just coins | Six stars appear in a circle formation, spin, become 6 coins |
| **ten** | Just coins | Ten golden orbs cascade down in an arc, become 10 coins |

## Actions / Power-ups

| Word | Current | Improved Design |
|------|---------|----------------|
| **run** | Speed boost | KEEP — speed trail behind player |
| **hop** | Jump boost | KEEP — extra jump height |
| **big** | Size up | KEEP — player grows giant |
| **hit** | Punch effect | Player does a ground pound, screen shakes |
| **dig** | Dig power | KEEP — faster/deeper digging |
| **zip** | Dash | KEEP — quick dash |
| **zap** | MISSING | Lightning bolt strikes player's position, teleport pad appears |
| **sit** | Rest | Player sits down, small hearts float up, pets gather around |
| **hug** | Hug effect | KEEP — hearts, companions come close |
| **mix** | Color mix | Colors around player swirl and blend temporarily |
| **mop** | Clean effect | Mop sweeps across screen, sparkles left behind |
| **fan** | Wind push | KEEP — wind pushes things |
| **lip** | Cosmetic | KEEP — silly lips on player |
| **leg** | Speed | KEEP — faster legs |

## Buildings

| Word | Current | Improved Design |
|------|---------|----------------|
| **hut** | Spawns house | Small cozy hut with smoke from chimney, door player can enter |

## Vehicles

| Word | Current | Improved Design |
|------|---------|----------------|
| **bus** | Has visual | School bus drives in from off-screen, honks, parks |
| **van** | Has visual | Ice cream van! Jingle plays, colorful van parks nearby |
| **jet** | MISSING | Jet streaks across sky leaving a trail, circles back, lands nearby |

## Priority Implementation Order

### Tier 1: Missing summons (must add)
1. **zap** — teleport (core mechanic)
2. **pet** — touch companions for hearts
3. **rug** — magic carpet ride (exciting!)
4. **jet** — jet streaks across sky
5. **bow** — decorative ribbon bow

### Tier 2: Coin-only summons that need visuals (boring currently)
6. **gem** — sparkle + rainbow
7. **pot** — pot of gold with rainbow
8. **pan** — frying pan with pancake flip
9. **bag** — coin bag drops from sky
10. **bun** — tasty bun with steam
11. **six** — star circle formation
12. **ten** — golden orb cascade

### Tier 3: Has basic visual but could be more fun
13. **pin** — balloon pop
14. **gum** — blow bubble
15. **jam** — sticky slide zone
16. **dot** — confetti cascade
17. **bed** — bouncy bed
