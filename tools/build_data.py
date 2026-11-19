"""Merges Huntmaster, Petopia and Wowhead into Data/Creatures.lua.

Run from the repository root:  py -m tools.build_data
Network access is cached under .cache/; delete that folder to refetch.
"""
import collections, csv, io, os, re, sys

from tools import huntmaster, petopia, wowhead

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HUNTMASTER_FILE = os.path.join(ROOT, ".cache", "sources", "Huntmaster", "Data", "TameableNPCs.lua")
FAMILIES = set(huntmaster.FAMILY_SLUG.values())
HUNTMASTER_ABILITIES = os.path.join(ROOT, ".cache", "sources", "Huntmaster", "Data", "TameableAbilities.lua")
# Abilities Huntmaster has no spell for; IDs looked up on wowhead.com/forever (any rank names the ability).
EXTRA_ABILITY_SPELLS = {"Pinch": 1264735, "Sonic Blast": 1264478}


def ability_spells(path):
    """{ability name: one spell ID}: the lowest rank's, enough for the client to give its name."""
    with open(path, encoding="utf-8") as f:
        raw = huntmaster.read_lua_tables(f.read())["TameableAbilities"]
    out = {}
    for a in raw.values():
        ranks = sorted(a["ranks"], key=lambda r: r["rank"])
        if ranks:
            out[a["name"]] = ranks[0]["spell_id"]
    out.update(EXTRA_ABILITY_SPELLS)
    return out
# Must match CLS_KEY in Filter.lua.
CLASSIFICATIONS = {None, "rare", "elite", "rareelite", "spawned", "spawnedelite"}


# The client's area names (zones, dungeons, sub-areas) for the Forever build, from wago.tools.
AREA_TABLE_URL = "https://wago.tools/db2/AreaTable/csv?build=1.60.1.70959"


def area_ids(csv_text):
    """{lowercased English area name: area ID}; a top-level area wins over a sub-area of the same name."""
    out = {}
    rows = sorted(csv.DictReader(io.StringIO(csv_text)), key=lambda r: (r["ParentAreaID"] != "0", int(r["ID"])))
    for r in rows:
        out.setdefault(r["AreaName_lang"].lower(), int(r["ID"]))
    return out


def zone_area(zone, areas):
    """Area ID of a Petopia zone such as "Halycon's Lair, Blackrock Spire (Dungeon)": its last, outermost part."""
    top = re.sub(r"\s*\((Dungeon|Raid|Battleground)\)$", "", zone).split(", ")[-1]
    return areas.get(top.lower())


def merge(hm, pet_creatures, wh, areas=None):
    """hm: {id: huntmaster record}; pet_creatures: Petopia rows; wh: {id: {'area', 'coords'}}."""
    pet = {}
    for row in pet_creatures:
        pet.setdefault(row["id"], row)  # an NPC listed under two looks keeps the first

    # Huntmaster knows area -> uiMapID; creatures in both sources give zone name -> uiMapID.
    # Huntmaster stores the area ID in place of the uiMapID for zones it has no map ID
    # for (the new Forever zone); such a value is not a map.
    hm = {i: dict(r, map=None if r["map"] == r["area"] else r["map"]) for i, r in hm.items()}
    area_map = {r["area"]: r["map"] for r in hm.values() if r["map"] and r["area"]}
    zone_map = {pet[i]["zone"]: r["map"] for i, r in hm.items()
                if r["map"] and i in pet and pet[i]["zone"]}
    map_zone = {m: z for z, m in zone_map.items()}

    out = []
    for i in sorted(set(hm) | set(pet)):
        h, p, w = hm.get(i), pet.get(i), wh.get(i)
        src = p or h
        c = {
            "id": i, "name": src["name"], "family": src["family"] or (h and h["family"]),
            "look": p["look"] if p else None,
            "min": src["min"] if src["min"] is not None else (h and h["min"]),
            "max": src["max"] if src["max"] is not None else (h and h["max"]),
            "cls": src["cls"], "tame": p["tame"] if p else True,
            "note": p["note"] if p else None, "speed": p["speed"] if p else None,
            "abilities": [list(a) for a in p["abilities"]] if p else [],
            "zone": p["zone"] if p else None, "map": None, "coords": [],
        }
        if h and h["map"] and h["coords"]:
            c["map"], coords = h["map"], h["coords"]
        elif w and area_map.get(w["area"]):
            c["map"], coords = area_map[w["area"]], w["coords"]
        else:
            # No usable coordinates: still try to name the map so the zone shows localized.
            c["map"], coords = (h and h["map"]) or zone_map.get(c["zone"]), []
        c["coords"] = [v for xy in coords for v in xy]
        c["zone"] = c["zone"] or map_zone.get(c["map"])
        # No map: the area ID still lets the game name the zone in the player's language.
        c["area"] = zone_area(c["zone"], areas) if areas and c["map"] is None and c["zone"] else None
        out.append(c)
    out.sort(key=sort_key)
    return out


