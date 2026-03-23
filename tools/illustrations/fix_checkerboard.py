#!/usr/bin/env python3
"""Fix images where the AI drew a literal checkerboard transparency pattern.

Detects the grey/white alternating squares and replaces them with real alpha.
"""

import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path
import os

ILLUSTRATIONS_DIR = Path(__file__).parent.parent.parent / "site" / "public" / "assets" / "illustrations"


def has_checkerboard(img_array, check_size=8):
    """Detect if image corners have checkerboard pattern."""
    h, w = img_array.shape[:2]
    # Sample top-right corner (most likely to have checkerboard)
    patch = img_array[:40, -40:]
    if patch.shape[0] < 40 or patch.shape[1] < 40:
        return False

    # Check for alternating light/dark in a grid pattern
    rgb = patch[:, :, :3] if patch.shape[2] >= 3 else patch
    brightness = np.mean(rgb, axis=2)

    # Checkerboard has regular alternation every ~8-16 pixels
    for block_size in [8, 10, 12, 16]:
        if brightness.shape[0] < block_size * 2 or brightness.shape[1] < block_size * 2:
            continue
        blocks = brightness[:block_size*3, :block_size*3]
        # Compute variance within blocks vs between blocks
        row_diffs = []
        for r in range(0, blocks.shape[0] - block_size, block_size):
            for c in range(0, blocks.shape[1] - block_size, block_size):
                block = blocks[r:r+block_size, c:c+block_size]
                row_diffs.append(np.std(block))

        if len(row_diffs) > 0 and np.mean(row_diffs) < 15:
            # Low variance within blocks = possible checkerboard
            # Check if neighboring blocks differ
            b1 = np.mean(brightness[:block_size, :block_size])
            b2 = np.mean(brightness[:block_size, block_size:block_size*2])
            if abs(b1 - b2) > 15:
                return True

    return False


def remove_checkerboard_bg(input_path):
    """Replace checkerboard background with transparency."""
    img = Image.open(input_path).convert("RGBA")
    arr = np.array(img, dtype=np.float64)
    h, w = arr.shape[:2]

    # The checkerboard is typically light grey (~204) and white (~255)
    # alternating in 8-16px blocks
    rgb = arr[:, :, :3]
    brightness = np.mean(rgb, axis=2)

    # Detect the two checkerboard colors from corners
    corner_regions = [
        rgb[:20, :20],      # TL
        rgb[:20, -20:],     # TR
        rgb[-20:, :20],     # BL
        rgb[-20:, -20:],    # BR
    ]

    corner_pixels = np.concatenate([c.reshape(-1, 3) for c in corner_regions])
    corner_bright = np.mean(corner_pixels, axis=1)

    # If corners are NOT light (< 180 brightness), skip
    if np.median(corner_bright) < 180:
        print(f"    Corners are dark ({np.median(corner_bright):.0f}), skipping")
        return False

    # Classify corner pixels into two clusters (light and lighter)
    median_b = np.median(corner_bright)
    light_pixels = corner_pixels[corner_bright >= median_b]
    dark_pixels = corner_pixels[corner_bright < median_b]

    light_color = np.mean(light_pixels, axis=0) if len(light_pixels) > 0 else np.array([255, 255, 255])
    dark_color = np.mean(dark_pixels, axis=0) if len(dark_pixels) > 0 else np.array([204, 204, 204])

    print(f"    Checker colors: light=({int(light_color[0])},{int(light_color[1])},{int(light_color[2])}) dark=({int(dark_color[0])},{int(dark_color[1])},{int(dark_color[2])})")

    # Create mask: pixel is background if close to either checkerboard color
    dist_light = np.sqrt(np.sum((rgb - light_color) ** 2, axis=2))
    dist_dark = np.sqrt(np.sum((rgb - dark_color) ** 2, axis=2))
    dist_min = np.minimum(dist_light, dist_dark)

    # Thresholds
    inner_t = 25   # definite background
    outer_t = 50   # edge zone

    alpha = np.ones((h, w), dtype=np.float64)
    alpha[dist_min < inner_t] = 0.0
    edge = (dist_min >= inner_t) & (dist_min < outer_t)
    alpha[edge] = (dist_min[edge] - inner_t) / (outer_t - inner_t)

    # Smooth
    alpha_img = Image.fromarray((alpha * 255).astype(np.uint8), mode="L")
    alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=1.5))

    # Apply alpha
    result = img.copy()
    result.putalpha(alpha_img)
    result.save(str(input_path))
    print(f"    ✓ Fixed: {input_path.name}")
    return True


def main():
    print("🔧 Fixing checkerboard backgrounds\n")

    fixed = 0
    for f in sorted(os.listdir(ILLUSTRATIONS_DIR)):
        if not f.endswith(".png"):
            continue
        if "-bg" in f:
            continue  # backgrounds keep their cream
        if "workers" in f:
            continue  # full illustrations, not layers

        path = ILLUSTRATIONS_DIR / f
        img = Image.open(path)
        arr = np.array(img.convert("RGBA"))

        if has_checkerboard(arr):
            print(f"  ⚠️  {f} — checkerboard detected")
            if remove_checkerboard_bg(path):
                fixed += 1
        else:
            # Still check if corners are light grey (cleanup missed some)
            corner = arr[:10, -10:, :3]
            brightness = np.mean(corner)
            if 190 < brightness < 220:
                print(f"  🔍 {f} — grey corners ({brightness:.0f}), fixing")
                if remove_checkerboard_bg(path):
                    fixed += 1

    print(f"\n✓ Fixed {fixed} images")


if __name__ == "__main__":
    main()
