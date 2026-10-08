"""Create Godot-ready transparent 768px RGBA sprites from isolated black-backed renders.

Install: python -m pip install Pillow
Usage: python tools/build_premium_assets.py SOURCE_FOLDER assets/premium/buildings
SOURCE_FOLDER must contain: safehouse.png, hospital.png, barracks.png,
garage.png, intel_office.png, scrapyard.png, data_hub.png, vault.png

All images must use the same fixed isometric camera and consistent lighting.
Review transparent edges manually after extraction.
"""
from collections import deque
from pathlib import Path
from PIL import Image, ImageFilter
import sys

NAMES = ("safehouse", "hospital", "barracks", "garage",
         "intel_office", "scrapyard", "data_hub", "vault")


def convert(source: Path, dest: Path, canvas: int = 768) -> None:
    image = Image.open(source).convert("RGB")
    width, height = image.size
    colors = image.load()
    seen = bytearray(width * height)
    outside = Image.new("L", image.size, 0)
    mask = outside.load()
    todo = deque()
    for x in range(width):
        todo.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        todo.extend(((0, y), (width - 1, y)))

    # Erase only near-black exterior pixels connected to image edges.
    # This retains black and dark details inside the buildings themselves.
    while todo:
        x, y = todo.popleft()
        if x < 0 or x >= width or y < 0 or y >= height:
            continue
        index = y * width + x
        if seen[index]:
            continue
        seen[index] = 1
        red, green, blue = colors[x, y]
        if max(red, green, blue) > 44 or red + green + blue > 90:
            continue
        mask[x, y] = 255
        todo.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))

    alpha = Image.eval(outside, lambda pixel: 255 - pixel)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.45))
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"No building detected in {source}")
    pad = 14
    bounds = (max(0, bounds[0] - pad), max(0, bounds[1] - pad),
              min(width, bounds[2] + pad), min(height, bounds[3] + pad))
    sprite = image.convert("RGBA")
    sprite.putalpha(alpha)
    sprite = sprite.crop(bounds)
    sprite.thumbnail((canvas, canvas), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    result.alpha_composite(sprite, ((canvas - sprite.width) // 2,
                                    (canvas - sprite.height) // 2))
    dest.parent.mkdir(parents=True, exist_ok=True)
    result.save(dest, optimize=True)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: python tools/build_premium_assets.py SOURCE_DIR OUTPUT_DIR")
    source_dir, output_dir = map(Path, sys.argv[1:])
    for name in NAMES:
        convert(source_dir / (name + ".png"), output_dir / (name + ".png"))
        print(f"Prepared {name}.png (RGBA 768x768)")
