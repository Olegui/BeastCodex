"""Reads Huntmaster's Data/TameableNPCs.lua (MIT, Yurri Studio / Justin Moody).

Also holds the small Lua-literal reader the data tools share.
"""
import re

FAMILY_SLUG = {
    "Bat": "bat", "Bear": "bear", "Birds of Prey": "birdofprey", "Boar": "boar",
    "Carrion Bird": "carrionbird", "Cat": "cat", "Core Hound": "corehound",
    "Crab": "crab", "Crocolisk": "crocolisk", "Fox": "fox", "Gorilla": "gorilla",
    "Hyena": "hyena", "Raptor": "raptor", "Scorpid": "scorpid", "Spider": "spider",
    "Tallstrider": "tallstrider", "Turtle": "turtle",
    "Wind Serpent": "windserpent", "Wolf": "wolf",
}

_TOKEN = re.compile(r'''
    \s+ | --[^\n]*                         # whitespace, comments (skipped)
  | (?P<str>"(?:[^"\\]|\\.)*")
  | (?P<num>-?\d+\.?\d*(?:[eE][-+]?\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<sym>[{}\[\]=,;])
''', re.X)

_ESC = {"n": "\n", "t": "\t", "\\": "\\", '"': '"', "'": "'"}


def _tokens(text, pos):
    while pos < len(text):
        m = _TOKEN.match(text, pos)
        if not m:
            raise ValueError("unexpected Lua at offset %d: %r" % (pos, text[pos:pos + 30]))
        pos = m.end()
        if m.lastgroup:
            yield m.lastgroup, m.group(m.lastgroup)


def _unquote(s):
    return re.sub(r"\\(.)", lambda m: _ESC.get(m.group(1), m.group(1)), s[1:-1])


def _value(kind, tok, it):
    if kind == "str":
        return _unquote(tok)
    if kind == "num":
        return float(tok) if re.search(r"[.eE]", tok) else int(tok)
    if kind == "name":
        return {"true": True, "false": False, "nil": None}[tok]
    if tok == "{":
        return _table(it)
    raise ValueError("unexpected token %r" % tok)


def _table(it):
    """Parses after '{'. Returns a list for purely positional tables, else a dict."""
    items, keyed = [], {}
    for kind, tok in it:
        if tok == "}":
            break
        if tok in ",;":
            continue
        if tok == "[":
            k = _value(*next(it), it)
            assert next(it)[1] == "]" and next(it)[1] == "="
            keyed[k] = _value(*next(it), it)
        elif kind == "name" and tok not in ("true", "false", "nil"):
            assert next(it)[1] == "="
            keyed[tok] = _value(*next(it), it)
        else:
            items.append(_value(kind, tok, it))
    if keyed:
        keyed.update({i + 1: v for i, v in enumerate(items)})
        return keyed
    return items


def read_lua_tables(text):
    """Returns {name: value} for every `<anything>.Name = {...}` assignment."""
    # Huntmaster has one `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC and A or B` value;
    # Forever is not the Classic Era project, so keep B.
    text = re.sub(r'WOW_PROJECT_ID\s*==\s*\w+\s+and\s+"[^"]*"\s+or\s+("[^"]*")', r"\1", text)
    out = {}
    for m in re.finditer(r"^[A-Za-z_]\w*\.(\w+)\s*=\s*", text, re.M):
        it = _tokens(text, m.end())
        out[m.group(1)] = _value(*next(it), it)
    return out


def parse_cls(text):
    """'Rare Elite' -> 'rareelite'; None stays None."""
    return text.replace(" ", "").lower() if text else None


def parse_levels(text):
    """'5-6' -> (5, 6); '42' -> (42, 42); '??' or missing -> (None, None)."""
    lo, _, hi = str(text).partition("-")
    if not lo.isdigit():
        return None, None
    return int(lo), int(hi or lo)


def load(path):
    with open(path, encoding="utf-8") as f:
        raw = read_lua_tables(f.read())["TameableNPCs"]
    out = {}
    for key, r in raw.items():
        lo, hi = parse_levels(r["level_range"])
        fam = r.get("family")
        out[int(key)] = {
            "id": int(key), "name": r["name"],
            "family": FAMILY_SLUG[fam] if fam else None,
            "min": lo, "max": hi, "cls": parse_cls(r.get("classification")),
            "diet": r.get("diet"), "map": r.get("ui_map_id"), "area": r.get("zone_id"),
            "coords": [(c["x"], c["y"]) for c in r.get("coords", [])],
        }
    return out
