"""Turns the two generated paw icons into the files the addon and CurseForge use.

    .cache/venv/Scripts/python tools/make_icon.py

  art-src/icon-source.jpg (flat paw)     -> Art/Icon.tga, 64 px, the in-game icon
  art-src/logo-source.jpg (detailed paw) -> media/logo-400.png, media/logo-128.png (CurseForge)

The flat icon is cropped a little toward its middle first, so the paw fills
more of the square and still reads at the ~20 px of a minimap button.
Needs Pillow (development only; .cache/venv).
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CROP = 0.86  # share of the flat icon kept around its center


def main():
    flat = Image.open(os.path.join(ROOT, "art-src", "icon-source.jpg")).convert("RGB")
    m = round(flat.width * (1 - CROP) / 2)
    flat = flat.crop((m, m, flat.width - m, flat.height - m))
    flat.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, "art-src", "icon.png"))
    flat.resize((64, 64), Image.LANCZOS).convert("RGBA").save(
        os.path.join(ROOT, "Art", "Icon.tga"), format="TGA", compression=None)

    logo = Image.open(os.path.join(ROOT, "art-src", "logo-source.jpg")).convert("RGB")
    logo.resize((1024, 1024), Image.LANCZOS).save(os.path.join(ROOT, "art-src", "logo.png"))
    os.makedirs(os.path.join(ROOT, "media"), exist_ok=True)
    for size in (400, 128):
        logo.resize((size, size), Image.LANCZOS).save(os.path.join(ROOT, "media", "logo-%d.png" % size))

    # Preview sheet: the in-game icon at real sizes.
    sheet = Image.new("RGB", (300, 84), (28, 26, 24))
    x = 10
    for size in (64, 36, 24, 18):
        sheet.paste(flat.resize((size, size), Image.LANCZOS), (x, 10))
        x += size + 16
    sheet.save(os.path.join(ROOT, ".cache", "icon-sizes.png"))
    print("wrote Art/Icon.tga, media/logo-400.png, media/logo-128.png")


if __name__ == "__main__":
    main()
