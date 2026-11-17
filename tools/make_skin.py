"""Turns a generated window image into a game texture.

    .cache/venv/Scripts/python tools/make_skin.py <image> Art/<Name>.tga [--width 1024] [--keep-background]

Removes the solid magenta (#FF00FF) around the art, scales the image to
--width, and places it at the top-left of a power-of-two canvas saved as a
32-bit TGA. Prints the numbers the theme needs (image size inside the canvas).
A preview PNG over a checkerboard-like grey is written next to the source.
Needs Pillow (development only; lives in .cache/venv).
"""
import argparse, os

from PIL import Image, ImageChops


def key_magenta(img, lo=50, hi=130):
    """Returns an RGBA copy with magenta made transparent and its fringe despilled.

    Magenta-ness of a pixel is min(R, B) - G: 255 for pure magenta, 0 or less
    for anything grey, green, brown or white. Below `lo` a pixel is opaque,
    above `hi` it is fully transparent, in between it fades.
    """
    r, g, b = img.convert("RGB").split()
    m = ImageChops.subtract(ImageChops.darker(r, b), g)
    alpha = m.point(lambda v: 255 if v <= lo else 0 if v >= hi else int(255 * (hi - v) / (hi - lo)))
    # Despill: pull the magenta excess out of red and blue so edges do not glow pink.
    r, b = ImageChops.subtract(r, m), ImageChops.subtract(b, m)
    return Image.merge("RGBA", (r, g, b, alpha))


def pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


def build(src, width, keep_background=False):
    """Returns (canvas RGBA image, image width, image height) for the texture."""
    img = Image.open(src)
    img = img.convert("RGBA") if keep_background else key_magenta(img)
    height = round(img.height * width / img.width)
    img = img.resize((width, height), Image.LANCZOS)
    canvas = Image.new("RGBA", (pow2(width), pow2(height)), (0, 0, 0, 0))
    canvas.paste(img, (0, 0))
    return canvas, width, height


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--width", type=int, default=1024)
    ap.add_argument("--keep-background", action="store_true", help="do not remove magenta")
    a = ap.parse_args()

    canvas, w, h = build(a.src, a.width, a.keep_background)
    os.makedirs(os.path.dirname(os.path.abspath(a.dst)), exist_ok=True)
    canvas.save(a.dst, format="TGA", compression=None)

    preview = Image.new("RGBA", canvas.size, (70, 70, 70, 255))
    preview.alpha_composite(canvas)
    preview_path = os.path.splitext(a.src)[0] + ".preview.png"
    preview.crop((0, 0, w, h)).save(preview_path)

    print("texture %s: canvas %dx%d, image %dx%d" % (a.dst, canvas.width, canvas.height, w, h))
    print("theme: texW = %d, texH = %d, imgW = %d, imgH = %d" % (canvas.width, canvas.height, w, h))
    print("preview: %s" % preview_path)


if __name__ == "__main__":
    main()
