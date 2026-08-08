#!/usr/bin/env python3
"""Pack AI-generated chroma-key art into deterministic Godot-ready pixel atlases."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "generated"
NEAREST = getattr(getattr(Image, "Resampling", Image), "NEAREST")
FASTOCTREE = getattr(getattr(Image, "Quantize", Image), "FASTOCTREE")
NO_DITHER = getattr(getattr(Image, "Dither", Image), "NONE")


def alpha_bbox(image: Image.Image, threshold: int = 16):
    alpha = image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    return alpha.getbbox()


def harden_alpha(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    image.putalpha(alpha)
    return image


def quantize_rgba(image: Image.Image, colors: int) -> Image.Image:
    image = harden_alpha(image)
    alpha = image.getchannel("A")
    rgb = image.convert("RGB").quantize(
        colors=colors,
        method=FASTOCTREE,
        dither=NO_DITHER,
    ).convert("RGB")
    rgb.putalpha(alpha)
    return rgb


def projection_segments(
    image: Image.Image,
    y0: int,
    y1: int,
    merge_gap: int = 25,
) -> list[tuple[int, int]]:
    alpha = image.getchannel("A")
    raw: list[tuple[int, int]] = []
    active = False
    start = 0
    for x in range(image.width):
        occupied = alpha.crop((x, y0, x + 1, y1)).getbbox() is not None
        if occupied and not active:
            start = x
            active = True
        if active and (not occupied or x == image.width - 1):
            raw.append((start, x if not occupied else x + 1))
            active = False
    merged: list[tuple[int, int]] = []
    for segment in raw:
        if merged and segment[0] - merged[-1][1] < merge_gap:
            merged[-1] = (merged[-1][0], segment[1])
        else:
            merged.append(segment)
    return merged


def crop_strip_frames(
    image: Image.Image,
    y0: int,
    y1: int,
    merge_gap: int = 25,
) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for x0, x1 in projection_segments(image, y0, y1, merge_gap):
        candidate = image.crop((x0, y0, x1, y1))
        bbox = alpha_bbox(candidate)
        if bbox:
            frames.append(candidate.crop(bbox))
    return frames


def resize_by_scale(image: Image.Image, scale: float, max_width: int = 30) -> Image.Image:
    width = max(1, round(image.width * scale))
    height = max(1, round(image.height * scale))
    if width > max_width:
        ratio = max_width / width
        width = max_width
        height = max(1, round(height * ratio))
    return image.resize((width, height), NEAREST)


def resize_to_height(image: Image.Image, height: int, max_width: int = 30) -> Image.Image:
    scale = height / image.height
    return resize_by_scale(image, scale, max_width)


def pack_character_sheet() -> None:
    source = Image.open(ASSETS / "forest_mechanic_spritesheet-hires.png").convert("RGBA")
    supplement = Image.open(ASSETS / "forest_mechanic_supplement-hires.png").convert("RGBA")

    row_height = source.height // 6
    base_rows = [
        crop_strip_frames(source, row * row_height, (row + 1) * row_height)
        for row in range(6)
    ]
    detected = [len(row) for row in base_rows]
    if detected != [3, 7, 3, 2, 4, 2]:
        raise RuntimeError(f"Unexpected source frame layout: {detected}")

    left = supplement.crop((0, 0, supplement.width // 2, supplement.height))
    right = supplement.crop((supplement.width // 2, 0, supplement.width, supplement.height))
    left_bbox = alpha_bbox(left)
    right_bbox = alpha_bbox(right)
    if not left_bbox or not right_bbox:
        raise RuntimeError("Could not find both supplemental frames")
    idle_extra = left.crop(left_bbox)
    run_extra = right.crop(right_bbox)

    # The original six strips share a common source pixel density. Use one scale
    # for them so tucked/extended poses retain their intended relative sizes.
    standing_height = max(frame.height for frame in base_rows[0])
    base_scale = 26.0 / standing_height
    packed_rows: list[list[Image.Image]] = [
        [resize_by_scale(frame, base_scale) for frame in row]
        for row in base_rows
    ]
    packed_rows[0].append(resize_to_height(idle_extra, 26))
    packed_rows[1].append(resize_to_height(run_extra, 26))

    expected = [4, 8, 3, 2, 4, 2]
    if [len(row) for row in packed_rows] != expected:
        raise RuntimeError("Final animation frame counts are invalid")

    sheet = Image.new("RGBA", (8 * 32, 6 * 32), (0, 0, 0, 0))
    airborne_bottoms = {2: [30, 27, 25], 3: [26, 29]}
    for row_index, frames in enumerate(packed_rows):
        for column_index, frame in enumerate(frames):
            bottom = airborne_bottoms.get(row_index, [30] * len(frames))[column_index]
            x = column_index * 32 + (32 - frame.width) // 2
            y = row_index * 32 + bottom - frame.height
            sheet.alpha_composite(frame, (x, y))

    sheet = quantize_rgba(sheet, 32)
    sheet.save(ASSETS / "forest_mechanic_spritesheet_32px.png", optimize=True)

    animations = {
        "image": "forest_mechanic_spritesheet_32px.png",
        "frame_size": [32, 32],
        "sheet_size": [256, 192],
        "columns": 8,
        "rows": 6,
        "animations": {
            "idle": {"row": 0, "frames": 4, "fps": 6, "loop": True},
            "run": {"row": 1, "frames": 8, "fps": 12, "loop": True},
            "jump": {"row": 2, "frames": 3, "fps": 9, "loop": False},
            "fall": {"row": 3, "frames": 2, "fps": 6, "loop": True},
            "attack": {"row": 4, "frames": 4, "fps": 12, "loop": False},
            "hurt": {"row": 5, "frames": 2, "fps": 8, "loop": False},
        },
    }
    (ASSETS / "forest_mechanic_spritesheet_32px.json").write_text(
        json.dumps(animations, indent=2), encoding="utf-8"
    )


def fit_into(image: Image.Image, width: int, height: int) -> Image.Image:
    bbox = alpha_bbox(image)
    if not bbox:
        return Image.new("RGBA", (width, height), (0, 0, 0, 0))
    image = image.crop(bbox)
    scale = min(width / image.width, height / image.height)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    resized = image.resize(size, NEAREST)
    result = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    result.alpha_composite(resized, ((width - size[0]) // 2, height - size[1]))
    return result


def paste_region(
    atlas: Image.Image,
    source: Image.Image,
    source_box: tuple[int, int, int, int],
    tile_box: tuple[int, int, int, int],
) -> None:
    tx, ty, tw, th = tile_box
    fitted = fit_into(source.crop(source_box), tw * 16, th * 16)
    atlas.alpha_composite(fitted, (tx * 16, ty * 16))


def pack_forest_tileset() -> None:
    source = Image.open(ASSETS / "forest_tileset-hires.png").convert("RGBA")
    atlas = Image.new("RGBA", (16 * 16, 18 * 16), (0, 0, 0, 0))

    top_bands = [(0, 130), (130, 235), (235, 340), (340, 450)]
    for row, (y0, y1) in enumerate(top_bands):
        segments = projection_segments(source, y0, y1, merge_gap=10)
        for column, (x0, x1) in enumerate(segments[:16]):
            tile = fit_into(source.crop((x0, y0, x1, y1)), 16, 16)
            atlas.alpha_composite(tile, (column * 16, row * 16))

    # Multi-tile modules keep their original proportions inside strict tile regions.
    paste_region(atlas, source, (31, 450, 198, 790), (0, 4, 3, 6))
    paste_region(atlas, source, (198, 450, 480, 790), (3, 4, 4, 6))
    paste_region(atlas, source, (500, 450, 910, 790), (7, 4, 6, 6))
    paste_region(atlas, source, (915, 350, 1170, 790), (13, 4, 3, 6))

    paste_region(atlas, source, (30, 790, 590, 905), (0, 10, 8, 2))
    paste_region(atlas, source, (645, 790, 750, 905), (8, 10, 1, 2))
    paste_region(atlas, source, (840, 790, 955, 905), (9, 10, 2, 2))
    paste_region(atlas, source, (955, 790, 1075, 905), (11, 10, 2, 2))
    paste_region(atlas, source, (1080, 790, 1180, 905), (13, 10, 2, 2))

    paste_region(atlas, source, (20, 910, 1230, 1015), (0, 12, 16, 2))
    paste_region(atlas, source, (20, 1015, 1230, 1120), (0, 14, 16, 2))
    paste_region(atlas, source, (20, 1120, 840, 1230), (0, 16, 12, 2))

    atlas = quantize_rgba(atlas, 64)
    atlas.save(ASSETS / "forest_tileset_16px.png", optimize=True)

    layout = {
        "image": "forest_tileset_16px.png",
        "tile_size": [16, 16],
        "atlas_size": [256, 288],
        "columns": 16,
        "rows": 18,
        "regions": {
            "terrain_and_grass": {"x": 0, "y": 0, "width": 16, "height": 2},
            "stone_and_crates": {"x": 0, "y": 2, "width": 16, "height": 2},
            "tree_module_a": {"x": 0, "y": 4, "width": 3, "height": 6},
            "tree_module_b": {"x": 3, "y": 4, "width": 4, "height": 6},
            "tree_module_c": {"x": 7, "y": 4, "width": 6, "height": 6},
            "vines": {"x": 13, "y": 4, "width": 3, "height": 6},
            "moving_platform": {"x": 0, "y": 10, "width": 8, "height": 2},
            "spring": {"x": 8, "y": 10, "width": 1, "height": 2},
            "metal_tiles": {"x": 9, "y": 10, "width": 6, "height": 2},
            "mountains": {"x": 0, "y": 12, "width": 16, "height": 2},
            "distant_forest": {"x": 0, "y": 14, "width": 16, "height": 2},
            "foreground_bushes": {"x": 0, "y": 16, "width": 12, "height": 2},
        },
    }
    (ASSETS / "forest_tileset_16px.json").write_text(
        json.dumps(layout, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    ASSETS.mkdir(parents=True, exist_ok=True)
    pack_character_sheet()
    pack_forest_tileset()
    print("Packed forest_mechanic_spritesheet_32px.png (256x192, 32px frames)")
    print("Packed forest_tileset_16px.png (256x288, 16px tiles)")
