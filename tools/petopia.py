"""Collects creature facts from Petopia Forever (names, levels, zones, looks).

Only factual fields are read; no images or descriptive text are copied.
"""
import hashlib, os, time, urllib.request

BASE = "https://www.wow-petopia.com/forever/"


class Fetcher:
    """HTTP GET with an on-disk cache and a delay between real requests."""

    def __init__(self, cache_dir, delay=1.5):
        self.cache_dir, self.delay = cache_dir, delay
        os.makedirs(cache_dir, exist_ok=True)

    def get(self, url):
        path = os.path.join(self.cache_dir, hashlib.sha1(url.encode()).hexdigest() + ".html")
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                return f.read()
        time.sleep(self.delay)
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                html = r.read().decode("utf-8", "replace")
        except Exception as e:
            raise RuntimeError("fetch failed for %s: %s" % (url, e)) from e
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        return html


import html as _html
import re

from tools.huntmaster import parse_cls, parse_levels


def _text(fragment):
    """Strips tags and decodes entities."""
    return _html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()


def parse_family_index(page):
    """Family slugs linked from the home page, in page order, without repeats."""
    return list(dict.fromkeys(re.findall(r"family\.php\?id=([a-z]+)", page)))


def parse_family(page):
    """{'name', 'diet', 'looks': [(look_id, status)]}; status: tameable|unused|untameable."""
    name = _text(re.search(r"<h1 class='familyheadingname[^>]*>(.*?)</h1>", page, re.S).group(1))
    diet = re.search(r"familydetailsabilities diet'><div class='familydetailsdata'>(.*?)</div>", page, re.S)
    looks, status = {}, "tameable"
    marks = re.finditer(r"family_model_subheading|name='(unused|untame)toggle_|look\.php\?id=([\w-]+)", page)
    for m in marks:
        if m.group(2):
            looks.setdefault(m.group(2), status)
        elif m.group(1):
            status = "unused" if m.group(1) == "unused" else "untameable"
        else:
            status = "tameable"  # a new model section starts with its tameable looks
    return {"name": name, "diet": _text(diet.group(1)) if diet else None, "looks": list(looks.items())}


def parse_look_title(page):
    m = re.search(r"<h1 class='lookheading[^>]*>(.*?)</h1>", page, re.S)
    return _text(m.group(1)) if m else None


def parse_tameable_count(page):
    """The page's own 'There are N tameable creatures' figure, or None."""
    m = re.search(r"There (?:are|is) (\d+) tameable creature", page)
    return int(m.group(1)) if m else None


_ROW = re.compile(r"<tr class='petstats.*?</tr>(?:\s*<tr class='petnotes.*?</tr>)?", re.S)


def parse_look(page):
    """Creature rows of a look page. Rows without a Wowhead NPC link are skipped."""
    out = []
    for row in _ROW.findall(page):
        npc = re.search(r"wowhead\.com/forever/npc=(\d+)", row)
        if not npc:
            continue
        level = re.search(r"<td class='level'>(.*?)</td>", row, re.S).group(1)
        lv, _, cls = level.partition("<br/>")
        lo, hi = parse_levels(_text(lv))
        notes = re.search(r"<td class='petnotes'[^>]*>(.*?)</td>", row, re.S)
        notes = notes.group(1) if notes else ""
        speed = re.search(r"Attack speed: ([\d.]+)", notes)
        abilities = [(a.rsplit(" ", 1)[0], int(a.rsplit(" ", 1)[1]))
                     for a in map(_text, re.findall(r"abilities\.php#[^>]*>(.*?)</a>", notes))]
        # What is left of the notes once abilities and speed are removed is the remark.
        note = _text(re.sub(r"Knows:.*?when tamed\.|Attack speed: [\d.]+", "", notes.replace("<br/>", " "), flags=re.S))
        out.append({
            "id": int(npc.group(1)),
            "name": _text(re.search(r"pettablename'>(.*?)</div>", row, re.S).group(1)),
            "min": lo, "max": hi, "cls": parse_cls(_text(cls)) or None,
            "zone": _text(re.search(r"<td class='zone'>(.*?)</td>", row, re.S).group(1)) or None,
            "tame": "Can Be Tamed" in row,
            "note": note or None,
            "speed": float(speed.group(1)) if speed else None,
            "abilities": abilities,
        })
    return out


def crawl(fetcher, log=print):
    """Walks every family and look. Returns (looks, diets, creatures, problems)."""
    looks, diets, creatures, problems = {}, {}, [], []
    for fam in parse_family_index(fetcher.get(BASE)):
        f = parse_family(fetcher.get(BASE + "family.php?id=" + fam))
        diets[fam] = f["diet"]
        log("%s: %d looks" % (fam, len(f["looks"])))
        for look_id, status in f["looks"]:
            page = fetcher.get(BASE + "look.php?id=" + look_id)
            rows = parse_look(page)
            looks[look_id] = {"name": parse_look_title(page) or look_id, "family": fam, "status": status}
            want, got = parse_tameable_count(page), sum(r["tame"] for r in rows)
            if want is not None and want != got:
                problems.append("%s: page says %d tameable, parsed %d" % (look_id, want, got))
            for r in rows:
                creatures.append(dict(r, look=look_id, family=fam))
    return looks, diets, creatures, problems
