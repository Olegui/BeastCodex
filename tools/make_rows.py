"""Generates each panel theme's atlas, Art/<Theme>Rows.tga.

    .cache/venv/Scripts/python tools/make_rows.py

The atlas holds everything the addon draws itself inside a themed window.
Slots are 64 px apart on a 1024x512 canvas:
  0 row box   1 hovered row   2 selected row (accent outline and glow)
  3 tag pill, the "unavailable" map button face, the "clear pins" button face
  4 drop-down field with arrow, checkbox, tick

The button, field and checkbox pieces are cut from the theme's own art
(art-src/<Theme>.png), so they carry the same surface, outline and wear as the
search field and buttons painted there. Positions must match rowArt in Skin.lua.
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_W, TEX_H, SLOT_H = 1024, 512, 64
ROW_W, ROW_H = 800, 44
PILL_W, PILL_H = 96, 30
GREY_PILL_X = 920
BTN_W, BTN_H, OFF_X, FACE_X = 390, 60, 128, 528  # button faces share the pill's slot
OFF_PAD, OFF_W = 6, 338                          # the unavailable face is cut 6 units larger all round
CONTROLS_Y = 4 * SLOT_H                           # second band: field, checkbox, tick
FIELD_W, FIELD_H, BOX_X, TICK_X, BOX = 362, 56, 368, 432, 48
CLEAR_X, CLEAR_W, CLEAR_H = 496, 54, 42
SS = 4  # supersampling for smooth edges

# Where the painted controls are in the art, in a 2000-px-wide frame. Both
# panel themes share the layout, so these hold for every theme.
SEARCH = (1413, 107, 1805, 166)       # the search field: the model for fields and outline buttons
MAGNIFIER = (1740, 116, 1794, 158)    # painted inside it; removed for our own fields
MAP_BUTTON = (1447, 960, 1851, 1022)  # the main button: the model for its unavailable state
CLOSE = (1827, 107, 1887, 167)        # the round close button: the model for the checkbox

# Per theme: row fill, row border, hover border, accent, pill fill, pill border.
PALETTES = {
    "Selva": ((38, 54, 46, 150), (86, 108, 96, 150), (150, 170, 158, 170), (243, 169, 65),
              (122, 62, 28, 235), (214, 126, 60, 255)),
    "Hunter": ((34, 20, 13, 135), (150, 112, 70, 140), (205, 168, 110, 180), (219, 176, 97),
               (98, 62, 22, 235), (219, 176, 97, 255)),
}


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


def cut(art, box, size, erase=None, erase_from=None):
    """Cuts `box` (2000-wide frame) out of the art as a pill-shaped piece of `size`.

    The piece gets a transparent surround, so only the control itself remains,
    not the wood or leather it was painted on. `erase` blanks a sub-box with
    the color found at `erase_from`.
    """
    k = art.width / 2000.0
    src = art.convert("RGB")
    if erase:
        color = src.getpixel((int(erase_from[0] * k), int(erase_from[1] * k)))
        ImageDraw.Draw(src).rectangle([int(v * k) for v in erase], fill=color)
    piece = src.crop([int(round(v * k)) for v in box]).resize(size, Image.LANCZOS).convert("RGBA")
    mask = rounded(size, min(size) // 2, (255, 255, 255, 255)).getchannel("A")
    piece.putalpha(mask)
    return piece


def cut_shape(art, box, pad, size):
    """Cuts a painted control with its real outline, found in the art itself.

    A pill mask misses the corners of a button that is not a perfect pill, and
    its own rim then shows around the piece. Here the mask is every pixel
    brighter than halfway between the surface around the control and the
    control's middle, closed over cracks and grown a little, so the whole
    control is covered, rim included. The cut is `pad` units larger than `box`.
    """
    k = art.width / 2000.0
    big = (box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad)
    region = art.convert("RGB").crop([int(round(v * k)) for v in big])
    lum = region.convert("L")
    around = lum.getpixel((2, 2))
    middle = lum.getpixel((lum.width // 2, lum.height // 2))
    threshold = (around + middle) / 2
    mask = lum.point(lambda v: 255 if v > threshold else 0)
    mask = mask.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.MinFilter(15))  # close cracks and dark wear
    mask = mask.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(1.5))  # take the rim too
    piece = region.convert("RGBA")
    piece.putalpha(mask)
    return piece.resize(size, Image.LANCZOS)


def desaturate(piece, amount=0.88, level=105):
    """Same surface and wear, most of the color taken out.

    Brightness is brought down to about `level` on average, so a bright button
    (Selva's amber) reads as unavailable rather than as a white one.
    """
    alpha = piece.getchannel("A")
    rgb = piece.convert("RGB")
    lum = rgb.convert("L")
    mean = sum(lum.get_flattened_data()) / (lum.width * lum.height)
    darken = min(1.0, level / mean)
    grey = lum.point(lambda v: int(v * darken)).convert("RGB")
    out = Image.blend(rgb, grey, amount).convert("RGBA")
    out.putalpha(alpha)
    return out


def build(name):
    fill, border, hover, accent, pill, pill_border = PALETTES[name]
    art = Image.open(os.path.join(ROOT, "art-src", name + ".png"))
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
    # Grey version of the tag, for plain rares.
    atlas.alpha_composite(rounded((PILL_W, PILL_H), 9, (72, 72, 72, 235), (165, 165, 165, 255), 2), (GREY_PILL_X, 3 * SLOT_H))

    inside = ((SEARCH[0] + SEARCH[2]) // 2, (SEARCH[1] + SEARCH[3]) // 2)  # plain interior of the search field
    # The map button while a creature has no location: the painted button itself, drained of color.
    atlas.alpha_composite(desaturate(cut_shape(art, MAP_BUTTON, OFF_PAD, (OFF_W, BTN_H))), (OFF_X, 3 * SLOT_H))
    # "Clear pins": the search field's look, without its magnifier.
    atlas.alpha_composite(cut(art, SEARCH, (BTN_W, BTN_H), MAGNIFIER, inside), (FACE_X, 3 * SLOT_H))

    # Drop-down field: the search field again, with a small arrow instead of the magnifier.
    field = cut(art, SEARCH, (FIELD_W, FIELD_H), MAGNIFIER, inside)
    field.alpha_composite(stroke((FIELD_W, FIELD_H), [(FIELD_W - 42, 24), (FIELD_W - 33, 33), (FIELD_W - 24, 24)],
                                 accent + (255,), 2.4))
    atlas.alpha_composite(field, (0, CONTROLS_Y))
    # Checkbox: the round close button with its X removed.
    cx, cy = (CLOSE[0] + CLOSE[2]) / 2, (CLOSE[1] + CLOSE[3]) / 2
    box = cut(art, CLOSE, (BOX, BOX), (cx - 13, cy - 13, cx + 13, cy + 13), (cx - 16, cy))
    atlas.alpha_composite(box, (BOX_X, CONTROLS_Y))
    atlas.alpha_composite(stroke((BOX, BOX), [(13, 25), (21, 33), (35, 15)], accent + (255,), 5), (TICK_X, CONTROLS_Y))
    # The search field's magnifier spot, emptied, with an X: laid over the magnifier while there is text.
    k = art.width / 2000.0
    src = art.convert("RGB")
    color = src.getpixel((int(inside[0] * k), int(inside[1] * k)))
    spot = src.crop([int(round(v * k)) for v in MAGNIFIER])
    ImageDraw.Draw(spot).rectangle((0, 0, spot.width, spot.height), fill=color)
    spot = spot.resize((CLEAR_W, CLEAR_H), Image.LANCZOS).convert("RGBA")
    cx, cy, r = CLEAR_W / 2, CLEAR_H / 2, 8
    spot.alpha_composite(stroke((CLEAR_W, CLEAR_H), [(cx - r, cy - r), (cx + r, cy + r)], accent + (255,), 2.6))
    spot.alpha_composite(stroke((CLEAR_W, CLEAR_H), [(cx - r, cy + r), (cx + r, cy - r)], accent + (255,), 2.6))
    atlas.alpha_composite(spot, (CLEAR_X, CONTROLS_Y))
    return atlas


if __name__ == "__main__":
    for name in PALETTES:
        out = os.path.join(ROOT, "Art", name + "Rows.tga")
        build(name).save(out, format="TGA", compression=None)
        print("wrote %s (%dx%d)" % (out, TEX_W, TEX_H))
