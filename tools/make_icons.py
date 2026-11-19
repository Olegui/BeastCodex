"""Generates Art/Icons.tga: white glyphs the addon tints with each theme's colors.

    .cache/venv/Scripts/python tools/make_icons.py

One 64x64 cell per icon on a 1024x64 canvas (16 cells), in ICONS order; the order must
match ICON_CELL in UI/Window.lua.
"""
import math, os

from PIL import Image, ImageDraw, ImageOps

from tools.make_rows import stroke

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL, SS = 64, 4
WHITE = (255, 255, 255, 255)
ICONS = ("rotLeft", "rotRight", "play", "pause", "alert", "chevUp", "chevDown", "close", "guide")


def polygon(points):
    img = Image.new("RGBA", (CELL * SS, CELL * SS), (0, 0, 0, 0))
    ImageDraw.Draw(img).polygon([(x * SS, y * SS) for x, y in points], fill=WHITE)
    return img.resize((CELL, CELL), Image.LANCZOS)


def rotate_arrow(clockwise):
    """Most of a circle, open at the top-left, with an arrow head at its end."""
    cx, cy, r = 32, 33, 18
    # Screen angles grow clockwise (y points down): the arc runs clockwise and ends top-left.
    angles = [math.radians(-75 + 280 * i / 40) for i in range(41)]
    arc = [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in angles]
    icon = stroke((CELL, CELL), arc[:-3], WHITE, 6)
    a, tip = angles[-1], arc[-1]
    ahead, out = (-math.sin(a), math.cos(a)), (math.cos(a), math.sin(a))
    head = [(tip[0] + ahead[0] * 8, tip[1] + ahead[1] * 8),
            (tip[0] - ahead[0] * 6 + out[0] * 10, tip[1] - ahead[1] * 6 + out[1] * 10),
            (tip[0] - ahead[0] * 6 - out[0] * 10, tip[1] - ahead[1] * 6 - out[1] * 10)]
    icon.alpha_composite(polygon(head))
    return ImageOps.mirror(icon) if clockwise else icon  # mirrored: head top-right, pointing right


def alert():
    icon = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    icon.alpha_composite(stroke((CELL, CELL), [(32, 8), (58, 54), (6, 54), (32, 8)], WHITE, 6))
    icon.alpha_composite(stroke((CELL, CELL), [(32, 24), (32, 38)], WHITE, 6))
    icon.alpha_composite(stroke((CELL, CELL), [(32, 46), (32, 46.5)], WHITE, 7))
    return icon


def build():
    draw = {
        "rotLeft": lambda: rotate_arrow(False),
        "rotRight": lambda: rotate_arrow(True),
        "play": lambda: polygon([(20, 12), (52, 32), (20, 52)]),
        "pause": pause,
        "alert": alert,
        "chevUp": lambda: stroke((CELL, CELL), [(14, 40), (32, 22), (50, 40)], WHITE, 6),
        "chevDown": lambda: stroke((CELL, CELL), [(14, 24), (32, 42), (50, 24)], WHITE, 6),
        "close": close,
        "guide": guide,
    }
    atlas = Image.new("RGBA", (CELL * 16, CELL), (0, 0, 0, 0))
    for i, name in enumerate(ICONS):
        atlas.alpha_composite(draw[name](), (i * CELL, 0))
    return atlas


def guide():
    """An open book: two pages meeting at the spine, a line of text on each."""
    icon = stroke((CELL, CELL), [(32, 18), (32, 50)], WHITE, 5)
    for side in (-1, 1):
        icon.alpha_composite(stroke((CELL, CELL), [(32, 18), (32 + side * 12, 13), (32 + side * 25, 16),
                                                   (32 + side * 25, 47), (32 + side * 12, 44), (32, 50)], WHITE, 5))
        icon.alpha_composite(stroke((CELL, CELL), [(32 + side * 8, 25), (32 + side * 18, 25)], WHITE, 3.5))
        icon.alpha_composite(stroke((CELL, CELL), [(32 + side * 8, 33), (32 + side * 18, 33)], WHITE, 3.5))
    return icon


def close():
    icon = stroke((CELL, CELL), [(18, 18), (46, 46)], WHITE, 6)
    icon.alpha_composite(stroke((CELL, CELL), [(18, 46), (46, 18)], WHITE, 6))
    return icon


def pause():
    icon = stroke((CELL, CELL), [(23, 15), (23, 49)], WHITE, 9)
    icon.alpha_composite(stroke((CELL, CELL), [(41, 15), (41, 49)], WHITE, 9))
    return icon


if __name__ == "__main__":
    out = os.path.join(ROOT, "Art", "Icons.tga")
    build().save(out, format="TGA", compression=None)
    print("wrote", out)