def sort_key(c):
    return (c["family"] or "", c["look"] is None, c["look"] or "", c["name"])


# Creatures no source lists yet, written by hand.
# shortcut: Ta'shkal (wowhead.com/forever/npc=268231, Level 58 Beast (Normal), Cat) is in no source the
# builder reads; drop it from here once Petopia lists it, or the creature shows up twice.
MANUAL = [
    # Level, abilities and spots from a Wowhead comment (2026-11-16) and Icy Veins.
    {"id": 268231, "name": "Ta'shkal", "family": "cat", "look": "tigerskingreen", "min": 57, "max": 58,
     "cls": "spawned", "zone": "Mourning's Rest, Mount Hyjal", "map": 2482, "area": None, "tame": True,
     "note": "Loot the Corrupted Cat Figurine from a fel pool with bones around it in Felblood Scar "
             "(47 75; also 48 82, 44 76, 44 82, 46 76), then click the Lonely Lantern above the "
             "Mourning's Rest cave (26 65) with it in your bags to spawn this green and orange cat. "
             "Same 1.0 attack speed as Broken Tooth.",
     # map: Mount Hyjal's uiMapID in the 1.60.1 UiMap table (wago.tools); coords: Wowhead's spawn points by the lantern.
     "speed": 1.0, "abilities": [["Prowl", 3], ["Cower", 6]], "coords": [26.4, 65.2, 26.5, 65.4, 26.6, 64.4]},
]


def add_manual(creatures, manual=MANUAL):
    """Hand-written entries join the generated ones, sorted the same way."""
    return sorted(creatures + [dict(c) for c in manual], key=sort_key)


def validate(creatures):
    """Raises ValueError on data the addon cannot use."""
    seen = set()
    for c in creatures:
        if c["id"] in seen:
            raise ValueError("duplicate NPC id %d" % c["id"])
        seen.add(c["id"])
        if c["cls"] not in CLASSIFICATIONS:
            raise ValueError("NPC %d has unknown classification %r" % (c["id"], c["cls"]))
        if c["family"] not in FAMILIES:
            raise ValueError("NPC %d has unknown family %r" % (c["id"], c["family"]))
        if len(c["coords"]) % 2 or any(not 0 <= v <= 100 for v in c["coords"]):
            raise ValueError("NPC %d has bad coordinates" % c["id"])


def _lua(v):
    if v is True or v is False:
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"%s"' % v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    if isinstance(v, (list, tuple)):
        return "{" + ",".join(_lua(x) for x in v) + "}"
    raise TypeError(type(v))


FIELDS = ("id", "name", "family", "look", "min", "max", "cls", "zone", "map", "area",
          "tame", "rumor", "note", "speed", "abilities", "coords")


