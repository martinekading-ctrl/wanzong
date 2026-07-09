"""Process Task-0026 world-object source PNGs without modifying originals."""

from __future__ import annotations

import argparse
import json
from collections import Counter, deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ASSET_GROUPS = {
    "普通阔叶树": ("trees", "tree_green", 5, "screenshot_color"),
    "松树  针叶树": ("trees", "tree_pine", 2, "alpha_checker"),
    "竹林": ("bamboo", "bamboo", 3, "screenshot_color"),
    "枯树  灵木  特殊树": (
        "special",
        ("tree_dead_01", "tree_dead_02", "resource_spirit_tree_01"),
        3,
        "existing_alpha",
    ),
    "小石头  岩石": ("rocks", "rock", 8, "screenshot_gray"),
    "山丘": ("hills", "hill_grass", 4, "screenshot_color"),
    "灰岩山峰": ("mountains", "mountain_rock", 6, "screenshot_gray"),
    "雪山峰": ("mountains", "mountain_snow", 4, "screenshot_snow"),
}


def color_distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    return sum((left[index] - right[index]) ** 2 for index in range(3))


def find_checker_colors(image: Image.Image) -> list[tuple[int, int, int]]:
    counts = Counter(image.convert("RGB").get_flattened_data())
    neutral = [
        (count, color)
        for color, count in counts.items()
        if max(color) - min(color) <= 6 and 145 <= sum(color) // 3 <= 225
    ]
    neutral.sort(reverse=True)
    colors: list[tuple[int, int, int]] = []
    for _count, color in neutral:
        if all(color_distance(color, existing) > 18 * 18 * 3 for existing in colors):
            colors.append(color)
        if len(colors) == 2:
            break
    if len(colors) != 2:
        raise ValueError("could not identify both checkerboard colors")
    return colors


def remove_screenshot_checker(
    image: Image.Image,
    protect_neutral_subject: bool,
    include_near_white_background: bool = False,
) -> tuple[Image.Image, dict]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    checker_colors = find_checker_colors(rgba)
    flood_distance = 8 * 8 * 3

    pixels = np.asarray(rgba).copy()
    rgb = pixels[:, :, :3].astype(np.int32)
    distances = [
        np.sum((rgb - np.asarray(color, dtype=np.int32)) ** 2, axis=2)
        for color in checker_colors
    ]
    nearest = np.minimum(distances[0], distances[1])
    candidate_mask = nearest <= flood_distance
    if include_near_white_background:
        channel_range = np.max(rgb, axis=2) - np.min(rgb, axis=2)
        mean_brightness = np.mean(rgb, axis=2)
        candidate_mask |= (channel_range <= 24) & (mean_brightness >= 145.0)
    candidate = Image.fromarray(
        np.where(candidate_mask, 255, 0).astype(np.uint8),
        "L",
    ).copy()
    border_seeds = (
        [(x, 0) for x in range(candidate.width)]
        + [(x, candidate.height - 1) for x in range(candidate.width)]
        + [(0, y) for y in range(candidate.height)]
        + [(candidate.width - 1, y) for y in range(candidate.height)]
    )
    for seed in border_seeds:
        if candidate.getpixel(seed) == 255:
            ImageDraw.floodfill(candidate, seed, 128)
    removal_mask = np.asarray(candidate) == 128
    if not protect_neutral_subject:
        channel_range = np.max(rgb, axis=2) - np.min(rgb, axis=2)
        mean_brightness = np.mean(rgb, axis=2)
        removal_mask |= (
            (channel_range <= 14)
            & (mean_brightness >= 145.0)
            & (mean_brightness <= 235.0)
        )
    pixels[:, :, 3][removal_mask] = 0
    removed = int(np.count_nonzero(removal_mask))

    return Image.fromarray(pixels, "RGBA"), {
        "method": (
            "checkerboard exterior flood removal"
            if protect_neutral_subject
            else "checkerboard neutral-color and exterior removal"
        ),
        "checker_colors": [list(color) for color in checker_colors],
        "removed_pixels": removed,
    }


