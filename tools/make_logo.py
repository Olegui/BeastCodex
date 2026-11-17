"""Turns the generated logo (art-src/logo-source.webp) into the CurseForge files.

    .cache/venv/Scripts/python tools/make_logo.py

The generated art is a dark round vignette on black. Here the vignette is
stretched so it reaches the corners: the background's radial profile is
measured, then every background-like pixel beyond START is moved toward the
profile value it would have if the vignette ended at the corner instead of at
the circle's edge. The change is added, not painted, so the texture stays;
pixels that do not look like background (antler, arrows, leaves) are left alone.
"""
import math, os
from statistics import median

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art-src", "logo-source.webp")
START, EDGE = 380, 495   # in a 1024 frame: where stretching begins, where the circle ends


def main():
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    k = w / 1024.0
    cx, cy = w / 2, h / 2
    px = im.load()
    corner = math.hypot(cx, cy)

    # Radial profile: median color of each 1-px ring (the median ignores the subject).
    rings = {}
    for y in range(h):
        for x in range(w):
            rings.setdefault(int(math.hypot(x - cx, y - cy)), []).append(px[x, y])
    profile = {r: tuple(median(c[i] for c in v) for i in range(3)) for r, v in rings.items()}

    def stretched(r):
        if r <= START * k:
            return profile[int(r)]
        t = (r - START * k) / (corner - START * k)
        return profile[int(START * k + t * (EDGE - START) * k)]

    out = im.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            r = math.hypot(x - cx, y - cy)
            if r <= START * k:
                continue
            p, here, want = px[x, y], profile[int(r)], stretched(r)
            dist = max(abs(p[i] - here[i]) for i in range(3))
            weight = max(0.0, min(1.0, 1 - (dist - 10) / 25))   # background-like: full change
            op[x, y] = tuple(max(0, min(255, int(p[i] + weight * (want[i] - here[i])))) for i in range(3))

    os.makedirs(os.path.join(ROOT, "media"), exist_ok=True)
    out.save(os.path.join(ROOT, "art-src", "logo.png"))
    for size in (400, 128):
        path = os.path.join(ROOT, "media", "logo-%d.png" % size)
        out.resize((size, size), Image.LANCZOS).save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
