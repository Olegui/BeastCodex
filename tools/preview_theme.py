"""Draws a theme's rectangles over its source image, to check measurements.

    .cache/venv/Scripts/python tools/preview_theme.py <theme> <image> <out.png>

Reads the theme from Skin.lua through the offline Lua runtime, so what is
drawn is exactly what the addon will use.
"""
import os, sys

from lupa import lua51
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    name, src, out = sys.argv[1:4]
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    ns = lua.eval("{}")
    with open(os.path.join(ROOT, "Skin.lua"), encoding="utf-8") as f:
        lua.eval("function(src, ns) loadstring(src)('BeastCodex', ns) end")(f.read(), ns)
    t = ns.Themes[name]
    img = Image.open(src).convert("RGBA")
    back = Image.new("RGBA", img.size, (90, 30, 90, 255))
    back.alpha_composite(img)
    k = img.width / t.W
    d = ImageDraw.Draw(back)

    def box(r, color, label):
        x, y = r.x * k, r.y * k
        w, h = (r.w or 60) * k, (r.h or 14) * k
        d.rectangle((x, y, x + w, y + h), outline=color, width=3)
        d.text((x + 4, y + 2), label, fill=color)

    for key in ("search", "searchClear", "close", "check", "check2", "resetButton", "themeButton", "credits", "count", "list", "model", "name", "text", "mapButton", "clearButton"):
        box(t[key], (255, 80, 80, 255), key)
    for i in range(1, 4):
        f = t.filters[i]
        box(f, (80, 200, 255, 255), "filter%d" % i)
        if f.label and f.label is not True:
            box(f.label, (255, 255, 80, 255), "label")
    rows = int(t.list.h // t.rowH)
    for i in range(1, rows):
        y = (t.list.y + i * t.rowH) * k
        d.line((t.list.x * k, y, (t.list.x + t.list.w) * k, y), fill=(255, 255, 255, 60), width=1)
    back.convert("RGB").resize((1600, round(1600 * img.height / img.width))).save(out, quality=85)
    print("window %dx%d units, %d rows; wrote %s" % (t.W, t.H, rows, out))


if __name__ == "__main__":
    main()