def remove_alpha_checker(image: Image.Image) -> tuple[Image.Image, dict]:
    rgba = image.convert("RGBA")
    pixels = np.asarray(rgba).copy()
    rgb = pixels[:, :, :3]
    alpha = pixels[:, :, 3]
    near_white = (np.min(rgb, axis=2) >= 180) & (
        np.max(rgb, axis=2).astype(np.int16) - np.min(rgb, axis=2).astype(np.int16) <= 36
    )
    removal_mask = (alpha <= 20) | near_white
    pixels[:, :, 3][removal_mask] = 0
    return Image.fromarray(pixels, "RGBA"), {
        "method": "alpha and near-white checker removal",
        "removed_pixels": int(np.count_nonzero(removal_mask)),
    }


def remove_snow_checker(image: Image.Image) -> tuple[Image.Image, dict]:
    rgba = image.convert("RGBA")
    pixels = np.asarray(rgba).copy()
    rgb = pixels[:, :, :3].astype(np.int16)
    channel_range = np.max(rgb, axis=2) - np.min(rgb, axis=2)
    mean_brightness = np.mean(rgb, axis=2)
    subject_core = (channel_range >= 22) | (mean_brightness < 145.0)
    subject_mask = np.zeros(subject_core.shape, dtype=bool)

    for row_index in range(subject_core.shape[0]):
        columns = np.flatnonzero(subject_core[row_index])
        if columns.size < 2:
            continue
        subject_mask[row_index, columns[0] : columns[-1] + 1] = True

    pixels[:, :, 3][~subject_mask] = 0
    return Image.fromarray(pixels, "RGBA"), {
        "method": "snow mountain silhouette reconstruction",
        "removed_pixels": int(np.count_nonzero(~subject_mask)),
    }


def preserve_existing_alpha(image: Image.Image) -> tuple[Image.Image, dict]:
    rgba = image.convert("RGBA")
    return rgba, {"method": "preserved source alpha", "removed_pixels": 0}


def opaque_components(image: Image.Image, threshold: int = 16) -> list[list[tuple[int, int]]]:
    alpha = image.getchannel("A")
    width, height = image.size
    data = alpha.load()
    visited = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            index = y * width + x
            if visited[index] or data[x, y] <= threshold:
                continue
            visited[index] = 1
            queue = deque([(x, y)])
            component: list[tuple[int, int]] = []
            while queue:
                current_x, current_y = queue.popleft()
                component.append((current_x, current_y))
                for next_x, next_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if not (0 <= next_x < width and 0 <= next_y < height):
                        continue
                    next_index = next_y * width + next_x
                    if visited[next_index] or data[next_x, next_y] <= threshold:
                        continue
                    visited[next_index] = 1
                    queue.append((next_x, next_y))
            components.append(component)
    components.sort(key=len, reverse=True)
    return components


def remove_distant_fragments(image: Image.Image) -> tuple[Image.Image, int]:
    scale = min(1.0, 256.0 / float(max(image.size)))
    analysis_size = (
        max(1, int(round(image.width * scale))),
        max(1, int(round(image.height * scale))),
    )
    analysis_alpha = image.getchannel("A").resize(analysis_size, Image.Resampling.NEAREST)
    analysis_image = Image.new("RGBA", analysis_size)
    analysis_image.putalpha(analysis_alpha)
    components = opaque_components(analysis_image)
    if not components:
        raise ValueError("no opaque subject remained after background removal")

    largest = components[0]
    left = min(point[0] for point in largest)
    top = min(point[1] for point in largest)
    right = max(point[0] for point in largest)
    bottom = max(point[1] for point in largest)
    margin_x = max(3, int((right - left + 1) * 0.22))
    margin_y = max(3, int((bottom - top + 1) * 0.22))
    subject_box = (
        max(0, left - margin_x),
        max(0, top - margin_y),
        min(analysis_image.width - 1, right + margin_x),
        min(analysis_image.height - 1, bottom + margin_y),
    )

    removed_components = 0
    for component in components:
        component_box = (
            min(point[0] for point in component),
            min(point[1] for point in component),
            max(point[0] for point in component),
            max(point[1] for point in component),
        )
        intersects = not (
            component_box[2] < subject_box[0]
            or component_box[0] > subject_box[2]
            or component_box[3] < subject_box[1]
            or component_box[1] > subject_box[3]
        )
        if not intersects:
            removed_components += 1

    inverse_scale = 1.0 / scale
    crop_box = (
        max(0, int(subject_box[0] * inverse_scale)),
        max(0, int(subject_box[1] * inverse_scale)),
        min(image.width, int((subject_box[2] + 1) * inverse_scale)),
        min(image.height, int((subject_box[3] + 1) * inverse_scale)),
    )
    return image.crop(crop_box), removed_components


