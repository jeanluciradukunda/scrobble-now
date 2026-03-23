#!/usr/bin/env python3
"""
Scrobble Now — Condec 1969-inspired parallax illustration generator.

Generates multi-layered illustrations for scroll parallax.
Each illustration = 3 separate images (background, midground, foreground)
that stack and move at different scroll speeds.

Usage:
    cd tools/illustrations
    source .venv/bin/activate
    export GOOGLE_API_KEY="your-key"
    python3 generate.py [--only NAME] [--force]

Cost: ~$0.04/image × 3 layers × 6 illustrations = ~$0.72 total
"""

import os
import sys
import time
from pathlib import Path

try:
    from google import genai
    from google.genai import types
except ImportError:
    print("Install: source .venv/bin/activate && pip install google-genai Pillow")
    sys.exit(1)

MODEL = "gemini-3.1-flash-image-preview"
DELAY = 4
OUTPUT_DIR = Path(__file__).parent.parent.parent / "site" / "public" / "assets" / "illustrations"

# ═══════════════════════════════════════════════════════════
# CONDEC 1969 / ARNO STERNGLASS STYLE — applied to music equipment
#
# Key visual rules from studying the full PDF:
# - Pop art gouache + colored pencil on cream paper
# - Bold overlapping geometric color planes
# - Visible crosshatching and pencil texture
# - Black ink outlines with flat color fills
# - Industrial cutaway revealing internals
# - Rainbow stripe motif (red→indigo vertical bars)
# - Cream paper showing through as negative space
# - NOT photorealistic, NOT digital, NOT flat vector
# ═══════════════════════════════════════════════════════════

STYLE = """
1969 pop art technical illustration in the style of Arno Sternglass for the Condec Corporation annual report.
Gouache and colored pencil on cream/off-white paper. Bold overlapping geometric color planes.
Visible crosshatching and pencil stroke texture throughout. Black ink outlines with flat opaque color fills.
Color palette: cobalt blue, burnt orange, golden yellow, olive green, deep purple, warm sepia browns.
Cream paper background visible as negative space. Wide landscape composition.
NOT photorealistic. NOT digital art. NOT flat minimalist vector. Hand-painted technical illustration feel.
"""

TRANSPARENT_SUFFIX = "Isolated on a pure transparent background with NO ground, NO shadows, NO backdrop. PNG with alpha transparency."
CREAM_BG = "On cream/off-white (#f5f0e4) paper background."

