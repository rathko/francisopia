#!/usr/bin/env python3
"""
Build a kohya_ss SDXL LoRA training dataset from Francis-opia's existing sprites.

Output layout (kohya_ss SDXL convention):
    <out_root>/
      img/
        10_francisopia/     # standard-weight images (10 repeats per epoch)
          <name>.png        # 1024x1024 nearest-neighbor upscaled, flattened to white bg
          <name>.txt        # caption: `francisopia_style, <subject>, pixel art`
        15_francisopia/     # frame-coherent walk cycle (1.5x weight)
          ...
      log/
      model/

Run from the francisopia repo root. Default output is the NFS-shared training
volume so kohya_ss on mainframe sees the dataset without copy steps.
"""
import argparse
import shutil
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parent.parent

# ---- Curated training set ---------------------------------------------------
# Heaviest weight (1.5x): player walk cycle — ONLY existing 4-frame coherent
# sequence in the project. Teaches the LoRA same-character-different-pose.
HIGH_WEIGHT = [
    ("assets/sprites/player/walk_0.png",
     "child explorer with green hood and brown hair, walking, frame 1 of 4, side view"),
    ("assets/sprites/player/walk_1.png",
     "child explorer with green hood and brown hair, walking, frame 2 of 4, side view"),
    ("assets/sprites/player/walk_2.png",
     "child explorer with green hood and brown hair, walking, frame 3 of 4, side view"),
    ("assets/sprites/player/walk_3.png",
     "child explorer with green hood and brown hair, walking, frame 4 of 4, side view"),
]

# Standard weight: rest of the player + creature poses + curated summons.
# Summons selected for character-bearing subjects (creatures, expressive
# objects). Pure-concept words (big, six, hot, wet, run, ...) skipped because
# the existing sprite for those tends to be a generic icon rather than a
# Ghibli-cute character — they'd water down the style signal.
STANDARD_WEIGHT = [
    # Player extra states (single frames)
    ("assets/sprites/player/idle_0.png",
     "child explorer with green hood and brown hair, standing idle, side view"),
    ("assets/sprites/player/jump_0.png",
     "child explorer with green hood and brown hair, jumping, side view"),
    ("assets/sprites/player/fall_0.png",
     "child explorer with green hood and brown hair, falling, side view"),

    # Creature poses (each ~3 poses per creature — partial frame coherence)
    ("assets/sprites/creatures/cat_idle.png",
     "small orange cat, sitting, front view"),
    ("assets/sprites/creatures/cat_stretch.png",
     "small orange cat, stretching, side view"),
    ("assets/sprites/creatures/cat_walk.png",
     "small orange cat, walking, side view"),
    ("assets/sprites/creatures/dog_idle.png",
     "small golden puppy, sitting, front view"),
    ("assets/sprites/creatures/dog_walk.png",
     "small golden puppy, walking, side view"),
    ("assets/sprites/creatures/dog_bark.png",
     "small golden puppy, barking, side view"),

    # Summons — animals and creatures (highest style signal)
    ("assets/sprites/summons/bat.png",       "friendly orange bat, wings spread, front view"),
    ("assets/sprites/summons/bug.png",       "small cartoon bug, top view"),
    ("assets/sprites/summons/bun.png",       "cute bunny rabbit, sitting, front view"),
    ("assets/sprites/summons/fox.png",       "small orange fox, sitting, front view"),
    ("assets/sprites/summons/hen.png",       "plump cartoon hen, side view"),
    ("assets/sprites/summons/pet.png",       "small friendly pet creature, sitting"),
    ("assets/sprites/summons/pig.png",       "round pink pig, side view"),
    ("assets/sprites/summons/pup.png",       "small puppy, sitting, front view"),
    ("assets/sprites/summons/rat.png",       "small grey rat, side view"),

    # Summons — character-bearing objects
    ("assets/sprites/summons/bow.png",       "decorative ribbon bow, front view"),
    ("assets/sprites/summons/cup.png",       "ceramic cup, three-quarter view"),
    ("assets/sprites/summons/fan.png",       "hand fan, front view"),
    ("assets/sprites/summons/gem.png",       "shining cartoon gem"),
    ("assets/sprites/summons/hat.png",       "wide-brimmed hat, three-quarter view"),
    ("assets/sprites/summons/hut.png",       "small wooden hut, front view"),
    ("assets/sprites/summons/jam.png",       "jar of jam, front view"),
    ("assets/sprites/summons/jet.png",       "small cartoon jet plane, side view"),
    ("assets/sprites/summons/jug.png",       "small ceramic jug, side view"),
    ("assets/sprites/summons/log.png",       "wooden log, three-quarter view"),
    ("assets/sprites/summons/map.png",       "rolled paper map, three-quarter view"),
    ("assets/sprites/summons/mop.png",       "household mop, side view"),
    ("assets/sprites/summons/net.png",       "small fishing net, three-quarter view"),
    ("assets/sprites/summons/nut.png",       "single nut, three-quarter view"),
    ("assets/sprites/summons/pan.png",       "frying pan, three-quarter view"),
    ("assets/sprites/summons/pot.png",       "small clay pot, side view"),
    ("assets/sprites/summons/sun.png",       "smiling cartoon sun, front view"),
    ("assets/sprites/summons/web.png",       "spider web, front view"),
]

