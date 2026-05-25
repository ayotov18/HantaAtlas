#!/usr/bin/env python3
"""Build the HantaAtlas App Store screenshot set deterministically.

The source simulator screenshots are treated as immutable bitmaps: this script
only resizes each screenshot into the detected transparent screen cutout of the
device frame, masks it to the cutout, and composites the frame above it.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from urllib.request import urlretrieve

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ModuleNotFoundError as exc:  # pragma: no cover - helpful local error
    raise SystemExit(
        "Pillow is required. Run: python3 -m venv .venv-screenshots && "
        ".venv-screenshots/bin/python -m pip install Pillow"
    ) from exc


ROOT = Path(__file__).resolve().parents[1]
CANVAS_SIZE = (1290, 2796)
BACKGROUND = "#C15F3C"
OUTPUT_DIR = ROOT / "screenshots" / "final"
ASSET_DIR = ROOT / "screenshots" / "assets"
SHOWCASE_PATH = ROOT / "screenshots" / "showcase.png"
FRAME_PATH = ASSET_DIR / "iphone-17-pro.png"
FRAME_URL = (
    "https://raw.githubusercontent.com/jamesjingyi/mockup-device-frames/main/"
    "Exports/iOS/17%20Pro/17%20Pro%20-%20Deep%20Blue.png"
)

DOCUMENTS = Path("/Users/anthonyyotov/Documents")
MAX_TEXT_WIDTH = int(CANVAS_SIZE[0] * 0.70)
HEADLINE_AREA_HEIGHT = int(CANVAS_SIZE[1] * 0.22)
DEVICE_TARGET_WIDTH = 940
DEVICE_TOP = int(CANVAS_SIZE[1] * 0.35)
DEVICE_SHADOW_OFFSET = 44
DEVICE_SHADOW_BLUR = 38

LINE_ONE_FONTS = (
    "/System/Library/Fonts/SFCompact.ttf",
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
)
LINE_TWO_FONTS = (
    "/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf",
    "/System/Library/Fonts/SFCompact.ttf",
    "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
)


@dataclass(frozen=True)
class Shot:
    filename: str
    source: Path
    line_one: str
    line_two: str


SHOTS = (
    Shot(
        "01-know.png",
        DOCUMENTS / "screenshots-for-claude-8.png",
        "KNOW",
        "FIRST WHEN HANTAVIRUS HITS",
    ),
    Shot(
        "02-track.png",
        DOCUMENTS / "screenshots-for-claude-1.png",
        "TRACK",
        "COUNTRIES YOU CARE ABOUT",
    ),
    Shot(
        "03-see.png",
        DOCUMENTS / "screenshots-for-claude-4.png",
        "SEE",
        "EVERY OUTBREAK WORLDWIDE",
    ),
    Shot(
        "04-sourced.png",
        DOCUMENTS / "screenshots-for-claude-3.png",
        "SOURCED",
        "FROM HEALTH MINISTRIES",
    ),
)


def ensure_directories() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def ensure_frame() -> None:
    if not FRAME_PATH.exists():
        urlretrieve(FRAME_URL, FRAME_PATH)


def load_font(paths: Iterable[str], size: int) -> ImageFont.FreeTypeFont:
    for path in paths:
        font_path = Path(path)
        if font_path.exists():
            return ImageFont.truetype(str(font_path), size)
    raise FileNotFoundError("No suitable heavy system font was found.")


def transparent_components(alpha: Image.Image, threshold: int = 250) -> list[dict]:
    width, height = alpha.size
    pixels = alpha.load()
    seen = bytearray(width * height)
    components: list[dict] = []

    for y in range(height):
        for x in range(width):
            index = y * width + x
            if seen[index] or pixels[x, y] >= threshold:
                continue

            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen[index] = 1
            min_x = max_x = x
            min_y = max_y = y
            count = 0
            touches_edge = False

            while queue:
                cx, cy = queue.popleft()
                count += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)
                if cx == 0 or cy == 0 or cx == width - 1 or cy == height - 1:
                    touches_edge = True

                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < width and 0 <= ny < height:
                        next_index = ny * width + nx
                        if not seen[next_index] and pixels[nx, ny] < threshold:
                            seen[next_index] = 1
                            queue.append((nx, ny))

            components.append(
                {
                    "count": count,
                    "bbox": (min_x, min_y, max_x + 1, max_y + 1),
                    "seed": (x, y),
                    "touches_edge": touches_edge,
                }
            )

    return sorted(components, key=lambda component: component["count"], reverse=True)


def build_screen_mask(frame: Image.Image, threshold: int = 250) -> tuple[Image.Image, tuple[int, int, int, int]]:
    alpha = frame.getchannel("A")
    candidates = [
        component
        for component in transparent_components(alpha, threshold)
        if not component["touches_edge"]
    ]
    if not candidates:
        raise RuntimeError("Could not find an interior transparent screen cutout.")

    screen = max(candidates, key=lambda component: component["count"])
    width, height = alpha.size
    pixels = alpha.load()
    seen = bytearray(width * height)
    mask = Image.new("L", (width, height), 0)
    mask_pixels = mask.load()
    queue: deque[tuple[int, int]] = deque([screen["seed"]])
    sx, sy = screen["seed"]
    seen[sy * width + sx] = 1

    while queue:
        cx, cy = queue.popleft()
        mask_pixels[cx, cy] = 255
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if 0 <= nx < width and 0 <= ny < height:
                next_index = ny * width + nx
                if not seen[next_index] and pixels[nx, ny] < threshold:
                    seen[next_index] = 1
                    queue.append((nx, ny))

    return mask, screen["bbox"]


def resize_frame_and_mask(
    frame: Image.Image, screen_mask: Image.Image
) -> tuple[Image.Image, Image.Image, tuple[int, int, int, int]]:
    target_height = round(frame.height * (DEVICE_TARGET_WIDTH / frame.width))
    target_size = (DEVICE_TARGET_WIDTH, target_height)
    resized_frame = frame.resize(target_size, Image.Resampling.LANCZOS)
    resized_mask = screen_mask.resize(target_size, Image.Resampling.LANCZOS)
    bbox = resized_mask.getbbox()
    if bbox is None:
        raise RuntimeError("The resized screen mask is empty.")
    return resized_frame, resized_mask, bbox


def build_device(
    source_path: Path,
    frame: Image.Image,
    screen_mask: Image.Image,
    screen_bbox: tuple[int, int, int, int],
) -> Image.Image:
    source = Image.open(source_path).convert("RGB")
    x0, y0, x1, y1 = screen_bbox
    screen_size = (x1 - x0, y1 - y0)
    resized_source = source.resize(screen_size, Image.Resampling.LANCZOS).convert("RGBA")

    device = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    device.paste(resized_source, (x0, y0), screen_mask.crop(screen_bbox))
    device.alpha_composite(frame)
    return device


def text_layer(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> Image.Image:
    bbox = font.getbbox(text)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    pad = 12
    layer = Image.new("RGBA", (width + pad * 2, height + pad * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.text((pad - bbox[0], pad - bbox[1]), text, font=font, fill=(255, 255, 255, 255))
    cropped = layer.crop(layer.getbbox())
    if cropped.width > max_width:
        cropped = cropped.resize(
            (max_width, cropped.height),
            Image.Resampling.LANCZOS,
        )
    return cropped


def draw_headline(canvas: Image.Image, shot: Shot) -> None:
    line_one = text_layer(shot.line_one, load_font(LINE_ONE_FONTS, 200), MAX_TEXT_WIDTH)
    line_two = text_layer(shot.line_two, load_font(LINE_TWO_FONTS, 96), MAX_TEXT_WIDTH)
    gap = 26
    total_height = line_one.height + gap + line_two.height
    y = max(88, (HEADLINE_AREA_HEIGHT - total_height) // 2 + 20)

    for layer in (line_one, line_two):
        x = (CANVAS_SIZE[0] - layer.width) // 2
        canvas.alpha_composite(layer, (x, y))
        y += layer.height + gap


def draw_device(canvas: Image.Image, device: Image.Image, shadow_mask: Image.Image) -> None:
    x = (CANVAS_SIZE[0] - device.width) // 2
    y = DEVICE_TOP

    shadow_alpha = shadow_mask.filter(ImageFilter.GaussianBlur(DEVICE_SHADOW_BLUR))
    shadow_alpha = shadow_alpha.point(lambda value: int(value * 0.48))
    shadow = Image.new("RGBA", device.size, (0, 0, 0, 0))
    shadow.putalpha(shadow_alpha)
    canvas.alpha_composite(shadow, (x, y + DEVICE_SHADOW_OFFSET))
    canvas.alpha_composite(device, (x, y))


def compose_shot(
    shot: Shot,
    frame: Image.Image,
    screen_mask: Image.Image,
    screen_bbox: tuple[int, int, int, int],
) -> Path:
    canvas = Image.new("RGBA", CANVAS_SIZE, BACKGROUND)
    draw_headline(canvas, shot)
    device = build_device(shot.source, frame, screen_mask, screen_bbox)
    draw_device(canvas, device, frame.getchannel("A"))
    output_path = OUTPUT_DIR / shot.filename
    canvas.convert("RGB").save(output_path)
    return output_path


def build_showcase(paths: list[Path]) -> None:
    images = [Image.open(path).convert("RGB") for path in paths]
    showcase = Image.new("RGB", (CANVAS_SIZE[0] * len(images), CANVAS_SIZE[1]), BACKGROUND)
    for index, image in enumerate(images):
        showcase.paste(image, (index * CANVAS_SIZE[0], 0))
    showcase.save(SHOWCASE_PATH)


def validate_inputs() -> None:
    missing = [str(shot.source) for shot in SHOTS if not shot.source.exists()]
    if missing:
        raise FileNotFoundError("Missing simulator screenshot(s): " + ", ".join(missing))


def main() -> None:
    ensure_directories()
    ensure_frame()
    validate_inputs()

    frame = Image.open(FRAME_PATH).convert("RGBA")
    original_mask, original_bbox = build_screen_mask(frame)
    frame, screen_mask, screen_bbox = resize_frame_and_mask(frame, original_mask)

    outputs = [compose_shot(shot, frame, screen_mask, screen_bbox) for shot in SHOTS]
    build_showcase(outputs)

    print("HantaAtlas App Store screenshots built")
    print(f"Detected original screen cutout: {original_bbox}")
    print(f"Rendered device size: {frame.size[0]}x{frame.size[1]}")
    print(f"Rendered screen cutout: {screen_bbox}")
    print()
    for shot, output in zip(SHOTS, outputs, strict=True):
        with Image.open(output) as image:
            width, height = image.size
        print(
            f"{output} | {width}x{height} | source: {shot.source} | "
            f"headline: {shot.line_one} / {shot.line_two} | "
            "deviations: none; source resized and masked only"
        )
    with Image.open(SHOWCASE_PATH) as image:
        width, height = image.size
    print(f"{SHOWCASE_PATH} | {width}x{height} | 4-up side-by-side preview")


if __name__ == "__main__":
    main()
