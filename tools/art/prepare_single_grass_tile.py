#!/usr/bin/env python3
"""Extract the supplied grass tile without altering its interior colours."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    with Image.open(args.input) as source:
        rgba = np.asarray(source.convert("RGBA"), dtype=np.uint8).copy()

    # The backdrop is a softly varying presentation canvas. Flood only from the
    # outer edge so matching flowers, rocks and highlights inside the tile stay.
    flood = Image.fromarray(rgba[:, :, :3], "RGB")
    marker = (1, 254, 2)
    ImageDraw.floodfill(flood, (0, 0), marker, thresh=54)
    flooded = np.asarray(flood, dtype=np.uint8)
    background = np.all(flooded == np.asarray(marker, dtype=np.uint8), axis=2)
    rgba[background] = (0, 0, 0, 0)

    image = Image.fromarray(rgba, "RGBA")
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise SystemExit("background removal produced an empty image")
    left, top, right, bottom = bounds
    padding = 8
    crop = (
        max(0, left - padding),
        max(0, top - padding),
        min(image.width, right + padding),
        min(image.height, bottom + padding),
    )
    image = image.crop(crop)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.out, compress_level=4)

    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    transparent = int(np.count_nonzero(alpha == 0))
    print(f"Wrote {args.out} ({image.width}x{image.height})")
    print(f"Transparent pixels: {transparent}/{alpha.size}")


if __name__ == "__main__":
    main()