TRIGGER = "francisopia_style"
STYLE_TAG = "pixel art"
TARGET_SIZE = 1024
BG_COLOR = (255, 255, 255)  # White; matches the prompt-time `isolated on white background`

# ---- Image processing -------------------------------------------------------

def upscale_to_square(src: Path, target: int = TARGET_SIZE) -> Image.Image:
    """Open RGBA, pad to square if needed, NEAREST-upscale to target, flatten on white."""
    im = Image.open(src).convert("RGBA")
    w, h = im.size

    # Pad to square (preserves alpha; lets nearest-upscale stay axis-aligned).
    if w != h:
        side = max(w, h)
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.paste(im, ((side - w) // 2, (side - h) // 2))
        im = canvas

    # NEAREST upscale — critical: bilinear/bicubic destroys pixel edges.
    im = im.resize((target, target), Image.NEAREST)

    # Flatten alpha onto white; SDXL training needs RGB, and the intended
    # generation prompt already says "isolated on white background" so the
    # model learns to associate this style with that backdrop.
    bg = Image.new("RGB", im.size, BG_COLOR)
    bg.paste(im, mask=im.split()[3])
    return bg


def caption_for(subject: str) -> str:
    return f"{TRIGGER}, {subject}, {STYLE_TAG}"


# ---- Main -------------------------------------------------------------------

def write_set(items, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    for rel, subject in items:
        src = REPO / rel
        if not src.exists():
            print(f"  SKIP missing: {rel}")
            continue
        name = src.stem
        # Disambiguate when same-name files come from different folders.
        parent = src.parent.name
        out_name = f"{parent}_{name}"
        img_out = out_dir / f"{out_name}.png"
        cap_out = out_dir / f"{out_name}.txt"
        img = upscale_to_square(src)
        img.save(img_out, "PNG", optimize=True)
        cap_out.write_text(caption_for(subject) + "\n", encoding="utf-8")
        written += 1
        print(f"  + {out_name}  <-  {rel}")
    return written


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/home/shared/nfs/lora-train/francisopia-v1",
                    help="Dataset root (kohya_ss layout)")
    ap.add_argument("--clean", action="store_true",
                    help="Wipe the existing img/ subdirs first")
    args = ap.parse_args()

    out = Path(args.out)
    img_root = out / "img"
    log_dir = out / "log"
    model_dir = out / "model"

    if args.clean and img_root.exists():
        print(f"[clean] removing {img_root}")
        shutil.rmtree(img_root)

    log_dir.mkdir(parents=True, exist_ok=True)
    model_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n[high-weight set: 15_{TRIGGER}]")
    n_hi = write_set(HIGH_WEIGHT, img_root / f"15_{TRIGGER}")

    print(f"\n[standard-weight set: 10_{TRIGGER}]")
    n_std = write_set(STANDARD_WEIGHT, img_root / f"10_{TRIGGER}")

    total = n_hi + n_std
    # Effective exposures = images * repeat_count (the leading number in folder name)
    eff = n_hi * 15 + n_std * 10
    print(f"\n[summary]")
    print(f"  high-weight images:     {n_hi}  (15 repeats each)")
    print(f"  standard-weight images: {n_std}  (10 repeats each)")
    print(f"  total source images:    {total}")
    print(f"  exposures per epoch:    {eff}")
    print(f"  trigger word:           {TRIGGER}")
    print(f"  output root:            {out}")
    print(f"\nReview a few captions then kick off training in kohya_ss.")


if __name__ == "__main__":
    main()
