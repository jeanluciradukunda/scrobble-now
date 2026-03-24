#!/usr/bin/env python3
"""
Decompose illustrations into DRAMATIC parallax color layers.

Each illustration becomes 3 transparent PNGs with AGGRESSIVE separation:
  - back:  ONLY warm colors (reds, oranges, browns, golds) on transparent
  - mid:   ONLY cool colors (blues, greens, purples) on transparent
  - front: ONLY dark linework/outlines on transparent

Rainbow river passes between back and front layers.
"""

import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

SRC_DIR = Path(__file__).parent.parent.parent / "site" / "public" / "assets" / "illustrations"
OUT_DIR = SRC_DIR / "layers"


def decompose_image(src_path: Path):
    name = src_path.stem
    img = Image.open(src_path).convert("RGBA")
    arr = np.array(img, dtype=np.float64)
    h, w = arr.shape[:2]

    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    brightness = (r + g + b) / 3.0

    # Background mask — cream/white areas to exclude from ALL layers
    is_bg = brightness > 210

    # ── LINEWORK LAYER (front) ──
    # Very dark pixels = ink outlines, crosshatching
    is_dark = brightness < 70
    line_alpha = np.zeros((h, w))
    line_alpha[is_dark & ~is_bg] = 1.0
    # Soften edges
    near_dark = (brightness >= 70) & (brightness < 110) & ~is_bg
    line_alpha[near_dark] = (110 - brightness[near_dark]) / 40.0

    linework = np.zeros((h, w, 4), dtype=np.uint8)
    linework[:, :, :3] = arr[:, :, :3].astype(np.uint8)
    linework[:, :, 3] = (line_alpha * 255).astype(np.uint8)

    # ── WARM LAYER (back) ──
    # Strong warm: red dominates, or gold (high r+g, low b)
    warmth = r - np.minimum(g, b)  # how much warmer than coolest channel
    is_warm = (warmth > 40) & ~is_bg & ~is_dark
    is_gold = (r > 140) & (g > 100) & (b < 90) & ~is_bg & ~is_dark
    is_brown = (r > 100) & (g > 60) & (g < 120) & (b < 80) & ~is_bg & ~is_dark

    warm_alpha = np.zeros((h, w))
    warm_alpha[is_warm] = np.clip(warmth[is_warm] / 100.0, 0.4, 1.0)
    warm_alpha[is_gold] = 1.0
    warm_alpha[is_brown] = np.maximum(warm_alpha[is_brown], 0.8)

    warm = np.zeros((h, w, 4), dtype=np.uint8)
    warm[:, :, :3] = arr[:, :, :3].astype(np.uint8)
    warm[:, :, 3] = (warm_alpha * 255).astype(np.uint8)

    # ── COOL LAYER (mid) ──
    # Blue/green/purple dominates
    coolness = np.minimum(b, g) - r  # how much cooler than red
    is_cool = (coolness > 20) & ~is_bg & ~is_dark
    is_blue = (b > 120) & (b > r) & (b > g) & ~is_bg & ~is_dark
    is_purple = (r > 60) & (b > 100) & (g < r) & (b > r * 0.8) & ~is_bg & ~is_dark
    is_green = (g > 100) & (g > r) & (g > b) & ~is_bg & ~is_dark

    cool_alpha = np.zeros((h, w))
    cool_alpha[is_cool] = np.clip(coolness[is_cool] / 80.0, 0.4, 1.0)
    cool_alpha[is_blue] = 1.0
    cool_alpha[is_purple] = np.maximum(cool_alpha[is_purple], 0.9)
    cool_alpha[is_green] = np.maximum(cool_alpha[is_green], 0.8)

    cool = np.zeros((h, w, 4), dtype=np.uint8)
    cool[:, :, :3] = arr[:, :, :3].astype(np.uint8)
    cool[:, :, 3] = (cool_alpha * 255).astype(np.uint8)

    # Save
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for layer_name, layer_data in [("back-warm", warm), ("mid-cool", cool), ("front-line", linework)]:
        out_path = OUT_DIR / f"{name}-{layer_name}.png"
        layer_img = Image.fromarray(layer_data, mode="RGBA")
        if "back" in layer_name:
            layer_img = layer_img.filter(ImageFilter.GaussianBlur(radius=1.0))
        layer_img.save(str(out_path), optimize=True)
        size_kb = out_path.stat().st_size // 1024
        print(f"    {layer_name}: {size_kb}K")


def main():
    targets = [
        "te-zamrock-studio",
        "discovery-mid",
        "te-modular",
        "te-vinyl-machine",
        "zamrock-collage",
        "history-mid",
    ]

    print("🔬 Decomposing into AGGRESSIVE color layers\n")
    for name in targets:
        src = SRC_DIR / f"{name}.jpg"
        if not src.exists():
            src = SRC_DIR / f"{name}.png"
        if not src.exists():
            print(f"  ⏭ {name} — not found"); continue
        print(f"  📐 {name}")
        decompose_image(src)

    print(f"\n✓ {len(list(OUT_DIR.glob('*.png')))} layers in {OUT_DIR}/")


if __name__ == "__main__":
    main()