# Each illustration has 3 layers: bg (slow), mid (medium), fg (fast)
ILLUSTRATIONS = {
    "hero": {
        "layers": [
            {
                "name": "hero-bg",
                "prompt": f"""
Background layer for a turntable illustration.
A vast architectural backdrop: geometric overlapping color planes of blue, green, purple, and orange
forming abstract angular shapes — like a city skyline dissolving into abstract geometry.
A large circle (moon/sun) sits in the upper portion. Industrial silhouettes of radio towers,
smokestacks, and rooftops along the horizon line. A vertical rainbow stripe
(red, orange, gold, yellow, green, teal, blue, indigo) runs through the center.
{STYLE} {CREAM_BG}
""",
            },
            {
                "name": "hero-mid",
                "prompt": f"""
Middle layer for a turntable illustration.
A massive vintage turntable/record player shown in technical cutaway view, revealing internal mechanisms.
The platter, motor, belt drive, and plinth are all visible in cross-section.
A vinyl record sits on the platter with exaggerated grooves. The tonearm extends with visible
cartridge and stylus. Rendered at heroic scale — the turntable fills most of the frame.
VU meters and amplifier knobs visible at the base.
{STYLE} {TRANSPARENT_SUFFIX}
""",
            },
            {
                "name": "hero-fg",
                "prompt": f"""
Foreground layer for a turntable illustration.
Close-up detailed elements: a tonearm headshell with cartridge in sharp detail,
knobs and switches, a few small human figures sitting at desks with audio equipment,
cables and patch cords. All rendered at various scales scattered across the frame.
A couple of album covers/vinyl sleeves leaning against equipment.
{STYLE} {TRANSPARENT_SUFFIX}
""",
            },
        ],
    },

    "discovery": {
        "layers": [
            {
                "name": "discovery-bg",
                "prompt": f"""
Background layer for a recording studio mixing console illustration.
Abstract geometric color planes of blue, gold, and warm brown forming
architectural depth — angled walls, acoustic panels, a control room window.
Dotted with small indicator lights. Warm amber and cool blue contrast.
{STYLE} {CREAM_BG}
""",
            },
            {
                "name": "discovery-mid",
                "prompt": f"""
Middle layer for a mixing console illustration.
A massive professional studio mixing console shown in dramatic diagonal cutaway,
revealing channel strips, faders, rotary knobs, VU meters, and internal circuit boards.
The console stretches across the full width. Reel-to-reel tape machines visible behind it.
Monitor speakers on stands. Patch bay with dozens of cables.
Rendered in exquisite mechanical detail with every knob and fader visible.
{STYLE} {TRANSPARENT_SUFFIX}
""",
            },
            {
                "name": "discovery-fg",
                "prompt": f"""
Foreground layer for a mixing console illustration.
Close-up elements: individual fader caps in bright colors (red, blue, gold, green, purple)
representing different audio sources. Floating VU meter needles. A hand adjusting a knob.
Headphones. Microphone. Scattered patch cables.
{STYLE} {TRANSPARENT_SUFFIX}
""",
            },
        ],
    },

    "collage": {
        "layers": [
            {
                "name": "collage-bg",
                "prompt": f"""
Background layer for an album collage/printing press illustration.
Geometric color planes of gold, orange, and green forming an abstract industrial space.
Printing press rollers and conveyor belts visible in the background.
Color calibration bars and registration marks along the edges.
{STYLE} {CREAM_BG}
""",
            },
            {
                "name": "collage-mid",
                "prompt": f"""
Middle layer showing a large grid/mosaic of colorful rectangles (album covers) arranged
in a 5x5 pattern, viewed at an isometric angle. Each rectangle is a different bold color.
Around it: a vintage camera apparatus, printing plates, and a light table.
Rulers and crop marks frame the grid. The grid appears to be coming off a printing press.
{STYLE} {TRANSPARENT_SUFFIX}
""",
            },
            {
                "name": "collage-fg",
                "prompt": f"""
Foreground layer for album collage illustration.
A person examining the grid through a magnifying loupe. Scattered individual
album covers/prints in bright colors. An ink roller. Color swatches.
A rainbow stripe of ink colors on a mixing palette.
{STYLE} {TRANSPARENT_SUFFIX}
""",
            },
        ],
    },

    "history": {
        "layers": [
            {
                "name": "history-bg",
                "prompt": f"""
Background for a reel-to-reel tape machine illustration.
Bold planes of blue, purple, and warm brown forming a studio interior.
Wood paneling, acoustic tiles, and shelving visible.
Stacked tape boxes on shelves. A clock on the wall.
{STYLE} {CREAM_BG}
""",
            },
            {
                "name": "history-mid",
                "prompt": f"""
A giant reel-to-reel tape machine shown in dramatic technical cutaway.
Two large supply/take-up reels dominate the composition with tape threading through.
The transport mechanism exposed: capstan motor, pinch roller, erase/record/playback heads
all shown in cross-section. Tape counter display showing numbers.
Transport buttons (record, play, stop, rewind, fast-forward) as bold colored circles.
{STYLE} {TRANSPARENT_SUFFIX}
""",
            },
            {
                "name": "history-fg",
                "prompt": f"""
Foreground for tape machine illustration.
Close-up: tape threading through heads in detail. A hand pressing a transport button.
Magnetic tape unwinding. Sound level meters. A pencil and log sheet
for recording session notes. Splicing tape and razor blade.
{STYLE} {TRANSPARENT_SUFFIX}
""",
            },
        ],
    },

    "stats": {
        "layers": [
            {
                "name": "stats-bg",
                "prompt": f"""
Background for a data visualization dashboard illustration.
Abstract geometric planes of green, blue, and gold forming a retro-futuristic control room.
Panels of blinking indicator lights. Oscilloscope screens with waveforms.
{STYLE} {CREAM_BG}
""",
            },
            {
                "name": "stats-mid",
                "prompt": f"""
A wall of retro analog instruments and data displays.
Large VU meters with arcing needles. Oscilloscopes showing waveforms.
Horizontal bar charts rendered as physical raised wooden blocks.
A punched tape reader unspooling data. A row of nixie tube number displays
showing statistics. All rendered as physical vintage instruments, not digital screens.
{STYLE} {TRANSPARENT_SUFFIX}
""",
            },
            {
                "name": "stats-fg",
                "prompt": f"""
Foreground for data dashboard illustration.
A person reading a paper printout from a teletype machine. Scattered punched cards.
A desk lamp. A coffee cup. Individual nixie tube digits floating.
An abacus. A slide rule. Pencils and graph paper.
{STYLE} {TRANSPARENT_SUFFIX}
""",
            },
        ],
    },
}


def generate_image(client, prompt: str, output_path: Path, retries: int = 3) -> bool:
    for attempt in range(retries):
        try:
            print(f"    Generating (attempt {attempt + 1})...")
            response = client.models.generate_content(
                model=MODEL,
                contents=prompt.strip(),
                config=types.GenerateContentConfig(
                    response_modalities=["IMAGE"],
                ),
            )

            for part in response.parts:
                if part.inline_data is not None:
                    image = part.as_image()
                    output_path.parent.mkdir(parents=True, exist_ok=True)
                    image.save(str(output_path))
                    print(f"    ✓ Saved: {output_path.name}")
                    return True

            print(f"    ⚠ No image in response")

        except Exception as e:
            print(f"    ✗ Error: {e}")
            if attempt < retries - 1:
                time.sleep(DELAY * 2)

    return False


def main():
    api_key = os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("ERROR: Set GOOGLE_API_KEY")
        print("  export GOOGLE_API_KEY='your-key-from-aistudio.google.com'")
        sys.exit(1)

    client = genai.Client(api_key=api_key)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    only = None
    if "--only" in sys.argv:
        idx = sys.argv.index("--only")
        if idx + 1 < len(sys.argv):
            only = sys.argv[idx + 1]

    force = "--force" in sys.argv

    targets = {k: v for k, v in ILLUSTRATIONS.items() if only is None or k == only}

    total_layers = sum(len(v["layers"]) for v in targets.values())
    print(f"\n🎨 Scrobble Now — Condec 1969 parallax illustration generator")
    print(f"   Model: {MODEL}")
    print(f"   Illustrations: {len(targets)} × 3 layers = {total_layers} images")
    print(f"   Est. cost: ~${total_layers * 0.04:.2f}\n")

    success = 0
    total = 0
    for name, spec in targets.items():
        print(f"  📐 {name.upper()}")
        for layer in spec["layers"]:
            total += 1
            output_path = OUTPUT_DIR / f"{layer['name']}.png"

            if output_path.exists() and not force:
                print(f"    ⏭ {layer['name']} (exists)")
                success += 1
                continue

            if generate_image(client, layer["prompt"], output_path):
                success += 1

            time.sleep(DELAY)

    print(f"\n✓ Done: {success}/{total} layers generated")
    print(f"  Output: {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
