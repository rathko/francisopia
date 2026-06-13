#!/usr/bin/env python3
"""Generate the BAG summon sprite: a Ghibli-warm pixel-art hiking backpack.

Authored at 64x64 logical pixels then nearest-upscaled x2 -> 128x128 RGBA, to
match the other summon sprites' pixel density and transparent background.
Re-run after edits:  python3 tools/gen_bag_sprite.py
Godot must re-import the PNG (open editor once) before runtime use.
"""
from PIL import Image, ImageDraw

S = 64
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# --- Ghibli-warm palette (earthy, slightly desaturated) ---
OUT   = (58, 42, 30, 255)     # warm dark-brown outline (never pure black)
C_HI  = (156, 170, 104, 255)  # olive canvas highlight
C_MID = (122, 140, 80, 255)   # olive canvas midtone
C_LO  = (94, 108, 58, 255)    # olive canvas shadow
L_HI  = (176, 126, 70, 255)   # leather strap highlight
L     = (140, 94, 48, 255)    # leather strap
L_LO  = (98, 62, 30, 255)     # leather strap shadow
B_HI  = (244, 182, 104, 255)  # bedroll highlight (warm orange)
B     = (226, 138, 66, 255)   # bedroll mid
B_LO  = (184, 100, 44, 255)   # bedroll shadow
BR    = (218, 180, 76, 255)   # brass buckle
BR_HI = (244, 216, 132, 255)  # brass glint
M     = (202, 210, 214, 255)  # tin mug metal
M_LO  = (150, 160, 166, 255)  # tin mug shadow


def rr(box, fill, radius=4):
    d.rounded_rectangle(box, radius=radius, fill=fill)


# ---- OUTLINE PASS: silhouette drawn 1px larger in warm brown ----
rr([12, 9, 52, 19], OUT, 4)      # bedroll
rr([11, 30, 20, 47], OUT, 3)     # left side pocket
rr([44, 30, 53, 47], OUT, 3)     # right side pocket
rr([17, 14, 47, 30], OUT, 5)     # lid
rr([15, 23, 49, 53], OUT, 6)     # main body

# ---- FILL PASS ----
# side pockets (bulging water-bottle pockets)
rr([12, 31, 19, 46], C_LO, 3)
rr([45, 31, 52, 46], C_LO, 3)
rr([13, 32, 18, 40], C_MID, 2)   # pocket highlight
rr([46, 32, 51, 40], C_MID, 2)

# main body
rr([16, 24, 48, 52], C_MID, 5)
rr([32, 39, 48, 52], C_LO, 5)    # lower-right shadow band
rr([19, 27, 27, 32], C_HI, 2)    # soft upper-left highlight patch

# lid flap
rr([18, 15, 46, 29], C_HI, 4)
rr([20, 16, 44, 19], (176, 190, 120, 255), 3)  # lid crown light
rr([18, 25, 46, 29], C_MID, 3)   # under-lid shadow line
d.line([16, 24, 48, 24], fill=OUT, width=1)     # seam between lid and body

# front pocket with flap
rr([24, 35, 40, 50], OUT, 3)
rr([25, 36, 39, 49], C_LO, 2)
rr([25, 36, 39, 41], C_MID, 2)   # pocket flap (lighter)

# bedroll strapped on top
rr([13, 10, 51, 18], B, 4)
rr([13, 10, 51, 13], B_HI, 4)    # top highlight
d.ellipse([11, 9, 18, 18], fill=B_LO, outline=OUT)   # left rolled end
d.ellipse([46, 9, 53, 18], fill=B_LO, outline=OUT)   # right rolled end
d.ellipse([13, 11, 16, 16], fill=B, outline=None)    # spiral hint L
d.ellipse([48, 11, 51, 16], fill=B, outline=None)    # spiral hint R

# shoulder straps peeking at the top sides
d.line([20, 17, 18, 30], fill=L, width=2)
d.line([44, 17, 46, 30], fill=L, width=2)

# two vertical compression straps over lid + front pocket, with brass buckles
for sx in (28, 35):
    d.rectangle([sx, 16, sx + 2, 45], fill=L)
    d.rectangle([sx, 16, sx, 45], fill=L_HI)        # 1px strap highlight
    d.rectangle([sx - 1, 33, sx + 3, 37], fill=BR)  # buckle
    d.point((sx, 34), fill=BR_HI)                   # glint

# little tin mug hanging off the right pocket (charm detail)
d.line([50, 42, 51, 45], fill=L, width=1)            # clip strap to pocket
d.ellipse([47, 43, 55, 51], fill=M, outline=OUT)
d.ellipse([49, 45, 53, 49], fill=M_LO)
d.arc([52, 43, 58, 51], 300, 70, fill=OUT)

# ---- upscale x2 -> 128, NEAREST (crisp pixels), save ----
out = img.resize((128, 128), Image.NEAREST)
out.save("assets/sprites/summons/bag.png")
print("wrote assets/sprites/summons/bag.png", out.size, out.mode)
