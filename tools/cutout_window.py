"""Cuts an art-theme window out of an in-game screenshot, background removed.

    .cache/venv/Scripts/python tools/cutout_window.py <screenshot.png> Art/<Theme>.tga <out.png> <left,top,right,bottom>

The theme texture's alpha says exactly which pixels belong to the window
(panels, feathers, antlers, leaves). The script finds where the window sits
in the screenshot (scale and offset, by matching the texture's opaque pixels
against the screenshot), then keeps the screenshot pixels where the art is
opaque (they carry the list, model and text drawn over it) and the art's own
pixels where it is see-through, so edges keep no trace of the game world.
Needs Pillow and numpy (development only; .cache/venv).
"""
import sys
import numpy as np
from PIL import Image


def load_art(path):
    art = Image.open(path).convert("RGBA")
    a = np.asarray(art)[:, :, 3]
    ys, xs = np.nonzero(a)
    return art.crop((0, 0, xs.max() + 1, ys.max() + 1))  # image area inside the power-of-two canvas


def score(shot, art, x, y, step=3):
    """Lower is better: 1 - normalized correlation of brightness over the art's opaque pixels.
    Correlation, not color distance, since the game renders the texture a bit
    darker or lighter than the file."""
    w, h = art.size
    if x < 0 or y < 0 or x + w > shot.shape[1] or y + h > shot.shape[0]:
        return float("inf")
    a = np.asarray(art)[::step, ::step].astype(np.float32)
    mask = a[:, :, 3] == 255
    ga = a[:, :, :3].mean(axis=2)[mask]
    gs = shot[y:y + h:step, x:x + w:step, :3].astype(np.float32).mean(axis=2)[mask]
    ga, gs = ga - ga.mean(), gs - gs.mean()
    return 1.0 - float((ga * gs).sum() / (np.sqrt((ga * ga).sum() * (gs * gs).sum()) + 1e-6))


def locate(shot_img, art_full, box):
    """Searches widths and positions around `box` = (left, top, right, bottom), a rough bound."""
    shot = np.asarray(shot_img.convert("RGB"))
    l, t, r, b = box
    best = (float("inf"), None)
    for w in range(int((r - l) * 0.9), int((r - l) * 1.1), 4):
        art = art_full.resize((w, round(art_full.height * w / art_full.width)))
        for y in range(t - 40, t + 41, 4):
            for x in range(l - 40, l + 41, 4):
                sc = score(shot, art, x, y, 6)
                if sc < best[0]:
                    best = (sc, (w, x, y))
    _, (w0, x0, y0) = best
    best = (float("inf"), None)
    for w in range(w0 - 4, w0 + 5):
        art = art_full.resize((w, round(art_full.height * w / art_full.width)), Image.LANCZOS)
        for y in range(y0 - 4, y0 + 5):
            for x in range(x0 - 4, x0 + 5):
                sc = score(shot, art, x, y, 2)
                if sc < best[0]:
                    best = (sc, (w, x, y))
    return best


def cutout(shot_img, art_full, w, x, y):
    art = art_full.resize((w, round(art_full.height * w / art_full.width)), Image.LANCZOS)
    a = np.asarray(art).astype(np.float32)
    region = np.asarray(shot_img.convert("RGB"))[y:y + art.height, x:x + art.width].astype(np.float32)
    alpha = a[:, :, 3:4] / 255.0
    solid = alpha >= 0.99
    rgb = np.where(solid, region, a[:, :, :3])
    out = np.concatenate([rgb, a[:, :, 3:4]], axis=2).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


if __name__ == "__main__":
    shot_path, art_path, out_path = sys.argv[1:4]
    box = tuple(int(v) for v in sys.argv[4].split(","))
    shot = Image.open(shot_path)
    art = load_art(art_path)
    s, (w, x, y) = locate(shot, art, box)
    print("found window: width %d at (%d, %d), score %.3f" % (w, x, y, s))
    cutout(shot, art, w, x, y).save(out_path)
    print(out_path)
