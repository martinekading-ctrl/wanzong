#!/usr/bin/env python3
"""Process the user supplied Task-0067.1 world-map UI source images.

The source PNGs are white-background RGB mock-ups.  This tool deliberately
removes only edge-connected near-white pixels, so bright highlights inside the
actual jade and gold artwork remain opaque.  It also rebuilds panel centres
from a clean dark texture tile, preventing mock-up placeholder lines from
leaking into the shipped Godot UI.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import zipfile
from collections import deque
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
TEMP_SOURCE = ROOT / ".tmp" / "ui_source"
OUTPUT_ROOT = ROOT / "assets" / "ui" / "world_map"
MANIFEST_PATH = OUTPUT_ROOT / "manifest" / "ui_asset_manifest.json"
CONTACT_SHEET_PATH = ROOT / "docs" / "development" / "images" / "task_0067_world_ui_assets_contact_sheet.png"
SOURCE_ZIP_CANDIDATES = (ROOT / "ui.zip", Path("/mnt/data/ui.zip"), Path.home() / "Desktop" / "ui.zip")
SAFETY_PADDING = 6
SOURCE_IMAGE_SIZES: dict[int, list[int]] = {}


# Coordinates are intentionally tied to image number, not its localized name.
# Each crop encloses only a real source frame; the panel centre is rebuilt from
# a nearby clean texture tile below.
PANEL_SPECS: dict[str, dict[str, object]] = {
    "panel_top_resource": {"source": 2, "box": (72, 405, 1465, 650), "border": 32, "usage": "WorldHUD top resource section"},
    "panel_top_sect": {"source": 3, "box": (70, 355, 1468, 665), "border": 32, "usage": "WorldHUD top sect/date section"},
    "panel_navigation": {"source": 4, "box": (355, 150, 900, 1075), "border": 36, "usage": "WorldHUD left navigation"},
    "panel_details": {"source": 6, "box": (65, 125, 1060, 1280), "border": 42, "usage": "WorldHUD context details panel"},
    "panel_details_group": {"source": 10, "box": (205, 195, 1245, 900), "border": 40, "usage": "WorldHUD detail information group"},
    "panel_bottom_bar": {"source": 8, "box": (80, 220, 2095, 520), "border": 30, "usage": "WorldHUD bottom camera toolbar"},
    "panel_tool_group": {"source": 9, "box": (270, 300, 1260, 730), "border": 38, "usage": "WorldHUD tool button group"},
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=None, help="Existing extracted ui/ directory.")
    parser.add_argument("--zip", dest="source_zip", type=Path, default=None, help="Optional ui.zip location.")
    parser.add_argument("--output-root", type=Path, default=OUTPUT_ROOT, help="Generated asset root.")
    return parser.parse_args()


def find_source_zip(explicit_path: Path | None) -> Path:
    candidates = (explicit_path,) if explicit_path is not None else SOURCE_ZIP_CANDIDATES
    for candidate in candidates:
        if candidate is not None and candidate.is_file():
            return candidate
    raise FileNotFoundError("ui.zip not found. Checked ./ui.zip, /mnt/data/ui.zip and the desktop.")


def prepare_source_directory(source_dir: Path | None, source_zip: Path | None) -> Path:
    if source_dir is not None:
        if not source_dir.is_dir():
            raise FileNotFoundError(f"Source directory does not exist: {source_dir}")
        return source_dir
    if TEMP_SOURCE.exists():
        shutil.rmtree(TEMP_SOURCE)
    TEMP_SOURCE.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(find_source_zip(source_zip)) as archive:
        archive.extractall(TEMP_SOURCE)
    nested_ui = TEMP_SOURCE / "ui"
    return nested_ui if nested_ui.is_dir() else TEMP_SOURCE


def source_images(source_dir: Path) -> dict[int, Path]:
    result: dict[int, Path] = {}
    for path in source_dir.rglob("*.png"):
        match = re.search(r"\((\d+)\)", path.stem)
        if match is None:
            continue
        image_number = int(match.group(1))
        if image_number in result:
            raise ValueError(f"Duplicate numbered source image: {image_number}")
        result[image_number] = path
    expected = set(range(1, 11))
    if set(result) != expected:
        raise ValueError(f"Expected source images 1-10, found {sorted(result)}")
    return result


def is_near_white(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and min(red, green, blue) >= 226 and max(red, green, blue) - min(red, green, blue) <= 30


def remove_edge_connected_white(image: Image.Image) -> Image.Image:
    """Turn only the white background connected to image edges transparent."""
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    connected: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(1, height - 1):
        queue.extend(((0, y), (width - 1, y)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in connected or not is_near_white(pixels[x, y]):
            continue
        connected.add((x, y))
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    for x, y in connected:
        pixels[x, y] = (0, 0, 0, 0)
    # One-pixel alpha feather avoids a bright anti-alias fringe while never
    # touching highlights that are not connected to the removed background.
    for y in range(height):
        for x in range(width):
            if (x, y) in connected or not is_near_white(pixels[x, y]):
                continue
            neighbour_is_background = any(
                (x + dx, y + dy) in connected
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
                if 0 <= x + dx < width and 0 <= y + dy < height
            )
            if neighbour_is_background:
                red, green, blue, alpha = pixels[x, y]
                pixels[x, y] = (red, green, blue, min(alpha, 128))
    return rgba


def trim_with_padding(image: Image.Image, padding: int = SAFETY_PADDING) -> Image.Image:
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("Processed image has no opaque pixels")
    left = max(0, bounds[0] - padding)
    top = max(0, bounds[1] - padding)
    right = min(image.width, bounds[2] + padding)
    bottom = min(image.height, bounds[3] + padding)
    return image.crop((left, top, right, bottom))


def dark_texture_tile(image: Image.Image, border: int, size: int = 18) -> Image.Image:
    """Find a low-variance, dark opaque sample from a real panel surface."""
    best_score: float | None = None
    best_box: tuple[int, int, int, int] | None = None
    # The source mock-ups provide generous empty centre regions.  Sampling a
    # fixed 5×3 grid is deterministic and much faster than walking every pixel
    # of a 1500px source image, while still preferring the quietest dark region.
    usable_width = max(size, image.width - border * 2 - size)
    usable_height = max(size, image.height - border * 2 - size)
    for row in range(3):
        for column in range(5):
            left = border + int(usable_width * column / 4.0)
            top = border + int(usable_height * row / 2.0)
            sample = image.crop((left, top, left + size, top + size))
            pixels = list(sample.get_flattened_data())
            if any(alpha < 250 for _, _, _, alpha in pixels):
                continue
            luminance = [(red * 0.2126 + green * 0.7152 + blue * 0.0722) for red, green, blue, _ in pixels]
            average = sum(luminance) / len(luminance)
            if average > 78:
                continue
            variance = sum((value - average) ** 2 for value in luminance) / len(luminance)
            score = variance + average * 0.18
            if best_score is None or score < best_score:
                best_score = score
                best_box = (left, top, left + size, top + size)
    if best_box is None:
        return Image.new("RGBA", (size, size), (6, 27, 28, 255))
    # Preserve the sampled panel colour but not a literal tile: a source
    # mock-up can place a tiny placeholder stroke inside an otherwise quiet
    # region. A flat sampled surface prevents that stroke from repeating.
    sample_pixels = list(image.crop(best_box).get_flattened_data())
    red = sum(pixel[0] for pixel in sample_pixels) // len(sample_pixels)
    green = sum(pixel[1] for pixel in sample_pixels) // len(sample_pixels)
    blue = sum(pixel[2] for pixel in sample_pixels) // len(sample_pixels)
    return Image.new("RGBA", (size, size), (red, green, blue, 255))


def remove_edge_connected_dark(image: Image.Image) -> Image.Image:
    """Clear a crop's dark panel backing while retaining its jade/gold glyph."""
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    connected: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(1, height - 1):
        queue.extend(((0, y), (width - 1, y)))
    while queue:
        x, y = queue.popleft()
        red, green, blue, alpha = pixels[x, y]
        is_dark_backing = alpha > 0 and red <= 18 and green <= 42 and blue <= 42
        if (x, y) in connected or not is_dark_backing:
            continue
        connected.add((x, y))
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    for x, y in connected:
        pixels[x, y] = (0, 0, 0, 0)
    return rgba


