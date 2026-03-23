#!/usr/bin/env python3
"""Generate additional Condec-style illustrations — people working on complex machines."""

import os
import sys
import time
from pathlib import Path

from google import genai
from google.genai import types

MODEL = "gemini-3.1-flash-image-preview"
DELAY = 4
OUTPUT_DIR = Path(__file__).parent.parent.parent / "site" / "public" / "assets" / "illustrations"

STYLE = """
1969 pop art technical illustration in the style of Arno Sternglass for the Condec Corporation annual report.
Gouache and colored pencil on cream/off-white paper. Bold overlapping geometric color planes.
Visible crosshatching and pencil stroke texture. Black ink outlines with flat opaque color fills.
Color palette: cobalt blue, burnt orange, golden yellow, olive green, deep purple, warm sepia browns.
Cream paper background visible. Wide landscape composition.
NOT photorealistic. NOT digital. Hand-painted industrial technical illustration.
"""

EXTRAS = {
    "workers-synth": {
        "prompt": f"""
A dramatic scene of people working on a massive modular synthesizer wall.
The synth fills the entire left side — hundreds of patch cables, knobs, oscillators,
envelope generators, and sequencer modules rendered in exquisite mechanical detail.
Workers on ladders and scaffolding plug in cables and adjust knobs.
Complex gear mechanisms and rotating wheels visible inside the open panels.
Exposed circuit boards and wiring. A vertical rainbow stripe descends through the center.
Bold geometric color planes of blue, orange, and gold create architectural depth behind.
On cream/off-white paper background.
{STYLE}
""",
        "filename": "workers-synth.png",
    },

    "workers-gears": {
        "prompt": f"""
An isometric cutaway of a giant clockwork music machine — gears, cogs, escapements,
and mechanical automata that play music. People in lab coats inspect and adjust
the mechanisms. The largest gear dominates the center at dramatic scale.
Smaller gears mesh in precise chains. Punched music rolls feed through the mechanism.
Hammers strike tuned metal bars. Everything rendered as a technical cross-section
showing the internals. Bold planes of purple, gold, and blue behind.
On cream/off-white paper background.
{STYLE}
""",
        "filename": "workers-gears.png",
    },

    "workers-pressing": {
        "prompt": f"""
A vinyl record pressing plant shown as a sprawling technical cutaway.
Workers operate large hydraulic presses that stamp vinyl records.
The pressing mechanism shown in cross-section: heated vinyl biscuit,
stamper plates, hydraulic rams. Conveyor belts carry finished records.
Label printing machines in the background. Stacks of finished records.
Quality control — a worker holds a record up to light.
Bold overlapping color planes of orange, green, and blue.
On cream/off-white paper background.
{STYLE}
""",
        "filename": "workers-pressing.png",
    },

    "workers-broadcast": {
        "prompt": f"""
A retro radio broadcast station control room with people operating equipment.
A massive broadcast console with dozens of knobs and faders. Reel-to-reel tape decks.
A turntable for playing records. Microphones on boom arms. A large clock on the wall.
The ON AIR sign illuminated in red. Through a window: a radio tower with
concentric broadcast waves. Sound dampening panels on walls.
Workers wear headphones and adjust levels. Geometric color planes of
blue, red, and gold create depth. On cream/off-white paper background.
{STYLE}
""",
        "filename": "workers-broadcast.png",
    },

    "workers-assembly": {
        "prompt": f"""
A Teenage Engineering-style product assembly scene. Workers at long benches
assemble small, precise electronic instruments — pocket synthesizers,
portable sequencers, drum machines. Magnifying lamps over each station.
Soldering irons, tweezers, tiny components. The products have bold orange,
yellow, and cream casings with exposed buttons and knobs.
A robotic arm assists with precision placement. Test oscilloscopes
display waveforms. Bins of colorful knobs and buttons.
Geometric planes of green, orange, and purple behind.
On cream/off-white paper background.
{STYLE}
""",
        "filename": "workers-assembly.png",
    },
}


def generate_image(client, prompt, output_path, retries=3):
    for attempt in range(retries):
        try:
            print(f"  Generating (attempt {attempt + 1})...")
            response = client.models.generate_content(
                model=MODEL,
                contents=prompt.strip(),
                config=types.GenerateContentConfig(response_modalities=["IMAGE"]),
            )
            for part in response.parts:
                if part.inline_data is not None:
                    image = part.as_image()
                    output_path.parent.mkdir(parents=True, exist_ok=True)
                    image.save(str(output_path))
                    print(f"  ✓ Saved: {output_path.name}")
                    return True
            print(f"  ⚠ No image in response")
        except Exception as e:
            print(f"  ✗ Error: {e}")
            if attempt < retries - 1:
                time.sleep(DELAY * 2)
    return False


def main():
    api_key = os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("Set GOOGLE_API_KEY"); sys.exit(1)

    client = genai.Client(api_key=api_key)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    only = None
    if "--only" in sys.argv:
        idx = sys.argv.index("--only")
        if idx + 1 < len(sys.argv): only = sys.argv[idx + 1]

    force = "--force" in sys.argv
    targets = {k: v for k, v in EXTRAS.items() if only is None or k == only}

    print(f"\n🎨 Extra illustrations — people + machines")
    print(f"   {len(targets)} images, ~${len(targets) * 0.04:.2f}\n")

    success = 0
    for name, spec in targets.items():
        path = OUTPUT_DIR / spec["filename"]
        if path.exists() and not force:
            print(f"  ⏭ {name} (exists)"); success += 1; continue
        print(f"  📐 {name}")
        if generate_image(client, spec["prompt"], path):
            success += 1
        time.sleep(DELAY)

    print(f"\n✓ {success}/{len(targets)} generated → {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
