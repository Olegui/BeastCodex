"""Generates each panel theme's row atlas, Art/<Theme>Rows.tga.

    .cache/venv/Scripts/python tools/make_rows.py

Slots stacked vertically, 64 px apart, on a 1024x512 canvas:
  0 row box   1 hovered row   2 selected row (accent outline and glow)
  3 tag pill, then the grey "unavailable" button face and the outline button face
  4 drop-down field with arrow, checkbox, tick
The row slots are ROW_W x ROW_H, matching the on-screen row's proportions, so
the rounded corners are not distorted when the texture is stretched to a row.
The numbers here must match rowArt in Skin.lua.
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_W, TEX_H, SLOT_H = 1024, 512, 64
ROW_W, ROW_H = 800, 44
PILL_W, PILL_H = 96, 30
BTN_W, BTN_H, OFF_X, FACE_X = 390, 60, 128, 528  # button faces share the pill's slot
CONTROLS_Y = 4 * SLOT_H                           # second band: field, checkbox, tick
FIELD_W, FIELD_H, BOX_X, TICK_X, BOX = 330, 56, 352, 416, 48
SS = 4  # supersampling for smooth edges


def rounded(size, radius, fill, outline=None, width=0):
    w, h = size
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        (width * SS // 2, width * SS // 2, w * SS - 1 - width * SS // 2, h * SS - 1 - width * SS // 2),
        radius=radius * SS, fill=fill, outline=outline, width=width * SS)
    return img.resize((w, h), Image.LANCZOS)


def stroke(size, points, color, width):
    """A round-capped polyline, supersampled."""
    w, h = size
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(x * SS, y * SS) for x, y in points]
    d.line(pts, fill=color, width=int(width * SS), joint="curve")
    r = width * SS / 2
    for x, y in pts:
        d.ellipse((x - r, y - r, x + r, y + r), fill=color)
    return img.resize((w, h), Image.LANCZOS)


# Per theme: row fill, row border, hover border, accent, pill fill, pill border, button well.
PALETTES = {
    "Selva": ((38, 54, 46, 150), (86, 108, 96, 150), (150, 170, 158, 170), (243, 169, 65),
              (122, 62, 28, 235), (214, 126, 60, 255), (14, 22, 18, 200)),
    "Hunter": ((34, 20, 13, 135), (150, 112, 70, 140), (205, 168, 110, 180), (219, 176, 97),
               (98, 62, 22, 235), (219, 176, 97, 255), (30, 17, 11, 200)),
}


def build(name):
    fill, border, hover, accent, pill, pill_border, well = PALETTES[name]
    atlas = Image.new("RGBA", (TEX_W, TEX_H), (0, 0, 0, 0))
    size = (ROW_W, ROW_H)
    atlas.alpha_composite(rounded(size, 9, fill, border, 2), (0, 0))
    atlas.alpha_composite(rounded(size, 9, (255, 255, 255, 22), hover, 2), (0, SLOT_H))

    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    glow.alpha_composite(rounded(size, 9, (0, 0, 0, 0), accent + (255,), 6))
    glow = glow.filter(ImageFilter.GaussianBlur(5))          # soft inner glow from the outline
    selected = rounded(size, 9, accent + (40,))
    selected.alpha_composite(glow)
    selected.alpha_composite(rounded(size, 9, (0, 0, 0, 0), accent + (255,), 2))
    atlas.alpha_composite(selected, (0, 2 * SLOT_H))

    atlas.alpha_composite(rounded((PILL_W, PILL_H), 9, pill, pill_border, 2), (0, 3 * SLOT_H))
    # Grey face laid over the map button while a creature has no location.
    atlas.alpha_composite(rounded((BTN_W, BTN_H), BTN_H // 2, (96, 94, 90, 255), (140, 138, 132, 255), 2),
                          (OFF_X, 3 * SLOT_H))
    # Outline face of the "clear pins" button, drawn only while pins exist.
    atlas.alpha_composite(rounded((BTN_W, BTN_H), BTN_H // 2, well, accent + (255,), 2), (FACE_X, 3 * SLOT_H))

    # Controls drawn by the addon, made to look like the ones painted in the art:
    # a recessed field with a thin accent outline and a small arrow, and a checkbox.
    field = rounded((FIELD_W, FIELD_H), 12, well, accent + (230,), 2)
    field.alpha_composite(stroke((FIELD_W, FIELD_H), [(FIELD_W - 40, 23), (FIELD_W - 31, 32), (FIELD_W - 22, 23)],
                                 accent + (255,), 2.4))
    atlas.alpha_composite(field, (0, CONTROLS_Y))
    atlas.alpha_composite(rounded((BOX, BOX), 10, well, accent + (230,), 3), (BOX_X, CONTROLS_Y))
    atlas.alpha_composite(stroke((BOX, BOX), [(12, 25), (21, 34), (36, 14)], accent + (255,), 5), (TICK_X, CONTROLS_Y))
    return atlas


if __name__ == "__main__":
    for name in PALETTES:
        out = os.path.join(ROOT, "Art", name + "Rows.tga")
        build(name).save(out, format="TGA", compression=None)
        print("wrote %s (%dx%d, slots every %d px, row %dx%d, pill %dx%d)" % (
            out, TEX_W, TEX_H, SLOT_H, ROW_W, ROW_H, PILL_W, PILL_H))
