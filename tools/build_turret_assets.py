#!/usr/bin/env python3
"""Split the generated turret sheet into transparent base/head sprites for Godot.
Run from project root. Requires Pillow and NumPy; runtime game does not depend on them.
"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source" / "turret_generated_sheet.png"
ASSETS = ROOT / "assets"


def extract(name: str, source_box: tuple[int, int, int, int]) -> None:
    image = Image.open(SOURCE).convert("RGBA").crop(source_box)
    pixels = np.asarray(image).copy()
    pixels[:, :, 3][pixels[:, :, 3] < 36] = 0
    image = Image.fromarray(pixels, "RGBA")
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > 25)
    if xs.size == 0:
        raise RuntimeError(f"No visible sprite pixels found for {name}")
    pad = 8
    bounds = (
        max(0, int(xs.min()) - pad), max(0, int(ys.min()) - pad),
        min(image.width, int(xs.max()) + 1 + pad), min(image.height, int(ys.max()) + 1 + pad),
    )
    image.crop(bounds).save(ASSETS / name, optimize=True)
    print(f"Wrote {ASSETS / name}")


if __name__ == "__main__":
    extract("turret_head.png", (180, 0, 1460, 430))
    extract("turret_base.png", (150, 450, 1320, 1020))
