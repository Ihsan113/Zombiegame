"""Extract five clean Brute attack poses per animation from the supplied reference atlas.

The source is a packed collage, not a perfectly aligned 256 px grid: several claws and
lunge silhouettes cross naïve cell boundaries. This builder keys its checker background,
labels actual foreground silhouettes, and crops each pose by its connected-component bounds
before placing it in a common, ground-aligned RGBA frame.
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source" / "boss_brute_spritesheet_source.jpg"
ASSETS = ROOT / "assets"
FRAME_WIDTH = 336
FRAME_HEIGHT = 226
FRAME_COUNT = 5

image = Image.open(SOURCE).convert("RGB")
a = np.asarray(image, dtype=np.int16)
h, w = a.shape[:2]
gray_spread = a.max(axis=2) - a.min(axis=2)
luma = a.mean(axis=2)
# The checker was baked into the JPEG in neutral gray shades near RGB 123 / 198.
candidate = (gray_spread <= 10) & (luma >= 112) & (luma <= 212)
_, labels = cv2.connectedComponents(candidate.astype(np.uint8), connectivity=8)
edge_labels = np.unique(np.concatenate([labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]]))
bg_connected = np.isin(labels, edge_labels) & candidate
palette_match = (gray_spread <= 14) & ((np.abs(luma - 123) <= 14) | (np.abs(luma - 198) <= 14))
bg = cv2.dilate((bg_connected | palette_match).astype(np.uint8), np.ones((3, 3), np.uint8), iterations=1).astype(bool)
rgba = np.dstack([np.clip(a, 0, 255).astype(np.uint8), np.where(bg, 0, 255).astype(np.uint8)])
clean = Image.fromarray(rgba, "RGBA")

# Each row's large connected components are the distinct painted poses. For ground slam,
# reorder the leftmost upright pose to become the recovery frame and skip the redundant
# impact/dust pose so the sequence reads wind-up -> strike -> impact -> recovery.
sequences = {
    "boss_attack_slash_sheet.png": {"row": (443, 660), "skip_first": False},
    "boss_attack_slam_sheet.png": {"row": (225, 443), "skip_first": True},
    "boss_attack_lunge_sheet.png": {"row": (660, 857), "skip_first": False},
}


def resize_rgba_premultiplied(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    arr = np.asarray(im.convert("RGBA"), dtype=np.float32)
    alpha = arr[..., 3:4] / 255.0
    premultiplied = arr[..., :3] * alpha
    packed = Image.fromarray(
        np.clip(np.concatenate([premultiplied, alpha * 255.0], axis=2), 0, 255).astype(np.uint8), "RGBA"
    )
    resized = np.asarray(packed.resize(size, Image.Resampling.LANCZOS), dtype=np.float32)
    out_alpha = resized[..., 3:4] / 255.0
    out_rgb = np.zeros_like(resized[..., :3])
    valid = out_alpha[..., 0] > 1e-4
    out_rgb[valid] = resized[..., :3][valid] / out_alpha[valid]
    return Image.fromarray(
        np.clip(np.concatenate([out_rgb, resized[..., 3:4]], axis=2), 0, 255).astype(np.uint8), "RGBA"
    )


for filename, spec in sequences.items():
    y0, y1 = spec["row"]
    row_alpha = np.asarray(clean.crop((0, y0, w, y1)).getchannel("A"))
    count, _, stats, _ = cv2.connectedComponentsWithStats((row_alpha > 0).astype(np.uint8), connectivity=8)
    components = []
    for label in range(1, count):
        x, y, cw, ch, area = (int(v) for v in stats[label])
        if area >= 5000:
            components.append((x, y, cw, ch, area))
    components.sort(key=lambda item: item[0])
    if spec["skip_first"]:
        # The final frame is the leftmost upright recovery pose. Drop the redundant
        # dust-heavy impact from the source collage to keep a clean five-frame sequence.
        components = components[1:4] + [components[5], components[0]]
    if len(components) != FRAME_COUNT:
        raise RuntimeError(f"{filename}: expected {FRAME_COUNT} foreground poses, found {len(components)}")

    frames = []
    for x, y, cw, ch, area in components:
        # Keep a few pixels of padding so the painted outline doesn't touch the crop edge.
        cx0 = max(0, x - 6)
        cy0 = max(y0, y0 + y - 6)
        cx1 = min(w, x + cw + 6)
        cy1 = min(y1, y0 + y + ch + 6)
        crop = clean.crop((cx0, cy0, cx1, cy1))
        max_w, max_h = FRAME_WIDTH - 12, FRAME_HEIGHT - 12
        scale = min(max_w / crop.width, max_h / crop.height)
        size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
        pose = resize_rgba_premultiplied(crop, size)
        canvas = Image.new("RGBA", (FRAME_WIDTH, FRAME_HEIGHT), (0, 0, 0, 0))
        px = (FRAME_WIDTH - pose.width) // 2
        py = FRAME_HEIGHT - 7 - pose.height
        canvas.alpha_composite(pose, (px, py))
        frames.append(canvas)

    strip = Image.new("RGBA", (FRAME_WIDTH * FRAME_COUNT, FRAME_HEIGHT), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_WIDTH, 0))
    out = ASSETS / filename
    strip.save(out, optimize=True)
    print(f"{filename}: {strip.size}; frame bounds={[frame.getchannel('A').getbbox() for frame in frames]}; {out.stat().st_size} bytes")

    # A local visual review file, not loaded by the game runtime.
    preview = Image.new("RGBA", strip.size, (35, 42, 43, 255))
    preview.alpha_composite(strip)
    preview.convert("RGB").save(ROOT / ("tmp_" + Path(filename).with_suffix(".jpg").name), quality=92)
