"""Generates the Selva theme's row atlas, Art/SelvaRows.tga.

    .cache/venv/Scripts/python tools/make_rows.py

Four slots stacked vertically, 64 px apart, on a 1024x256 canvas:
  0 row box   1 hovered row   2 selected row (amber outline and glow)   3 tag pill
The row slots are ROW_W x ROW_H, matching the on-screen row's proportions, so
the rounded corners are not distorted when the texture is stretched to a row.
The numbers here must match rowArt in Skin.lua.
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_W, TEX_H, SLOT_H = 1024, 256, 64
ROW_W, ROW_H = 800, 44
PILL_W, PILL_H = 96, 30
SS = 4  # supersampling for smooth edges
AMBER = (243, 169, 65)


def rounded(size, radius, fill, outline=None, width=0):
    w, h = size
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        (width * SS // 2, width * SS // 2, w * SS - 1 - width * SS // 2, h * SS - 1 - width * SS // 2),
        radius=radius * SS, fill=fill, outline=outline, width=width * SS)
    return img.resize((w, h), Image.LANCZOS)


def build():
    atlas = Image.new("RGBA", (TEX_W, TEX_H), (0, 0, 0, 0))
    size = (ROW_W, ROW_H)
    atlas.alpha_composite(rounded(size, 9, (38, 54, 46, 150), (86, 108, 96, 150), 2), (0, 0))
    atlas.alpha_composite(rounded(size, 9, (255, 255, 255, 22), (150, 170, 158, 170), 2), (0, SLOT_H))

    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    glow.alpha_composite(rounded(size, 9, (0, 0, 0, 0), AMBER + (255,), 6))
    glow = glow.filter(ImageFilter.GaussianBlur(5))          # soft inner glow from the outline
    selected = rounded(size, 9, AMBER + (40,))
    selected.alpha_composite(glow)
    selected.alpha_composite(rounded(size, 9, (0, 0, 0, 0), AMBER + (255,), 2))
    atlas.alpha_composite(selected, (0, 2 * SLOT_H))

    atlas.alpha_composite(rounded((PILL_W, PILL_H), 9, (122, 62, 28, 235), (214, 126, 60, 255), 2), (0, 3 * SLOT_H))
    return atlas


if __name__ == "__main__":
    out = os.path.join(ROOT, "Art", "SelvaRows.tga")
    build().save(out, format="TGA", compression=None)
    print("wrote %s (%dx%d, slots every %d px, row %dx%d, pill %dx%d)" % (
        out, TEX_W, TEX_H, SLOT_H, ROW_W, ROW_H, PILL_W, PILL_H))
