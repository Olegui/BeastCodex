"""Writes the window title into a panel theme's art, replacing the painted one.

    .cache/venv/Scripts/python tools/make_title.py

For each theme: the old title is covered with the top bar's own surface,
cloned from further right along the bar (the wood grain and the jungle haze
both run horizontally), then "Beast Codex" is drawn in Trade Winds (OFL, by
Sideshow; art-src/fonts) in the color the old title had. Works in place on
art-src/<Theme>.png and gives the same result however many times it is run.
"""
import os
from statistics import median

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "art-src", "fonts", "TradeWinds-Regular.ttf")
TEXT = "Beast Codex"
THEMES = ("Hunter", "Selva")

# In a 2000-px-wide frame.
OLD_TITLE = (196, 90, 676, 186)   # the painted "BEAST CODEX" with margin; the paw emblem ends at 205
CLONE_SHIFT = 500                 # same band of the top bar, this far to the right, is plain
LEFT, MIDDLE_Y = 226, 138         # where the new title starts and its vertical middle
MAX_W, CAP_H = 440, 50            # room available and wanted capital height


def title_color(rgb, k):
    """The old title's own color: the median of the brightest pixels in its area."""
    box = [int(v * k) for v in OLD_TITLE]
    px = list(rgb.crop(box).get_flattened_data())
    px.sort(key=lambda p: p[0] + p[1] + p[2], reverse=True)
    top = px[:max(1, len(px) // 12)]
    return tuple(int(median(p[i] for p in top)) for i in range(3))


def retitle(path, color=None):
    img = Image.open(path)
    alpha = img.getchannel("A") if img.mode == "RGBA" else None
    rgb = img.convert("RGB")
    k = rgb.width / 2000.0
    color = color or title_color(rgb, k)

    # 1. cover the old title
    box = [int(v * k) for v in OLD_TITLE]
    shift = int(CLONE_SHIFT * k)
    patch = rgb.crop((box[0] + shift, box[1], box[2] + shift, box[3]))
    size = patch.size
    mask = Image.new("L", size, 0)
    # Fully opaque over the old letters, fading out within the margin so no seam shows.
    ImageDraw.Draw(mask).rectangle((16, 12, size[0] - 17, size[1] - 13), fill=255)
    rgb.paste(patch, box[:2], mask.filter(ImageFilter.GaussianBlur(7)))

    # 2. size the font by capital height, then shrink if the text is too wide
    px_size = int(CAP_H * k / 0.72)
    while True:
        font = ImageFont.truetype(FONT, px_size)
        left, top, right, bottom = font.getbbox(TEXT)
        cap = font.getbbox("B")
        if right - left <= MAX_W * k and cap[3] - cap[1] <= CAP_H * k + 1:
            break
        px_size -= 2
    x = int(LEFT * k) - left
    y = int(MIDDLE_Y * k) - (cap[1] + cap[3]) // 2   # center on the capitals, ignoring descenders

    # 3. a soft dark shadow under the letters, then the letters
    layer = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((x + int(2 * k), y + int(3 * k)), TEXT, font=font, fill=(0, 0, 0, 170))
    layer = layer.filter(ImageFilter.GaussianBlur(2 * k))
    ImageDraw.Draw(layer).text((x, y), TEXT, font=font, fill=color + (255,))
    out = rgb.convert("RGBA")
    out.alpha_composite(layer)

    if alpha:
        out.putalpha(alpha)
        out.save(path)
    else:
        out.convert("RGB").save(path)
    return color, px_size, (right - left) / k


if __name__ == "__main__":
    for name in THEMES:
        path = os.path.join(ROOT, "art-src", name + ".png")
        color, size, width = retitle(path)
        print("%s: color %s, font %d px, title %.0f units wide" % (name, color, size, width))