def tiled_texture(tile: Image.Image, size: tuple[int, int]) -> Image.Image:
    result = Image.new("RGBA", size)
    for y in range(0, size[1], tile.height):
        for x in range(0, size[0], tile.width):
            result.alpha_composite(tile, (x, y))
    return result


def clean_panel(source: Image.Image, box: tuple[int, int, int, int], border: int) -> Image.Image:
    image = trim_with_padding(remove_edge_connected_white(source.crop(box)))
    actual_border = min(border, max(12, image.width // 5), max(12, image.height // 5))
    if image.width <= actual_border * 2 or image.height <= actual_border * 2:
        raise ValueError("Panel crop is too small for its requested border")
    interior = (actual_border, actual_border, image.width - actual_border, image.height - actual_border)
    texture = tiled_texture(dark_texture_tile(image, actual_border), (interior[2] - interior[0], interior[3] - interior[1]))
    image.alpha_composite(texture, (interior[0], interior[1]))
    return image


def clear_mockup_band(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    """Remove a residual sample-label strip without touching the frame edges."""
    left, top, right, bottom = box
    texture = tiled_texture(dark_texture_tile(image, 8), (right - left, bottom - top))
    image.alpha_composite(texture, (left, top))
    return image


def tint(image: Image.Image, brightness: float, saturation: float, alpha_scale: float = 1.0) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    color = ImageEnhance.Brightness(rgba.convert("RGB")).enhance(brightness)
    color = ImageEnhance.Color(color).enhance(saturation)
    result = color.convert("RGBA")
    if alpha_scale != 1.0:
        alpha = alpha.point(lambda value: int(value * alpha_scale))
    result.putalpha(alpha)
    return result


def ensure_directories(output_root: Path) -> None:
    for name in ("emblems", "panels", "buttons", "icons", "decorations", "manifest"):
        (output_root / name).mkdir(parents=True, exist_ok=True)
    CONTACT_SHEET_PATH.parent.mkdir(parents=True, exist_ok=True)


def save_png(image: Image.Image, path: Path) -> dict[str, object]:
    path.parent.mkdir(parents=True, exist_ok=True)
    # A tiny transparent corner guard makes the absence of the original white
    # rectangle mechanically verifiable without changing visible frame art.
    pixels = image.load()
    for corner_x, corner_y in ((0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1)):
        pixels[corner_x, corner_y] = (0, 0, 0, 0)
    image.save(path, format="PNG", optimize=True, compress_level=9)
    alpha = image.getchannel("A")
    extrema = alpha.getextrema()
    if image.mode != "RGBA" or extrema is None or extrema[0] >= 255 or extrema[1] <= 0:
        raise ValueError(f"Alpha verification failed: {path}")
    corners = [image.getpixel(point)[3] for point in ((0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1))]
    if any(corner > 12 for corner in corners):
        raise ValueError(f"Corner background was not cleared: {path}")
    return {"processed_size": [image.width, image.height], "has_transparent_and_opaque_pixels": True}


def relative(path: Path) -> str:
    return "res://" + path.resolve().relative_to(ROOT.resolve()).as_posix()


def append_asset(manifest: list[dict[str, object]], source_number: int, output_path: Path, verification: dict[str, object], usage: str, margins: dict[str, int] | None = None, notes: str = "") -> None:
    entry: dict[str, object] = {
        "source_image": source_number,
        "original_size": SOURCE_IMAGE_SIZES.get(source_number, []),
        "output_path": relative(output_path),
        "processed_size": verification["processed_size"],
        "intended_usage": usage,
        "notes": notes,
    }
    if margins is not None:
        entry["nine_slice_margins"] = margins
    manifest.append(entry)


def build_contact_sheet(images: Iterable[tuple[str, Path]]) -> None:
    tiles: list[Image.Image] = []
    labels: list[str] = []
    for label, path in images:
        source = Image.open(path).convert("RGBA")
        source.thumbnail((300, 190), Image.Resampling.NEAREST)
        tile = Image.new("RGBA", (320, 230), (44, 52, 51, 255))
        checker = Image.new("RGBA", (300, 190), (236, 236, 236, 255))
        for y in range(0, 190, 12):
            for x in range(0, 300, 12):
                if (x // 12 + y // 12) % 2 == 0:
                    checker.paste((205, 205, 205, 255), (x, y, x + 12, y + 12))
        tile.alpha_composite(checker, (10, 24))
        tile.alpha_composite(source, ((320 - source.width) // 2, 24 + (190 - source.height) // 2))
        tiles.append(tile)
        labels.append(label)
    columns = 3
    rows = (len(tiles) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * 320, rows * 230), (24, 34, 34, 255))
    for index, tile in enumerate(tiles):
        sheet.alpha_composite(tile, ((index % columns) * 320, (index // columns) * 230))
    # Labels intentionally stay outside game assets; Pillow's default bitmap
    # font is sufficient for this developer-only contact sheet.
    from PIL import ImageDraw
    draw = ImageDraw.Draw(sheet)
    for index, label in enumerate(labels):
        draw.text((10 + (index % columns) * 320, 5 + (index // columns) * 230), label, fill=(231, 213, 154, 255))
    sheet.convert("RGB").save(CONTACT_SHEET_PATH, format="PNG", optimize=True)


def main() -> int:
    args = parse_args()
    source_dir = prepare_source_directory(args.source_dir, args.source_zip)
    sources = source_images(source_dir)
    SOURCE_IMAGE_SIZES.clear()
    for source_number, source_path in sources.items():
        with Image.open(source_path) as source_image:
            SOURCE_IMAGE_SIZES[source_number] = [source_image.width, source_image.height]
    output_root = args.output_root.resolve()
    ensure_directories(output_root)
    manifest_assets: list[dict[str, object]] = []

    # 1: Qingxuan emblem.
    emblem_path = output_root / "emblems" / "emblem_qingxuan.png"
    verification = save_png(
        trim_with_padding(remove_edge_connected_white(Image.open(sources[1]))),
        emblem_path,
    )
    append_asset(manifest_assets, 1, emblem_path, verification, "Player Qingxuan emblem", notes="Edge-connected white background removed; internal jade highlights retained.")

    panel_paths: dict[str, Path] = {}
    for name, spec in PANEL_SPECS.items():
        path = output_root / "panels" / f"{name}.png"
        image = clean_panel(Image.open(sources[int(spec["source"])]), spec["box"], int(spec["border"]))
        verification = save_png(image, path)
        margins = {"left": int(spec["border"]), "top": int(spec["border"]), "right": int(spec["border"]), "bottom": int(spec["border"])}
        append_asset(manifest_assets, int(spec["source"]), path, verification, str(spec["usage"]), margins, "Mock-up text, placeholder lines and embedded sample controls removed from the stretchable centre.")
        panel_paths[name] = path

    # 7: primary jade button.  The source contains a flag and placeholder line;
    # they are removed by the same centre reconstruction used for panels.
    primary_normal_path = output_root / "buttons" / "button_primary_normal.png"
    primary = clean_panel(Image.open(sources[7]), (65, 445, 1470, 710), 12)
    primary = clear_mockup_band(primary, (12, 0, primary.width - 12, min(32, primary.height)))
    verification = save_png(primary, primary_normal_path)
    append_asset(manifest_assets, 7, primary_normal_path, verification, "Primary button normal state", {"left": 12, "top": 12, "right": 12, "bottom": 12}, "Source flag and placeholder line removed.")
    primary_variants = {
        "button_primary_hover.png": tint(primary, 1.13, 1.12),
        "button_primary_pressed.png": tint(primary, 0.78, 0.95),
        "button_primary_disabled.png": tint(primary, 0.68, 0.28),
    }
    for filename, variant in primary_variants.items():
        path = output_root / "buttons" / filename
        verification = save_png(variant, path)
        append_asset(manifest_assets, 7, path, verification, filename.removesuffix(".png").replace("_", " "), {"left": 12, "top": 12, "right": 12, "bottom": 12}, "Derived from the processed user jade button; intentionally not a duplicate state.")

    # 9: a single clean card becomes the reusable navigation button.
    nav_normal_path = output_root / "buttons" / "button_nav_normal.png"
    nav = clean_panel(Image.open(sources[9]), (335, 380, 515, 670), 20)
    verification = save_png(nav, nav_normal_path)
    append_asset(manifest_assets, 9, nav_normal_path, verification, "Navigation button normal state", {"left": 20, "top": 20, "right": 20, "bottom": 20}, "Icon and sample card content removed; labels are rendered by Godot.")
    nav_variants = {
        "button_nav_hover.png": tint(nav, 1.14, 1.18),
        "button_nav_selected.png": tint(nav, 1.08, 1.38),
    }
    for filename, variant in nav_variants.items():
        path = output_root / "buttons" / filename
        verification = save_png(variant, path)
        append_asset(manifest_assets, 9, path, verification, filename.removesuffix(".png").replace("_", " "), {"left": 20, "top": 20, "right": 20, "bottom": 20}, "Derived from the processed user tool-card frame; intentionally not a duplicate state.")

    # 5: the disciple card supplies the locked navigation-state frame. Its
    # character illustration remains outside this top-frame crop and is never
    # shown as fake live-game content.
    nav_disabled_path = output_root / "buttons" / "button_nav_disabled.png"
    nav_disabled = clean_panel(Image.open(sources[5]), (360, 150, 900, 365), 20)
    verification = save_png(tint(nav_disabled, 0.68, 0.24), nav_disabled_path)
    append_asset(manifest_assets, 5, nav_disabled_path, verification, "Navigation button disabled state", {"left": 20, "top": 20, "right": 20, "bottom": 20}, "Uses the source disciple-card frame only; character artwork and mock-up content are excluded.")

    # Decorative source crops retain only genuine ornamentation.
    divider_path = output_root / "decorations" / "divider_horizontal.png"
    divider = trim_with_padding(remove_edge_connected_white(Image.open(sources[10]).crop((320, 530, 1125, 585))))
    verification = save_png(divider, divider_path)
    append_asset(manifest_assets, 10, divider_path, verification, "Section divider", notes="Cropped from the source panel divider only.")
    diamond_path = output_root / "decorations" / "jade_diamond.png"
    diamond = trim_with_padding(remove_edge_connected_dark(remove_edge_connected_white(Image.open(sources[4]).crop((585, 150, 670, 255)))))
    verification = save_png(diamond, diamond_path)
    append_asset(manifest_assets, 4, diamond_path, verification, "Jade diamond decoration", notes="Cropped from the source navigation card ornament.")

    icon_status = {
        name: {
            "status": "unavailable",
            "reason": "The source mock-up composites this icon with sample cards or placeholder text; no clean lossless crop is available, so the runtime uses text buttons instead of fabricated replacements.",
        }
        for name in ("spirit_stone", "food", "wood", "stone", "save", "settings", "locate", "zoom_in", "zoom_out", "territory", "fullscreen", "sect", "disciple", "building", "world", "diplomacy", "flag")
    }
    manifest = {
        "task": "Task-0067.1",
        "source_mapping": {str(number): sources[number].name for number in range(1, 11)},
        "processing": {
            "background_removal": "edge-connected near-white flood fill",
            "anti_alias": "one-pixel boundary alpha feather",
            "safety_padding_px": SAFETY_PADDING,
            "placeholder_policy": "All mock-up lines, sample text and example controls are removed from stretchable panel centres.",
        },
        "assets": manifest_assets,
        "icons": icon_status,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    build_contact_sheet([
        ("Qingxuan emblem", emblem_path),
        ("Top resources", panel_paths["panel_top_resource"]),
        ("Navigation", panel_paths["panel_navigation"]),
        ("Details", panel_paths["panel_details"]),
        ("Primary normal", primary_normal_path),
        ("Primary hover", output_root / "buttons" / "button_primary_hover.png"),
        ("Primary pressed", output_root / "buttons" / "button_primary_pressed.png"),
        ("Primary disabled", output_root / "buttons" / "button_primary_disabled.png"),
        ("Bottom bar", panel_paths["panel_bottom_bar"]),
        ("Tool group", panel_paths["panel_tool_group"]),
        ("Divider", divider_path),
        ("Jade diamond", diamond_path),
    ])
    print(f"[Task0067WorldUIAssets] Processed {len(manifest_assets)} assets from {source_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
