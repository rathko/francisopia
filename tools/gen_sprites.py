#!/usr/bin/env python3
"""Generate summon sprites: HERO (caped super-puppy) and BUNNY (white rabbit).

64x64 logical, nearest-upscaled x2 -> 128x128 RGBA, transparent bg, warm Ghibli
palette — matches bag.png and the other summon sprites.
Re-run:  python3 tools/gen_sprites.py
Godot must re-import new PNGs (deploy.sh runs an import pass).
"""
from PIL import Image, ImageDraw

OUT_DIR = "assets/sprites/summons/"

# --- shared warm palette ---
OUT   = (74, 56, 42, 255)      # warm dark outline
WHITE = (255, 255, 255, 255)
DARK  = (40, 36, 44, 255)

# puppy fur
FUR_HI = (214, 170, 120, 255)
FUR    = (188, 144, 96, 255)
FUR_LO = (150, 110, 70, 255)
NOSE   = (60, 48, 48, 255)
# cape
CAPE   = (208, 52, 58, 255)
CAPE_LO = (168, 36, 44, 255)
MASK   = (44, 46, 70, 255)
YELLOW = (244, 206, 86, 255)
YELLOW_HI = (252, 232, 150, 255)
# bunny
WHT    = (248, 248, 245, 255)
WHT_SH = (216, 218, 226, 255)
PINK   = (255, 188, 200, 255)
PINK2  = (240, 130, 150, 255)


def _star(d, cx, cy, r, color):
    # simple 4-point sparkle-star
    d.polygon([(cx, cy - r), (cx + r * 0.3, cy), (cx, cy + r), (cx - r * 0.3, cy)], fill=color)
    d.polygon([(cx - r, cy), (cx, cy - r * 0.3), (cx + r, cy), (cx, cy + r * 0.3)], fill=color)


def make(draw_fn, name):
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(img))
    img.resize((128, 128), Image.NEAREST).save(OUT_DIR + name)
    print("wrote", OUT_DIR + name)


def draw_hero(d):
    # Cape behind, flaring out
    d.polygon([(16, 26), (48, 26), (54, 54), (10, 54)], fill=CAPE, outline=OUT)
    d.polygon([(32, 26), (48, 26), (54, 54), (32, 54)], fill=CAPE_LO)   # shaded half
    # Body
    d.ellipse([22, 34, 42, 54], fill=FUR, outline=OUT)
    # Paws
    d.ellipse([22, 49, 29, 56], fill=FUR_HI, outline=OUT)
    d.ellipse([35, 49, 42, 56], fill=FUR_HI, outline=OUT)
    # Floppy ears (behind head)
    d.ellipse([12, 14, 23, 36], fill=FUR_LO, outline=OUT)
    d.ellipse([41, 14, 52, 36], fill=FUR_LO, outline=OUT)
    # Head
    d.ellipse([17, 11, 47, 39], fill=FUR_HI, outline=OUT)
    # Snout
    d.ellipse([25, 26, 39, 39], fill=FUR)
    d.ellipse([29, 30, 35, 36], fill=NOSE)   # nose
    # Hero mask
    d.rounded_rectangle([20, 17, 44, 27], radius=4, fill=MASK)
    d.ellipse([24, 18, 30, 26], fill=WHITE)  # eye holes
    d.ellipse([34, 18, 40, 26], fill=WHITE)
    d.ellipse([26, 20, 29, 25], fill=DARK)   # pupils
    d.ellipse([36, 20, 39, 25], fill=DARK)
    # Chest emblem star
    _star(d, 32, 44, 5, YELLOW)
    _star(d, 32, 44, 2.4, YELLOW_HI)


def draw_bunny(d):
    # Ears (white, pink inner)
    d.ellipse([20, 3, 30, 30], fill=WHT, outline=OUT)
    d.ellipse([34, 3, 44, 30], fill=WHT, outline=OUT)
    d.ellipse([23, 7, 27, 26], fill=PINK)
    d.ellipse([37, 7, 41, 26], fill=PINK)
    # Body
    d.ellipse([21, 38, 43, 60], fill=WHT, outline=OUT)
    # Head
    d.ellipse([17, 17, 47, 45], fill=WHT, outline=OUT)
    # Soft cheek shading
    d.ellipse([18, 30, 26, 41], fill=WHT_SH)
    d.ellipse([38, 30, 46, 41], fill=WHT_SH)
    # Feet
    d.ellipse([21, 54, 30, 61], fill=WHT, outline=OUT)
    d.ellipse([34, 54, 43, 61], fill=WHT, outline=OUT)
    # Eyes + shine
    d.ellipse([24, 25, 30, 34], fill=DARK)
    d.ellipse([34, 25, 40, 34], fill=DARK)
    d.ellipse([26, 27, 28, 30], fill=WHITE)
    d.ellipse([36, 27, 38, 30], fill=WHITE)
    # Nose + mouth
    d.polygon([(30, 34), (34, 34), (32, 37)], fill=PINK2)
    d.line([32, 37, 32, 39], fill=OUT)
    d.line([32, 39, 29, 41], fill=OUT)
    d.line([32, 39, 35, 41], fill=OUT)


def draw_rat(d):
    GREY = (138, 128, 117, 255)
    GREY_HI = (164, 154, 143, 255)
    GREY_LO = (104, 95, 86, 255)
    # Long curvy pink tail behind (left), curling
    d.line([(14, 47), (7, 41), (9, 32), (18, 29)], fill=PINK2, width=3, joint="curve")
    # Body
    d.ellipse([15, 30, 46, 50], fill=GREY, outline=OUT)
    d.ellipse([20, 37, 42, 50], fill=GREY_HI)        # belly
    # Feet
    d.ellipse([21, 47, 28, 53], fill=GREY_LO)
    d.ellipse([33, 47, 40, 53], fill=GREY_LO)
    # Head (front-right)
    d.ellipse([35, 26, 56, 46], fill=GREY, outline=OUT)
    # Round ears with pink inners
    d.ellipse([35, 21, 46, 32], fill=GREY, outline=OUT)
    d.ellipse([38, 23, 43, 29], fill=PINK)
    d.ellipse([46, 21, 57, 32], fill=GREY, outline=OUT)
    d.ellipse([49, 23, 54, 29], fill=PINK)
    # Eye + shine
    d.ellipse([44, 32, 50, 38], fill=DARK)
    d.ellipse([45, 33, 47, 35], fill=WHITE)
    # Nose (front tip)
    d.ellipse([54, 38, 58, 42], fill=PINK2)
    # Whiskers
    d.line([(54, 40), (40, 37)], fill=OUT)
    d.line([(54, 41), (40, 44)], fill=OUT)


make(draw_hero, "hero.png")
make(draw_bunny, "bunny.png")
make(draw_rat, "rat.png")