def crop_transparent(image: Image.Image, padding: int = 4) -> Image.Image:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("image is fully transparent")
    left, top, right, bottom = bounds
    return image.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(image.width, right + padding),
            min(image.height, bottom + padding),
        )
    )


def resize_for_runtime(image: Image.Image, max_dimension: int = 512) -> Image.Image:
    longest_edge = max(image.size)
    if longest_edge <= max_dimension:
        return image
    scale = float(max_dimension) / float(longest_edge)
    target_size = (
        max(1, int(round(image.width * scale))),
        max(1, int(round(image.height * scale))),
    )
    return image.resize(target_size, Image.Resampling.NEAREST)


def output_name(prefix: str | tuple[str, ...], index: int) -> str:
    if isinstance(prefix, tuple):
        return f"{prefix[index]}.png"
    return f"{prefix}_{index + 1:02d}.png"


def process(source_root: Path, output_root: Path) -> dict:
    report = {"processed": [], "skipped": []}
    source_directories = {path.name: path for path in source_root.rglob("*") if path.is_dir()}
    output_root.mkdir(parents=True, exist_ok=True)
    for category in ("trees", "bamboo", "rocks", "hills", "mountains", "special"):
        (output_root / category).mkdir(parents=True, exist_ok=True)

    for source_name, (category, prefix, expected_count, mode) in ASSET_GROUPS.items():
        source_directory = source_directories.get(source_name)
        if source_directory is None:
            report["skipped"].append({"source": source_name, "reason": "source directory missing"})
            continue
        files = sorted(source_directory.glob("*.png"))
        if len(files) != expected_count:
            report["skipped"].append(
                {
                    "source": source_name,
                    "reason": f"expected {expected_count} PNG files, found {len(files)}",
                }
            )
            continue

        for index, source_path in enumerate(files):
            destination = output_root / category / output_name(prefix, index)
            try:
                source = Image.open(source_path)
                if mode == "screenshot_gray":
                    processed, details = remove_screenshot_checker(source, True)
                elif mode == "screenshot_snow":
                    processed, details = remove_snow_checker(source)
                elif mode == "screenshot_color":
                    processed, details = remove_screenshot_checker(source, False)
                elif mode == "alpha_checker":
                    processed, details = remove_alpha_checker(source)
                else:
                    processed, details = preserve_existing_alpha(source)
                processed, removed_components = remove_distant_fragments(processed)
                processed = crop_transparent(processed)
                processed = resize_for_runtime(processed)
                processed.save(destination, "PNG", compress_level=6)
                details["removed_distant_components"] = removed_components
                report["processed"].append(
                    {
                        "source": str(source_path),
                        "output": str(destination),
                        "source_size": list(source.size),
                        "output_size": list(processed.size),
                        **details,
                    }
                )
            except Exception as error:
                report["skipped"].append({"source": str(source_path), "reason": str(error)})

    report["processed_count"] = len(report["processed"])
    report["skipped_count"] = len(report["skipped"])
    (output_root / "processing_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    report = process(args.source_root, args.output_root)
    print(json.dumps({"processed": report["processed_count"], "skipped": report["skipped_count"]}))


if __name__ == "__main__":
    main()
