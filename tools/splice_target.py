"""Makes the small target-window art from the large generated image.

    .cache/venv/Scripts/python -m tools.splice_target
    .cache/venv/Scripts/python tools/make_skin.py art-src/HunterTarget.png Art/HunterTarget.tga --width 512

Cuts out plain bands of the source: rows of empty leather between the name
and the button, and columns of plain leather and plain button middle, so the
frame, its corners, the X and the button's rounded ends stay whole. Each cut
fades the two sides into each other over BLEND units so no seam shows.
Everything is measured on the source scaled to 2000 px wide.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art-src", "HunterTarget-source.jpg")
OUT = os.path.join(ROOT, "art-src", "HunterTarget.png")
ROW_CUTS = [(400, 1055)]                               # leather between the name and the button
COL_CUTS = [(330, 450), (760, 1240), (1560, 1670)]   # beside the button, and its plain middle
BLEND = 24


def cut_rows(img, start, end, n):
    """Drops rows [start, end), fading the n rows above `start` into those above `end`."""
    top = img.crop((0, 0, img.width, start))
    bottom = img.crop((0, end - n, img.width, img.height))
    out = Image.new("RGB", (img.width, start + img.height - end))
    out.paste(top, (0, 0))
    out.paste(bottom, (0, start - n))
    for i in range(n):
        y = start - n + i
        row = Image.blend(top.crop((0, y, img.width, y + 1)), bottom.crop((0, i, img.width, i + 1)), (i + 1) / (n + 1))
        out.paste(row, (0, y))
    return out


def splice(img, row_cuts, col_cuts, blend):
    k = img.width / 2000.0
    n = round(blend * k)
    for start, end in sorted(row_cuts, reverse=True):  # from the bottom, so earlier rows keep their place
        img = cut_rows(img, round(start * k), round(end * k), n)
    img = img.transpose(Image.Transpose.TRANSPOSE)     # columns as rows
    for start, end in sorted(col_cuts, reverse=True):
        img = cut_rows(img, round(start * k), round(end * k), n)
    return img.transpose(Image.Transpose.TRANSPOSE)


def shift(x, cuts):
    """Where source position x lands once `cuts` are removed."""
    return x - sum(e - s for s, e in cuts if e <= x)


if __name__ == "__main__":
    out = splice(Image.open(SRC).convert("RGB"), ROW_CUTS, COL_CUTS, BLEND)
    out.save(OUT)
    print("wrote %s (%dx%d); width %d units" % (OUT, out.width, out.height, shift(2000, COL_CUTS)))
    for name, x in (("close", 1735), ("title", 290), ("button", 470), ("button end", 1540)):
        print("  %s x: %d" % (name, shift(x, COL_CUTS)))
