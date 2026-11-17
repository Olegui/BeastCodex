"""Spawn coordinates from Wowhead Forever's public tooltip endpoint.

The regular NPC pages answer 403 to scripts; the tooltip endpoint (the one the
embeddable tooltip widget uses) returns JSON with the primary zone and coords.
"""
import json


def url(npc_id):
    return "https://nether.wowhead.com/forever/tooltip/npc/%d" % npc_id


def parse_npc(text):
    """{'area': int, 'coords': [(x, y)]}, or None when there is no usable map."""
    try:
        m = json.loads(text).get("map")
    except (ValueError, AttributeError):
        return None
    if not isinstance(m, dict) or not m.get("zone"):
        return None
    floors = m.get("coords") or []
    floors = floors.values() if isinstance(floors, dict) else floors
    coords = [(x, y) for floor in floors for x, y in floor]
    return {"area": int(m["zone"]), "coords": coords} if coords else None
