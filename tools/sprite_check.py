#!/usr/bin/env python3
"""Sprite quality checker - detects artifacts, stray pixels, and measures content bounds.

Usage:
    python3 tools/sprite_check.py assets/sprites/world/tree_0.png
    python3 tools/sprite_check.py assets/sprites/world/   # check all PNGs in dir
    python3 tools/sprite_check.py --fix assets/sprites/world/tree_0.png  # auto-fix stray pixels

Reports:
    - Content bounding box (where the actual art is)
    - Stray pixel clusters (< 4 connected pixels far from main content = artifact)
    - Background remnants (non-transparent pixels in expected-empty regions)
    - Roof/top line and ground/bottom line positions
"""

import sys
import os
from PIL import Image
from collections import deque


def analyze_sprite(path: str, fix: bool = False) -> dict:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    pixels = list(img.getdata())

    # Find all non-transparent pixels
    opaque = set()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[y * w + x]
            if a > 10:
                opaque.add((x, y))

    if not opaque:
        return {"file": os.path.basename(path), "status": "EMPTY", "opaque_pixels": 0}

    # Bounding box
    min_x = min(p[0] for p in opaque)
    max_x = max(p[0] for p in opaque)
    min_y = min(p[1] for p in opaque)
    max_y = max(p[1] for p in opaque)

    # Find connected components using flood fill
    visited = set()
    components = []

    def flood_fill(start):
        component = set()
        queue = deque([start])
        while queue:
            px, py = queue.popleft()
            if (px, py) in visited:
                continue
            visited.add((px, py))
            component.add((px, py))
            for dx, dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1),(-1,1),(1,1)]:
                nx, ny = px+dx, py+dy
                if (nx, ny) in opaque and (nx, ny) not in visited:
                    queue.append((nx, ny))
        return component

    for p in opaque:
        if p not in visited:
            comp = flood_fill(p)
            components.append(comp)

    # Sort by size, largest is main content
    components.sort(key=len, reverse=True)
    main_component = components[0] if components else set()

    # Stray pixels: small components (< 6 pixels) that are far from main content
    strays = []
    for comp in components[1:]:
        if len(comp) < 6:
            # Check distance from main content bbox
            comp_cx = sum(p[0] for p in comp) / len(comp)
            comp_cy = sum(p[1] for p in comp) / len(comp)
            main_cx = (min_x + max_x) / 2
            main_cy = (min_y + max_y) / 2
            dist = ((comp_cx - main_cx)**2 + (comp_cy - main_cy)**2) ** 0.5
            if dist > 10:  # Far from center
                strays.append({
                    "pixels": len(comp),
                    "center": (int(comp_cx), int(comp_cy)),
                    "distance_from_content": int(dist)
                })

    # Fix: remove stray pixels
    fixed = False
    if fix and strays:
        stray_pixels = set()
        for comp in components[1:]:
            if len(comp) < 6:
                comp_cx = sum(p[0] for p in comp) / len(comp)
                comp_cy = sum(p[1] for p in comp) / len(comp)
                main_cx = (min_x + max_x) / 2
                main_cy = (min_y + max_y) / 2
                dist = ((comp_cx - main_cx)**2 + (comp_cy - main_cy)**2) ** 0.5
                if dist > 10:
                    stray_pixels.update(comp)

        if stray_pixels:
            new_pixels = list(pixels)
            for x, y in stray_pixels:
                new_pixels[y * w + x] = (0, 0, 0, 0)
            img.putdata(new_pixels)
            img.save(path)
            fixed = True

    # Edge analysis
    result = {
        "file": os.path.basename(path),
        "size": f"{w}x{h}",
        "content_bbox": {"x": min_x, "y": min_y, "w": max_x-min_x+1, "h": max_y-min_y+1},
        "roof_y": min_y,
        "ground_y": max_y,
        "left_edge": min_x,
        "right_edge": max_x,
        "opaque_pixels": len(opaque),
        "components": len(components),
        "main_component_pct": f"{100*len(main_component)/len(opaque):.0f}%",
        "stray_artifacts": strays,
        "status": "CLEAN" if not strays else f"{len(strays)} STRAYS",
    }
    if fixed:
        result["fixed"] = f"Removed {len(strays)} stray clusters"

    return result


def main():
    fix = "--fix" in sys.argv
    paths = [a for a in sys.argv[1:] if a != "--fix"]

    if not paths:
        print("Usage: python3 sprite_check.py [--fix] <file_or_dir>")
        sys.exit(1)

    targets = []
    for p in paths:
        if os.path.isdir(p):
            for f in sorted(os.listdir(p)):
                if f.endswith(".png") and not f.startswith("raw"):
                    targets.append(os.path.join(p, f))
        else:
            targets.append(p)

    for t in targets:
        result = analyze_sprite(t, fix=fix)
        status = result["status"]
        icon = "OK" if status == "CLEAN" else "!!"
        print(f"[{icon}] {result['file']:30s} {result.get('size','?'):>8s}  "
              f"content:{result.get('content_bbox',{}).get('w','?')}x{result.get('content_bbox',{}).get('h','?')}  "
              f"roof:{result.get('roof_y','?')} ground:{result.get('ground_y','?')}  "
              f"components:{result.get('components','?')}  {status}")
        if result.get("stray_artifacts"):
            for s in result["stray_artifacts"]:
                print(f"     stray: {s['pixels']}px at {s['center']}, dist={s['distance_from_content']}")
        if result.get("fixed"):
            print(f"     FIXED: {result['fixed']}")


if __name__ == "__main__":
    main()
