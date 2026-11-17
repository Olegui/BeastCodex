"""Builds the CurseForge/README banner (media/banner-<lang>.png).

Layout follows the EAD - Skill Preview banner: framed dark panel, title,
subtitle, short bullet list, footer on the left; two in-game window crops on
the right. Usage: make_banner.py <front.png> <back.png>
(each shot already cropped to the addon window).
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
FONTS = Path("C:/Windows/Fonts")
W, H = 1980, 980          # 2x of ~990x490 shown on CurseForge

BG_TOP, BG_BOT = (30, 26, 20), (14, 12, 9)
GOLD = (201, 160, 84)
GOLD_DIM = (120, 94, 52)
CREAM = (236, 226, 204)
GREEN = (150, 196, 110)
MUTED = (150, 140, 120)

TEXT = {
    "pt": {
        "sub": "World of Warcraft: Forever",
        "bullets": [
            "Todas as feras domáveis e indomáveis",
            "Filtros por família, zona e nível",
            "Modelo 3D ao passar o cursor",
            "Pins no mapa em cada ponto de aparição",
            "Habilidades, dieta e velocidade de ataque",
            "Três temas, troca na hora",
            "11 idiomas",
        ],
        "footer": "Desenvolvido por Oleg  •  assantech.com.br",
    },
    "en": {
        "sub": "World of Warcraft: Forever",
        "bullets": [
            "Every tameable and untameable beast",
            "Filter by family, zone and level",
            "3D model on hover",
            "Map pins on every spawn point",
            "Abilities, diet and attack speed",
            "Three themes, switched live",
            "11 languages",
        ],
        "footer": "Developed by Oleg  •  assantech.com.br",
    },
}


def font(name, size):
    return ImageFont.truetype(str(name), size)


def gradient(w, h, top, bot):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bot)))
    return img


def paste_shadow(base, tile, x, y):
    sh = Image.new("RGBA", (tile.width + 60, tile.height + 60), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rectangle([30, 36, 30 + tile.width, 36 + tile.height], fill=(0, 0, 0, 170))
    sh = sh.filter(ImageFilter.GaussianBlur(14))
    base.paste(sh, (x - 30, y - 30), sh)
    base.paste(tile, (x, y))


def build(lang, shots, out):
    t = TEXT[lang]
    img = gradient(W, H, BG_TOP, BG_BOT).convert("RGBA")
    d = ImageDraw.Draw(img)
    # frame
    d.rectangle([14, 14, W - 15, H - 15], outline=GOLD, width=5)
    d.rectangle([28, 28, W - 29, H - 29], outline=GOLD_DIM, width=1)

    # right: window crops, cascaded (back one up-left, front one down-right)
    tw = 1010
    tiles = []
    for p in shots:
        im = Image.open(p).convert("RGB")
        im = im.resize((tw, round(im.height * tw / im.width)), Image.LANCZOS)
        rim = Image.new("RGB", (im.width + 4, im.height + 4), GOLD_DIM)
        rim.paste(im, (2, 2))
        tiles.append(rim)
    back, front = tiles[1], tiles[0]
    paste_shadow(img, back, W - 60 - tw - 150, 60)
    paste_shadow(img, front, W - 60 - tw, H - 60 - front.height)
    left_limit = W - 60 - tw - 150 - 40

    # left: text
    lx = 80
    title = font(ROOT / "art-src/fonts/TradeWinds-Regular.ttf", 108)
    while d.textlength("Beast Codex", font=title) > left_limit - lx and title.size > 60:
        title = font(ROOT / "art-src/fonts/TradeWinds-Regular.ttf", title.size - 4)
    d.text((lx, 110), "Beast Codex", font=title, fill=GOLD)
    sub = font(FONTS / "georgia.ttf", 40)
    d.text((lx, 260), t["sub"], font=sub, fill=GREEN)
    d.line([(lx, 335), (lx + 190, 335)], fill=GOLD_DIM, width=3)

    body = font(FONTS / "georgia.ttf", 36)
    while max(d.textlength(b, font=body) for b in t["bullets"]) > left_limit - lx - 40 and body.size > 24:
        body = font(FONTS / "georgia.ttf", body.size - 1)
    by = 380
    for b in t["bullets"]:
        d.ellipse([lx + 2, by + body.size * 0.42, lx + 14, by + body.size * 0.42 + 12], fill=GOLD)
        d.text((lx + 36, by), b, font=body, fill=CREAM)
        by += round(body.size * 1.75)

    foot = font(FONTS / "georgia.ttf", 28)
    d.text((lx, H - 110), t["footer"], font=foot, fill=MUTED)

    out.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(out, optimize=True)
    print(out)


if __name__ == "__main__":
    shots = sys.argv[1:3]
    for lang in ("pt", "en"):
        build(lang, shots, ROOT / f"media/banner-{lang}.png")
