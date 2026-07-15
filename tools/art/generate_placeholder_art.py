#!/usr/bin/env python3
"""Deterministic placeholder art generator for Task-0068.0.

The generated assets are intentionally replaceable pre-alpha placeholders.  The
script is offline, uses a fixed seed, writes only task-owned directories and
records every output in a manifest consumed by Godot-side validation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import shutil
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw


SEED = 20260715
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "placeholder_art"
CONTACTS = ROOT / "docs" / "art" / "contact_sheets"
MANIFEST_PATH = OUT / "manifest" / "placeholder_art_manifest.json"

INK = "#102b2d"
INK_DARK = "#07191c"
INK_LIGHT = "#1e4b4d"
JADE = "#4fae9d"
JADE_BRIGHT = "#79d1bc"
GOLD = "#967a49"
GOLD_BRIGHT = "#c7a866"
RICE = "#eee5cb"
MUTED = "#9da79b"
WOOD = "#5c3f2b"
RED = "#9a4942"

SECT_PALETTES = {
    "qingxuan": ("#173b3d", "#53b29f", "#b99a58", "#e9dfc5"),
    "lingxiao": ("#18334d", "#5a91b8", "#b9c5cd", "#e7eef1"),
    "chilu": ("#552b25", "#b65742", "#c69a4f", "#f0d9bd"),
    "xuesha": ("#281c2b", "#7e3042", "#604067", "#d1b7c2"),
    "jinlian": ("#4b432f", "#b29755", "#d6c79a", "#f1ead5"),
}

manifest: list[dict] = []


def stable_seed(name: str) -> int:
    digest = hashlib.sha256(f"{SEED}:{name}".encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big")


def rgba(color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = color.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def save_asset(
    image: Image.Image,
    rel: str,
    category: str,
    *,
    usage: str = "replaceable placeholder",
    transparent: bool = True,
    nine_patch: bool = False,
    sprite_sheet: bool = False,
    frame_size: tuple[int, int] | None = None,
) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    if image.mode != "RGBA":
        image = image.convert("RGBA")
    image.save(path, format="PNG", optimize=True)
    alpha = image.getchannel("A")
    alpha_min, alpha_max = alpha.getextrema()
    if image.width <= 0 or image.height <= 0 or alpha_max == 0:
        raise RuntimeError(f"empty image: {rel}")
    if transparent and alpha_min == 255:
        raise RuntimeError(f"expected alpha transparency: {rel}")
    record = {
        "asset_id": Path(rel).stem,
        "category": category,
        "usage": usage,
        "path": f"res://assets/placeholder_art/{rel.replace('\\', '/')}",
        "width": image.width,
        "height": image.height,
        "transparent": transparent,
        "nine_patch": nine_patch,
        "sprite_sheet": sprite_sheet,
        "frame_size": list(frame_size) if frame_size else None,
        "seed": SEED,
        "replace_via": "replace PNG and update theme or manifest",
    }
    manifest.append(record)


def pixel_frame(
    size: tuple[int, int],
    fill: tuple[int, int, int, int],
    border: str = GOLD,
    accent: str = JADE,
    *,
    corners: bool = True,
) -> Image.Image:
    w, h = size
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((2, 2, w - 3, h - 3), fill=fill, outline=rgba(border), width=2)
    draw.rectangle((5, 5, w - 6, h - 6), outline=rgba(INK_LIGHT, 190), width=1)
    if corners:
        for x, y, sx, sy in ((4, 4, 1, 1), (w - 5, 4, -1, 1), (4, h - 5, 1, -1), (w - 5, h - 5, -1, -1)):
            draw.line((x, y, x + 8 * sx, y), fill=rgba(accent), width=2)
            draw.line((x, y, x, y + 8 * sy), fill=rgba(accent), width=2)
    for x in range(15, w - 15, 24):
        draw.point((x, 7), fill=rgba(GOLD_BRIGHT, 160))
        draw.point((x, h - 8), fill=rgba(GOLD_BRIGHT, 160))
    return image


def generate_ui() -> None:
    panels = [
        "panel_screen_background", "panel_top_bar", "panel_left_navigation",
        "panel_right_details", "panel_bottom_bar", "panel_content",
        "panel_content_elevated", "panel_dialog", "panel_tooltip", "panel_card",
        "panel_list_item", "panel_resource_strip", "panel_portrait",
        "panel_empty_state", "panel_warning", "panel_success",
    ]
    for name in panels:
        fill = rgba(INK, 225)
        accent = JADE
        if "warning" in name:
            accent = RED
        elif "success" in name:
            accent = JADE_BRIGHT
        elif "elevated" in name or "dialog" in name:
            fill = rgba(INK_LIGHT, 238)
        image = pixel_frame((128, 128), fill, GOLD, accent)
        save_asset(image, f"ui/panels/{name}.png", "global_ui", nine_patch=True)

    button_types = [
        "primary", "secondary", "ghost", "danger", "navigation",
        "navigation_selected", "icon_button", "tab", "tab_selected", "small", "large",
    ]
    states = ["normal", "hover", "pressed", "disabled", "focus"]
    state_values = {
        "normal": (rgba(INK_LIGHT, 238), GOLD),
        "hover": (rgba("#245f5a", 245), JADE_BRIGHT),
        "pressed": (rgba("#123638", 250), JADE),
        "disabled": (rgba("#242d2b", 190), "#555f58"),
        "focus": (rgba(INK_LIGHT, 245), GOLD_BRIGHT),
    }
    for kind in button_types:
        size = (64, 48) if kind == "icon_button" else ((112, 40) if kind == "small" else (192, 56))
        for state in states:
            fill, border = state_values[state]
            if kind == "danger" and state not in ("disabled",):
                fill, border = rgba("#5a2a2c", 240), RED
            if kind == "ghost":
                fill = rgba(INK_DARK, 115 if state == "normal" else 185)
            image = pixel_frame(size, fill, border, JADE, corners=True)
            if state == "pressed":
                ImageDraw.Draw(image).line((10, size[1] - 8, size[0] - 11, size[1] - 8), fill=rgba(INK_DARK), width=2)
            save_asset(image, f"ui/buttons/{kind}_{state}.png", "global_ui", nine_patch=kind != "icon_button")

    components = {
        "bars": ["progress_background", "progress_fill_jade", "progress_fill_gold", "progress_fill_red", "scrollbar_track", "scrollbar_thumb", "slider_track", "slider_thumb"],
        "decorations": ["horizontal_divider", "vertical_divider", "dropdown_arrow", "tooltip_pointer", "notification_dot"],
        "badges": ["badge_player", "badge_ally", "badge_neutral", "badge_hostile", "badge_locked", "badge_new"],
        "frames": ["selected_frame", "hover_frame", "portrait_frame", "emblem_frame", "item_slot", "building_slot"],
        "tabs": ["checkbox_off", "checkbox_on", "radio_off", "radio_on"],
        "cursors": ["cursor_default", "cursor_select", "cursor_move"],
    }
    for folder, names in components.items():
        for name in names:
            if "horizontal" in name or "progress" in name or "slider" in name or "scrollbar_track" in name:
                size = (128, 16)
            elif "vertical" in name:
                size = (16, 128)
            else:
                size = (48, 48)
            image = Image.new("RGBA", size, (0, 0, 0, 0))
            draw = ImageDraw.Draw(image)
            color = JADE
            if "gold" in name or "player" in name:
                color = GOLD_BRIGHT
            elif "red" in name or "hostile" in name:
                color = RED
            elif "neutral" in name or "disabled" in name:
                color = MUTED
            if "frame" in name or "slot" in name:
                draw.rectangle((2, 2, size[0] - 3, size[1] - 3), fill=rgba(INK, 205), outline=rgba(color), width=2)
                draw.rectangle((6, 6, size[0] - 7, size[1] - 7), outline=rgba(GOLD, 150))
            elif "arrow" in name or "pointer" in name:
                draw.polygon([(8, 12), (size[0] - 8, 12), (size[0] // 2, size[1] - 10)], fill=rgba(color))
            elif "radio" in name:
                draw.ellipse((5, 5, size[0] - 6, size[1] - 6), outline=rgba(GOLD), width=2)
                if name.endswith("on"):
                    draw.ellipse((14, 14, size[0] - 15, size[1] - 15), fill=rgba(JADE_BRIGHT))
            elif "checkbox" in name:
                draw.rectangle((5, 5, size[0] - 6, size[1] - 6), outline=rgba(GOLD), width=2)
                if name.endswith("on"):
                    draw.line((11, 24, 20, 33, 37, 13), fill=rgba(JADE_BRIGHT), width=4)
            elif "divider" in name or "track" in name or "fill" in name or "thumb" in name:
                draw.rectangle((1, 1, size[0] - 2, size[1] - 2), fill=rgba(color, 220), outline=rgba(GOLD, 150))
            else:
                draw.ellipse((6, 6, size[0] - 7, size[1] - 7), fill=rgba(INK, 220), outline=rgba(color), width=2)
                draw.polygon([(24, 10), (29, 20), (39, 24), (29, 28), (24, 38), (19, 28), (9, 24), (19, 20)], fill=rgba(color))
            save_asset(image, f"ui/{folder}/{name}.png", "global_ui")


ICON_GROUPS = {
    "resources": ["spirit_stone", "food", "wood", "stone", "spirit_grass", "spirit_ore", "population", "reputation", "combat_power", "influence", "action_point", "money", "time"],
    "navigation": ["sect", "disciple", "building", "world", "diplomacy", "inventory", "mission", "market", "history", "battle_report", "save_load", "settings", "tutorial"],
    "map_tools": ["zoom_in", "zoom_out", "locate_player", "full_map", "territory", "layer", "marker", "filter", "close", "back"],
    "systems": ["save", "load", "settings", "audio", "music", "effects", "confirm", "cancel", "warning", "success", "error", "lock", "unlock", "search", "sort", "refresh", "pause", "play", "next_day"],
    "status": ["healthy", "injured", "tired", "cultivating", "working", "idle", "assigned", "unassigned", "building", "completed", "hostile", "allied", "neutral"],
}


def icon_master(name: str) -> Image.Image:
    rng = random.Random(stable_seed(name))
    image = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    color = (JADE_BRIGHT, GOLD_BRIGHT, RICE, "#8fb6ce", "#cf7060")[rng.randrange(5)]
    draw.rectangle((4, 4, 43, 43), fill=rgba(INK, 218), outline=rgba(GOLD), width=2)
    mode = stable_seed(name) % 6
    if name in ("zoom_in", "zoom_out", "search"):
        draw.ellipse((10, 9, 31, 30), outline=rgba(color), width=4)
        draw.line((29, 29, 39, 39), fill=rgba(color), width=4)
        draw.line((15, 20, 27, 20), fill=rgba(RICE), width=3)
        if name == "zoom_in":
            draw.line((21, 14, 21, 26), fill=rgba(RICE), width=3)
    elif name in ("confirm", "success", "completed", "healthy"):
        draw.line((10, 25, 20, 35, 38, 12), fill=rgba(JADE_BRIGHT), width=5)
    elif name in ("cancel", "close", "error"):
        draw.line((12, 12, 36, 36), fill=rgba(RED), width=4)
        draw.line((36, 12, 12, 36), fill=rgba(RED), width=4)
    elif name in ("back",):
        draw.polygon([(9, 24), (26, 10), (26, 19), (39, 19), (39, 29), (26, 29), (26, 38)], fill=rgba(color))
    elif name in ("play", "next_day"):
        draw.polygon([(14, 10), (39, 24), (14, 38)], fill=rgba(color))
    elif name == "pause":
        draw.rectangle((13, 10, 20, 38), fill=rgba(color))
        draw.rectangle((28, 10, 35, 38), fill=rgba(color))
    elif mode == 0:
        draw.ellipse((10, 10, 37, 37), fill=rgba(color), outline=rgba(RICE), width=2)
    elif mode == 1:
        draw.polygon([(24, 7), (40, 24), (24, 41), (8, 24)], fill=rgba(color), outline=rgba(RICE))
    elif mode == 2:
        draw.rectangle((11, 12, 36, 37), fill=rgba(color), outline=rgba(RICE), width=2)
        draw.polygon([(8, 15), (24, 5), (39, 15)], fill=rgba(GOLD_BRIGHT))
    elif mode == 3:
        draw.arc((8, 8, 39, 39), 20, 320, fill=rgba(color), width=5)
        draw.ellipse((20, 20, 28, 28), fill=rgba(RICE))
    elif mode == 4:
        draw.polygon([(24, 6), (29, 19), (42, 24), (29, 29), (24, 42), (19, 29), (6, 24), (19, 19)], fill=rgba(color))
    else:
        for i in range(3):
            draw.line((10, 14 + i * 10, 38, 14 + i * 10), fill=rgba(color), width=4)
    return image


def generate_icons() -> None:
    for group, names in ICON_GROUPS.items():
        for name in names:
            master = icon_master(f"{group}:{name}")
            for size in (24, 32, 48):
                image = master.resize((size, size), Image.Resampling.NEAREST)
                save_asset(image, f"icons/{group}/{name}_{size}.png", f"icons_{group}")

    item_icons = ["spirit_stone", "spirit_grass", "spirit_ore", "pill", "weapon", "armor", "manual", "material", "mission_item", "secret_realm_item", "common_item", "rare_item"]
    for name in item_icons:
        save_asset(icon_master(f"item:{name}"), f"icons/resources/item_{name}.png", "item_icons")


def draw_mountain_background(kind: str) -> Image.Image:
    rng = random.Random(stable_seed(kind))
    small = Image.new("RGBA", (480, 270), rgba("#102b32"))
    draw = ImageDraw.Draw(small)
    # Sky wash and distant cloud bands.
    for y in range(0, 150):
        t = y / 150.0
        color = tuple(int(a + (b - a) * t) for a, b in zip(rgba("#193c48"), rgba("#769b92")))
        draw.line((0, y, 479, y), fill=color)
    for layer, base_y in enumerate((118, 150, 188)):
        pts = [(0, 270)]
        x = -40
        while x < 520:
            peak_x = x + rng.randint(28, 55)
            peak_y = base_y - rng.randint(24, 65) + layer * 8
            pts.extend([(x, base_y + rng.randint(-4, 6)), (peak_x, peak_y)])
            x += rng.randint(55, 95)
        pts.extend([(520, 270)])
        shade = ("#35575a", "#284749", "#173638")[layer]
        draw.polygon(pts, fill=rgba(shade))
    for i in range(16):
        cx = rng.randint(-20, 500)
        cy = rng.randint(112, 225)
        w = rng.randint(30, 85)
        draw.ellipse((cx, cy, cx + w, cy + rng.randint(8, 18)), fill=rgba("#c9d7ca", 65 + i % 3 * 20))
    # restrained sect silhouettes, kept away from the central menu column.
    for x in (45, 390):
        draw.rectangle((x, 158, x + 34, 205), fill=rgba(INK_DARK, 220))
        draw.polygon([(x - 10, 165), (x + 17, 145), (x + 44, 165)], fill=rgba(WOOD, 235))
        draw.rectangle((x + 13, 139, x + 20, 158), fill=rgba(GOLD, 220))
    return small.resize((1920, 1080), Image.Resampling.NEAREST)


def generate_scene_art() -> None:
    save_asset(draw_mountain_background("main_menu"), "scenes/main_menu/main_menu_background.png", "main_menu", transparent=False)
    save_asset(draw_mountain_background("qingxuan_sect"), "sects/backgrounds/qingxuan_sect_background.png", "sect_scene", transparent=False)
    save_asset(draw_mountain_background("battle"), "scenes/battle/battle_background.png", "battle", transparent=False)
    for folder, name in [
        ("building", "building_screen_background"), ("diplomacy", "diplomacy_background"),
        ("inventory", "inventory_background"), ("market", "market_background"),
        ("mission", "mission_background"), ("save_load", "save_load_background"),
    ]:
        image = draw_mountain_background(f"scene:{folder}").resize((1280, 720), Image.Resampling.NEAREST)
        save_asset(image, f"scenes/{folder}/{name}.png", f"scene_{folder}", transparent=False)

    scene_panels = {
        "main_menu": ["title_frame", "main_menu_center_panel", "version_decoration", "settings_dialog_background", "corrupt_save_dialog_background", "fade_overlay"],
        "building": ["building_category_tabs", "building_card", "building_locked_card", "building_selected_card", "construction_queue_panel", "construction_progress", "cost_strip", "build_button", "upgrade_button", "demolish_button", "worker_assignment_slot", "empty_build_slot", "building_preview_frame"],
        "diplomacy": ["sect_list_panel", "sect_diplomacy_card", "relation_badge", "relation_meter", "diplomacy_action_button", "treaty_panel", "message_scroll", "sect_banner_frame", "hostile_overlay", "allied_overlay", "neutral_overlay"],
        "inventory": ["item_slot", "item_slot_selected", "item_slot_locked", "inventory_panel", "tooltip_item"],
        "market": ["market_card", "price_tag", "buy_button", "sell_button"],
        "mission": ["mission_card", "mission_active", "mission_complete", "mission_locked", "reward_strip", "requirement_strip"],
        "save_load": ["save_slot", "save_slot_empty", "save_slot_corrupt", "autosave_badge", "delete_confirm_dialog", "load_confirm_dialog", "settings_dialog", "audio_slider", "toggle", "dropdown", "tab", "close_button", "tutorial_overlay", "tutorial_highlight", "tutorial_arrow", "tutorial_message_panel", "tutorial_step_badge", "event_dialog", "event_option_button", "event_result_panel", "warning_dialog", "success_dialog", "error_dialog", "toast"],
        "battle": ["battle_unit_card", "health_bar", "mana_bar", "action_bar", "skill_button", "turn_indicator", "victory_panel", "defeat_panel", "battle_report_frame"],
    }
    for folder, names in scene_panels.items():
        for name in names:
            size = (192, 96)
            if "overlay" in name or "highlight" in name:
                size = (256, 144)
            image = pixel_frame(size, rgba(INK, 215), GOLD, JADE)
            save_asset(image, f"scenes/{folder}/{name}.png", f"scene_{folder}", nine_patch=True)


def terrain_tile(name: str, variant: int) -> Image.Image:
    palettes = {
        "grass_light": ("#71956a", "#8aaa78"), "grass_medium": ("#557e57", "#6e9866"), "grass_dark": ("#365f47", "#4b7654"),
        "forest_floor": ("#3f6041", "#2f4d35"), "deep_forest": ("#274638", "#1b352e"),
        "shallow_water": ("#5592a3", "#7eb4b9"), "deep_water": ("#28566f", "#376f87"), "river": ("#3f7890", "#72a8ae"), "lake": ("#386c82", "#5c91a0"),
        "coast_sand": ("#ad9c70", "#c3b180"), "coast_rock": ("#726f65", "#8b887d"), "desert_sand": ("#a98a59", "#c1a06b"), "desert_rock": ("#765c47", "#8b6c50"),
        "snow": ("#d5ded8", "#eef0e6"), "ice": ("#a8c7cb", "#d0e4e1"), "mountain": ("#696a62", "#85847a"), "cliff": ("#58544c", "#777066"),
        "dirt": ("#745b40", "#8b6d4c"), "mud": ("#554c3d", "#6f604a"), "road": ("#8d7756", "#a58c64"), "stone_road": ("#77776d", "#969486"),
        "sect_ground": ("#415f5a", "#647f72"), "spirit_ground": ("#41645f", "#6da998"),
    }
    base, accent = palettes[name]
    image = Image.new("RGBA", (16, 16), rgba(base))
    draw = ImageDraw.Draw(image)
    rng = random.Random(stable_seed(f"tile:{name}:{variant}"))
    if name in ("shallow_water", "deep_water", "river", "lake"):
        for y in (4 + variant % 2, 11 - variant % 2):
            for x in range(1, 15, 4):
                draw.line((x, y, min(15, x + 2), y), fill=rgba(accent))
    elif name in ("road", "stone_road"):
        for x in range(0, 16, 5):
            draw.line((x, 0, x - 3, 15), fill=rgba(accent, 170))
    else:
        for _ in range(8):
            x, y = rng.randrange(16), rng.randrange(16)
            draw.point((x, y), fill=rgba(accent, 210))
    return image


def generate_world() -> None:
    terrain_names = ["grass_light", "grass_medium", "grass_dark", "forest_floor", "deep_forest", "shallow_water", "deep_water", "river", "lake", "coast_sand", "coast_rock", "desert_sand", "desert_rock", "snow", "ice", "mountain", "cliff", "dirt", "mud", "road", "stone_road", "sect_ground", "spirit_ground"]
    for name in terrain_names:
        for variant in range(1, 4):
            save_asset(terrain_tile(name, variant), f"world/terrain/{name}_{variant:02d}.png", "world_terrain", transparent=False)

    transitions = ["grass_to_water", "grass_to_sand", "grass_to_forest", "grass_to_snow", "grass_to_desert", "water_to_coast", "river_bank", "cliff_edge", "mountain_foot", "snow_edge", "desert_edge"]
    for name in transitions:
        for variant in range(1, 4):
            image = terrain_tile("grass_medium", variant)
            draw = ImageDraw.Draw(image)
            for y in range(16):
                edge = 7 + int(math.sin((y + variant) * 0.8) * 2)
                draw.rectangle((edge, y, 15, y), fill=rgba(("#477d83", "#a58b60", "#596f54")[stable_seed(name) % 3]))
            save_asset(image, f"world/transitions/{name}_{variant:02d}.png", "world_transitions", transparent=False)

    nature_names = ["tree_small", "tree_medium", "tree_large", "pine_tree", "dead_tree", "bamboo", "bush", "grass_cluster", "flower_cluster", "rock_small", "rock_large", "crystal_cluster", "snow_rock", "desert_cactus", "desert_shrub", "waterfall", "cloud", "mist", "spirit_mist"]
    for name in nature_names:
        for variant in range(1, 4):
            image = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
            draw = ImageDraw.Draw(image)
            rng = random.Random(stable_seed(f"nature:{name}:{variant}"))
            if "rock" in name or "crystal" in name:
                color = "#7b7b70" if "snow" not in name else "#c5d3d0"
                draw.polygon([(8, 52), (14, 25), (26, 14), (40, 33), (42, 54)], fill=rgba(color), outline=rgba(INK_DARK))
                if "crystal" in name:
                    draw.polygon([(20, 48), (24, 10), (31, 47)], fill=rgba(JADE_BRIGHT, 220))
            elif name in ("cloud", "mist", "spirit_mist"):
                alpha = 100 if name == "mist" else 155
                for i in range(6):
                    x, y = rng.randint(0, 34), rng.randint(17, 40)
                    draw.ellipse((x, y, x + rng.randint(12, 24), y + 12), fill=rgba(JADE_BRIGHT if "spirit" in name else RICE, alpha))
            elif name == "waterfall":
                draw.polygon([(12, 4), (36, 4), (32, 60), (16, 60)], fill=rgba("#78b8c0", 210))
                draw.line((20, 6, 18, 56), fill=rgba(RICE, 210), width=3)
            elif name in ("bush", "grass_cluster", "flower_cluster", "desert_shrub"):
                for i in range(8):
                    x = 6 + i * 5
                    draw.line((24, 57, x, 28 + rng.randint(0, 16)), fill=rgba("#567b4f"), width=2)
                    if "flower" in name:
                        draw.ellipse((x - 2, 26, x + 2, 30), fill=rgba(("#d59a9b", "#d7c67a", "#a8a0ca")[i % 3]))
            else:
                trunk = "#55402f"
                draw.rectangle((21, 33, 27, 61), fill=rgba(trunk))
                foliage = "#456f4f"
                if "dead" in name:
                    foliage = "#706354"
                    draw.line((24, 37, 10, 20), fill=rgba(foliage), width=4)
                    draw.line((24, 39, 39, 17), fill=rgba(foliage), width=4)
                elif "bamboo" in name:
                    for x in (14, 23, 32):
                        draw.line((x, 58, x + variant - 2, 10), fill=rgba("#5f8959"), width=3)
                else:
                    for i in range(8):
                        x, y = rng.randint(5, 34), rng.randint(8, 35)
                        draw.ellipse((x, y, x + 14, y + 14), fill=rgba(foliage), outline=rgba("#2c513e"))
            save_asset(image, f"world/nature/{name}_{variant:02d}.png", "world_nature")

    landmarks = ["village", "town", "pagoda", "shrine", "bridge", "mountain_gate", "watchtower", "ruined_temple", "cave", "secret_realm_gate", "resource_mine", "herb_field", "spirit_vein", "dock", "ship", "road_marker"]
    for name in landmarks:
        image = draw_building(name, SECT_PALETTES["qingxuan"], (96, 96))
        save_asset(image, f"world/landmarks/{name}.png", "world_landmarks")

    for sect, palette in SECT_PALETTES.items():
        image = draw_building(f"{sect}_headquarters", palette, (128, 128))
        save_asset(image, f"world/landmarks/{sect}_headquarters.png", "sect_headquarters")
        emblem = draw_emblem(sect, palette)
        save_asset(emblem, f"sects/emblems/{sect}_emblem.png", "sect_emblems")
        banner = Image.new("RGBA", (64, 128), (0, 0, 0, 0))
        banner.paste(emblem.resize((48, 48), Image.Resampling.NEAREST), (8, 24), emblem.resize((48, 48), Image.Resampling.NEAREST))
        ImageDraw.Draw(banner).polygon([(7, 8), (57, 8), (57, 104), (32, 122), (7, 104)], fill=rgba(palette[0]), outline=rgba(palette[2]), width=3)
        banner.paste(emblem.resize((40, 40), Image.Resampling.NEAREST), (12, 30), emblem.resize((40, 40), Image.Resampling.NEAREST))
        save_asset(banner, f"sects/banners/{sect}_banner.png", "sect_banners")


def draw_emblem(name: str, palette: tuple[str, str, str, str]) -> Image.Image:
    image = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((10, 10, 117, 117), fill=rgba(palette[0], 238), outline=rgba(palette[2]), width=5)
    draw.ellipse((20, 20, 107, 107), outline=rgba(palette[1]), width=3)
    points = [(64, 24), (76, 50), (104, 64), (76, 78), (64, 104), (52, 78), (24, 64), (52, 50)]
    draw.polygon(points, fill=rgba(palette[1]), outline=rgba(palette[3]))
    if name == "jinlian":
        for i in range(8):
            angle = i * math.pi / 4
            x, y = 64 + int(math.cos(angle) * 22), 64 + int(math.sin(angle) * 22)
            draw.ellipse((x - 8, y - 12, x + 8, y + 12), fill=rgba(palette[2], 210))
    return image


def draw_building(name: str, palette: tuple[str, str, str, str], size: tuple[int, int]) -> Image.Image:
    w, h = size
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    rng = random.Random(stable_seed(f"building:{name}"))
    ground = h - 10
    levels = 2 + stable_seed(name) % 3
    width = int(w * (0.55 + rng.random() * 0.18))
    left = (w - width) // 2
    level_h = max(10, (h - 30) // levels)
    for level in range(levels):
        y2 = ground - level * level_h
        y1 = y2 - level_h + 2
        inset = level * max(2, w // 32)
        draw.rectangle((left + inset, y1, left + width - inset, y2), fill=rgba(palette[0]), outline=rgba(palette[2]), width=2)
        roof_y = y1 - 7
        draw.polygon([(left + inset - 8, y1), (w // 2, roof_y), (left + width - inset + 8, y1)], fill=rgba(palette[1]), outline=rgba(INK_DARK))
    draw.rectangle((w // 2 - 5, ground - level_h + 4, w // 2 + 5, ground), fill=rgba(WOOD))
    draw.line((left - 8, ground + 2, left + width + 8, ground + 2), fill=rgba(palette[2]), width=3)
    return image


BUILDINGS = ["main_hall", "disciple_quarters", "alchemy_hall", "scripture_pavilion", "training_ground", "warehouse", "spirit_field", "crafting_hall", "mission_hall", "diplomacy_hall", "market_stall", "healing_hall", "formation_platform", "sect_gate", "watchtower", "empty_build_slot"]


def generate_buildings() -> None:
    palette = SECT_PALETTES["qingxuan"]
    for name in BUILDINGS:
        sprite = draw_building(name, palette, (128, 128))
        icon = sprite.resize((48, 48), Image.Resampling.NEAREST)
        card = pixel_frame((256, 192), rgba(INK, 225), GOLD, JADE)
        card.alpha_composite(sprite.resize((160, 160), Image.Resampling.NEAREST), (48, 16))
        silhouette = sprite.copy()
        alpha = silhouette.getchannel("A")
        silhouette = Image.new("RGBA", sprite.size, rgba(INK_DARK, 230))
        silhouette.putalpha(alpha)
        outline = pixel_frame((144, 144), (0, 0, 0, 0), JADE_BRIGHT, GOLD)
        outline.alpha_composite(sprite, (8, 8))
        save_asset(sprite, f"sects/buildings/{name}_map.png", "buildings")
        save_asset(icon, f"icons/buildings/{name}_icon.png", "building_icons")
        save_asset(card, f"sects/buildings/{name}_card.png", "building_cards")
        save_asset(silhouette, f"sects/buildings/{name}_locked.png", "building_locked")
        save_asset(outline, f"sects/buildings/{name}_selected.png", "building_selected")


def draw_portrait(identifier: str, palette: tuple[str, str, str, str], role: str) -> Image.Image:
    rng = random.Random(stable_seed(f"portrait:{identifier}"))
    small = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(small)
    # quiet jade backdrop, transparent corners
    draw.rectangle((5, 5, 58, 63), fill=rgba(palette[0], 235), outline=rgba(palette[2]))
    hair = ("#211d1a", "#3a3028", "#54504a")[rng.randrange(3)]
    skin = ("#d9af8e", "#c99676", "#e2bd99")[rng.randrange(3)]
    robe = palette[1]
    draw.ellipse((20, 10, 44, 36), fill=rgba(skin), outline=rgba(INK_DARK))
    draw.pieslice((18, 6, 46, 30), 180, 360, fill=rgba(hair))
    if "elder" in role or "master" in role:
        draw.line((27, 33, 31, 47), fill=rgba("#d7d3c5"), width=2)
        draw.line((37, 33, 33, 47), fill=rgba("#d7d3c5"), width=2)
    draw.polygon([(15, 63), (20, 38), (32, 32), (44, 38), (50, 63)], fill=rgba(robe), outline=rgba(palette[2]))
    draw.line((32, 36, 32, 62), fill=rgba(palette[3]), width=2)
    draw.point((27, 23), fill=rgba(INK_DARK))
    draw.point((37, 23), fill=rgba(INK_DARK))
    return small.resize((256, 256), Image.Resampling.NEAREST)


def sprite_sheet(identifier: str, palette: tuple[str, str, str, str]) -> Image.Image:
    fw, fh = 32, 48
    columns, rows = 18, 4
    sheet = Image.new("RGBA", (fw * columns, fh * rows), (0, 0, 0, 0))
    for direction in range(rows):
        for frame in range(columns):
            tile = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
            draw = ImageDraw.Draw(tile)
            bob = (frame % 4 == 1) - (frame % 4 == 3)
            skin = "#d6a989"
            robe = palette[1]
            draw.ellipse((11, 5 + bob, 21, 15 + bob), fill=rgba(skin), outline=rgba(INK_DARK))
            draw.rectangle((10, 14 + bob, 22, 34 + bob), fill=rgba(robe), outline=rgba(palette[2]))
            if direction == 1:
                draw.rectangle((8, 17 + bob, 11, 29 + bob), fill=rgba(palette[3]))
            elif direction == 2:
                draw.rectangle((21, 17 + bob, 24, 29 + bob), fill=rgba(palette[3]))
            elif direction == 3:
                draw.rectangle((13, 7 + bob, 19, 10 + bob), fill=rgba("#24201d"))
            if frame >= 16:  # injured two-frame pose
                tile = tile.rotate(90, expand=False, resample=Image.Resampling.NEAREST)
            else:
                step = -1 if frame % 2 == 0 else 1
                draw.rectangle((11 + step, 34 + bob, 15 + step, 43 + bob), fill=rgba(INK_DARK))
                draw.rectangle((18 - step, 34 + bob, 22 - step, 43 + bob), fill=rgba(INK_DARK))
            sheet.alpha_composite(tile, (frame * fw, direction * fh))
    return sheet


def generate_characters() -> None:
    roster: list[tuple[str, str, str]] = []
    for sect in SECT_PALETTES:
        roster.append((sect, f"{sect}_master", "master"))
        for i in range(1, 3):
            roster.append((sect, f"{sect}_elder_{i:02d}", "elder"))
        for i in range(1, 5):
            roster.append((sect, f"{sect}_disciple_{i:02d}", "disciple"))
    # Additional Qingxuan prototypes and common NPCs.
    for group, count in (("male_disciple", 6), ("female_disciple", 6), ("outer_disciple", 4), ("inner_disciple", 4), ("steward", 2)):
        for i in range(1, count + 1):
            roster.append(("qingxuan", f"qingxuan_{group}_{i:02d}", group))
    for npc in ("merchant", "alchemist", "blacksmith", "physician", "mission_giver", "wandering_cultivator", "rogue_cultivator", "guard"):
        roster.append(("qingxuan", f"npc_{npc}", "npc"))

    seen: set[str] = set()
    for sect, identifier, role in roster:
        if identifier in seen:
            continue
        seen.add(identifier)
        palette = SECT_PALETTES[sect]
        portrait = draw_portrait(identifier, palette, role)
        save_asset(portrait, f"characters/portraits/{identifier}_portrait_256.png", "character_portraits")
        save_asset(portrait.resize((64, 64), Image.Resampling.NEAREST), f"characters/portraits/{identifier}_portrait_64.png", "character_portraits_small")
        sheet = sprite_sheet(identifier, palette)
        save_asset(sheet, f"characters/sprite_sheets/{identifier}_sheet.png", "character_sprite_sheets", sprite_sheet=True, frame_size=(32, 48))
        first = sheet.crop((0, 0, 32, 48))
        save_asset(first, f"characters/map_sprites/{identifier}_map.png", "character_map_sprites")


def generate_effects() -> None:
    names = ["sword_slash", "spirit_bolt", "fire_burst", "healing_light", "poison_cloud", "shield", "cultivation_aura", "level_up", "resource_sparkle", "selection_ring", "quest_marker", "diplomacy_relation_change"]
    for name in names:
        fw, fh, frames = 64, 64, 8
        sheet = Image.new("RGBA", (fw * frames, fh), (0, 0, 0, 0))
        color = (JADE_BRIGHT, GOLD_BRIGHT, "#d86d55", "#8ab0d4", "#9a7ac1")[stable_seed(name) % 5]
        for frame in range(frames):
            tile = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
            draw = ImageDraw.Draw(tile)
            radius = 6 + frame * 3
            alpha = 255 - frame * 24
            if "slash" in name:
                draw.arc((7, 7, 57, 57), 210 - frame * 5, 330 + frame * 5, fill=rgba(color, alpha), width=max(2, 7 - frame // 2))
            elif "bolt" in name:
                draw.polygon([(8 + frame * 4, 32), (32, 22), (56, 32), (32, 42)], fill=rgba(color, alpha))
            elif "cloud" in name or "burst" in name:
                for i in range(5):
                    x = 32 + int(math.cos(i * 1.25) * radius)
                    y = 32 + int(math.sin(i * 1.25) * radius)
                    draw.ellipse((x - 8, y - 8, x + 8, y + 8), fill=rgba(color, alpha))
            else:
                draw.ellipse((32 - radius, 32 - radius, 32 + radius, 32 + radius), outline=rgba(color, alpha), width=4)
                draw.polygon([(32, 7 + frame), (38, 27), (58 - frame, 32), (38, 37), (32, 57 - frame), (26, 37), (7 + frame, 32), (26, 27)], fill=rgba(color, max(30, alpha // 2)))
            sheet.alpha_composite(tile, (frame * fw, 0))
        save_asset(sheet, f"world/effects/{name}_sheet.png", "effects", sprite_sheet=True, frame_size=(64, 64))


def generate_contact_sheet(filename: str, category_prefixes: Iterable[str], max_items: int = 96) -> None:
    records = [r for r in manifest if any(r["category"].startswith(prefix) for prefix in category_prefixes)][:max_items]
    cell_w, cell_h, columns = 128, 128, 8
    rows = max(1, math.ceil(len(records) / columns))
    sheet = Image.new("RGBA", (cell_w * columns, cell_h * rows), rgba("#182526"))
    draw = ImageDraw.Draw(sheet)
    for y in range(0, sheet.height, 16):
        for x in range(0, sheet.width, 16):
            draw.rectangle((x, y, x + 15, y + 15), fill=rgba("#233435" if (x // 16 + y // 16) % 2 else "#304344"))
    for index, record in enumerate(records):
        source = ROOT / record["path"].replace("res://", "")
        image = Image.open(source).convert("RGBA")
        image.thumbnail((104, 104), Image.Resampling.NEAREST)
        x = (index % columns) * cell_w + (cell_w - image.width) // 2
        y = (index // columns) * cell_h + (cell_h - image.height) // 2
        sheet.alpha_composite(image, (x, y))
        draw.rectangle((index % columns * cell_w + 1, index // columns * cell_h + 1, (index % columns + 1) * cell_w - 2, (index // columns + 1) * cell_h - 2), outline=rgba(GOLD, 160))
    CONTACTS.mkdir(parents=True, exist_ok=True)
    sheet.save(CONTACTS / filename, format="PNG", optimize=True)


def write_manifest_and_contacts() -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "task": "Task-0068.0",
        "project": "WanZong",
        "stage": "0.5.0 Pre-Alpha",
        "generator": "tools/art/generate_placeholder_art.py",
        "seed": SEED,
        "placeholder": True,
        "asset_count": len(manifest),
        "assets": sorted(manifest, key=lambda item: item["path"]),
    }
    MANIFEST_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    sheets = {
        "ui_panels.png": ["global_ui"], "ui_buttons.png": ["global_ui"],
        "icons_resources.png": ["icons_resources", "item_icons"], "icons_navigation.png": ["icons_navigation", "icons_map_tools"],
        "icons_systems.png": ["icons_systems", "icons_status"], "character_portraits.png": ["character_portraits"],
        "character_sprites.png": ["character_map_sprites"], "sect_buildings.png": ["sect_headquarters"],
        "general_buildings.png": ["buildings"], "world_tiles.png": ["world_terrain", "world_transitions"],
        "world_nature.png": ["world_nature"], "world_landmarks.png": ["world_landmarks"], "effects.png": ["effects"],
    }
    for filename, prefixes in sheets.items():
        generate_contact_sheet(filename, prefixes)


def clean_task_outputs() -> None:
    for path in (OUT, CONTACTS):
        if path.exists():
            shutil.rmtree(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if args.verify_only:
        payload = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        for record in payload["assets"]:
            path = ROOT / record["path"].replace("res://", "")
            with Image.open(path) as image:
                if image.size != (record["width"], record["height"]):
                    raise RuntimeError(f"size mismatch: {path}")
                if record["transparent"] and image.convert("RGBA").getchannel("A").getextrema()[0] == 255:
                    raise RuntimeError(f"alpha mismatch: {path}")
        print(f"[Task0068ArtGenerator] VERIFIED {len(payload['assets'])} assets")
        return 0
    clean_task_outputs()
    generate_ui()
    generate_icons()
    generate_scene_art()
    generate_world()
    generate_buildings()
    generate_characters()
    generate_effects()
    write_manifest_and_contacts()
    print(f"[Task0068ArtGenerator] GENERATED {len(manifest)} assets seed={SEED}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
