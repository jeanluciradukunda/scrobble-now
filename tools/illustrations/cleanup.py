#!/usr/bin/env python3
"""Remove white/cream backgrounds from mid and fg parallax layers."""

import os
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

ILLUSTRATIONS_DIR = Path(__file__).parent.parent.parent / "site" / "public" / "assets" / "illustrations"

def remove_light_background(input_path: Path, output_path: Path, threshold: int = 235):
    """Remove white/cream background and replace with transparency.

    Uses color distance from detected corner color for adaptive removal.
    Applies alpha matting for smooth edges.
    """
    img = Image.open(input_path).convert("RGB")
    pixels = np.array(img, dtype=np.float64)
    h, w = pixels.shape[:2]

    # Detect background from corners
    s = min(20, h // 4, w // 4)
    corners = np.concatenate([
        pixels[:s, :s].reshape(-1, 3),
        pixels[:s, -s:].reshape(-1, 3),
        pixels[-s:, :s].reshape(-1, 3),
        pixels[-s:, -s:].reshape(-1, 3),
    ])
    bg_color = np.median(corners, axis=0)

    print(f"  Detected bg: RGB({int(bg_color[0])}, {int(bg_color[1])}, {int(bg_color[2])})")

    # Only process if background is light (cream/white)
    if np.mean(bg_color) < 200:
        print(f"  ⏭ Background is dark ({np.mean(bg_color):.0f}), skipping")
        return False

    # Color distance from background
    dist = np.sqrt(np.sum((pixels - bg_color) ** 2, axis=2))

    # Thresholds
    inner_t = 30   # definite background
    outer_t = 60   # edge zone

    # Alpha channel
    alpha = np.zeros((h, w), dtype=np.float64)
    alpha[dist > outer_t] = 1.0
    edge_mask = (dist >= inner_t) & (dist <= outer_t)
    alpha[edge_mask] = (dist[edge_mask] - inner_t) / (outer_t - inner_t)

    # Smooth alpha
    alpha_img = Image.fromarray((alpha * 255).astype(np.uint8), mode="L")
    alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=1))

    # Compose RGBA
    rgba = img.convert("RGBA")
    rgba.putalpha(alpha_img)

    rgba.save(str(output_path))
    print(f"  ✓ Saved: {output_path.name} (RGBA)")
    return True


def main():
    print("🧹 Cleaning parallax layers — removing light backgrounds\n")

    processed = 0
    for f in sorted(os.listdir(ILLUSTRATIONS_DIR)):
        if not f.endswith(".png"):
            continue

        # Only process mid and fg layers (bg layers keep their cream background)
        if "-bg" in f:
            continue

        path = ILLUSTRATIONS_DIR / f
        print(f"  📄 {f}")
        if remove_light_background(path, path):
            processed += 1

    print(f"\n✓ Processed {processed} layers")


if __name__ == "__main__":
    main()