def emit_lua(creatures, looks, diets, path, spells=None):
    used = {c["look"] for c in creatures if c["look"]}
    lines = ["-- GENERATED by tools/build_data.py. Do not edit by hand.",
             "-- Sources: Huntmaster (MIT, Yurri Studio / Justin Moody), Petopia Forever, Wowhead Forever.",
             "local ADDON, ns = ...", "", "ns.Looks = {"]
    for k in sorted(used):
        lines.append("  [%s] = { name = %s, family = %s }," % (_lua(k), _lua(looks[k]["name"]), _lua(looks[k]["family"])))
    lines += ["}", "", "ns.FamilyDiet = {"]
    for k in sorted(diets):
        if diets[k]:
            lines.append("  [%s] = %s," % (_lua(k), _lua(diets[k])))
    lines += ["}", "", "-- One spell per ability name; the addon asks the client for its name in the player's language.",
              "ns.AbilitySpell = {"]
    for k in sorted(spells or {}):
        lines.append("  [%s] = %d," % (_lua(k), spells[k]))
    lines += ["}", "", "ns.MaxLevel = %d" % max([c["max"] or 0 for c in creatures] or [0]), "", "ns.Creatures = {"]
    for c in creatures:
        lines.append("  { " + ", ".join("%s = %s" % (f, _lua(c[f])) for f in FIELDS if c.get(f) is not None) + " },")
    lines += ["}", ""]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def report(creatures, hm, pet_rows, problems, path):
    pet = {}
    for r in pet_rows:
        pet.setdefault(r["id"], r)
    fam = collections.Counter(c["family"] for c in creatures)
    lines = ["# Relatório dos dados (gerado)", "",
             "- Criaturas: %d (domáveis %d, indomáveis %d)" % (
                 len(creatures), sum(c["tame"] for c in creatures), sum(not c["tame"] for c in creatures)),
             "- Só no Huntmaster: %d; só no Petopia: %d; nas duas: %d" % (
                 len(set(hm) - set(pet)), len(set(pet) - set(hm)), len(set(hm) & set(pet))),
             "- Sem coordenadas: %d" % sum(not c["coords"] for c in creatures),
             "- Sem mapa: %d" % sum(c["map"] is None for c in creatures),
             "- Sem nível: %d" % sum(c["min"] is None for c in creatures),
             "", "## Por família", ""]
    lines += ["- %s: %d" % kv for kv in sorted(fam.items())]
    lines += ["", "## Divergências de nível entre Huntmaster e Petopia (vale o Petopia)", ""]
    for i in sorted(set(hm) & set(pet)):
        h, p = hm[i], pet[i]
        if p["min"] is not None and (h["min"], h["max"]) != (p["min"], p["max"]):
            lines.append("- %d %s: Huntmaster %s-%s, Petopia %s-%s" % (i, p["name"], h["min"], h["max"], p["min"], p["max"]))
    lines += ["", "## Contagens que não batem com a página do Petopia", ""] + ["- " + p for p in problems]
    lines += ["", "## Domáveis sem coordenadas", ""]
    lines += ["- %d %s (%s)" % (c["id"], c["name"], c["zone"] or "zona desconhecida")
              for c in creatures if c["tame"] and not c["coords"]]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def main():
    hm = huntmaster.load(HUNTMASTER_FILE)
    looks, diets, pet_rows, problems = petopia.crawl(petopia.Fetcher(os.path.join(ROOT, ".cache", "petopia")))
    fetch = petopia.Fetcher(os.path.join(ROOT, ".cache", "wowhead"))
    wh = {}
    need = sorted({r["id"] for r in pet_rows} - {i for i, r in hm.items() if r["map"] and r["coords"]})
    print("Wowhead lookups: %d" % len(need))
    for i in need:
        try:
            d = wowhead.parse_npc(fetch.get(wowhead.url(i)))
        except RuntimeError as e:  # 404 for NPCs Wowhead does not know
            print("  skip", e)
            d = None
        if d:
            wh[i] = d
    areas = area_ids(petopia.Fetcher(os.path.join(ROOT, ".cache", "wago")).get(AREA_TABLE_URL))
    creatures = add_manual(merge(hm, pet_rows, wh, areas))
    unnamed = sorted({c["zone"] for c in creatures if c["zone"] and c["map"] is None and not c["area"]})
    if unnamed:
        print("zones without a map or an area (shown in English):", "; ".join(unnamed))
    validate(creatures)
    spells = ability_spells(HUNTMASTER_ABILITIES)
    used = {a[0] for c in creatures for a in c["abilities"]}
    missing = sorted(used - set(spells))
    if missing:
        print("abilities without a spell (shown in English):", ", ".join(missing))
    emit_lua(creatures, looks, diets, os.path.join(ROOT, "Data", "Creatures.lua"), spells)
    report(creatures, hm, pet_rows, problems, os.path.join(ROOT, "docs", "data-report.md"))
    print("Wrote %d creatures" % len(creatures))


if __name__ == "__main__":
    sys.exit(main())
