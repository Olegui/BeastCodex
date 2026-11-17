import os, tempfile, unittest
from tools import build_data
from tools.huntmaster import read_lua_tables

HM_SNARLER = {"id": 5356, "name": "Snarler", "family": "wolf", "min": 42, "max": 42, "cls": "rare",
              "diet": "Meat", "map": 1444, "area": 357, "coords": [(74.8, 35.4), (75.2, 35.8)]}
HM_SPIDER = {"id": 30, "name": "Forest Spider", "family": "spider", "min": 5, "max": 6, "cls": None,
             "diet": "Meat", "map": 1429, "area": 12, "coords": [(28.4, 66.4)]}
PET_SNARLER = {"id": 5356, "name": "Snarler", "look": "wolfskinblack", "family": "wolf", "min": 42,
               "max": 42, "cls": "rare", "zone": "Feralas", "tame": True, "note": None, "speed": 2.0,
               "abilities": [("Bite", 6), ("Furious Howl", 3)]}
PET_NEW = {"id": 777, "name": r'Odd "Name" \ Beast', "look": "raptorskinred", "family": "raptor",
           "min": 20, "max": 21, "cls": None, "zone": "Elwynn Forest", "tame": False,
           "note": "Friendly to Alliance players.", "speed": None, "abilities": []}
LOOKS = {"wolfskinblack": {"name": "Charcoal Black Wolf", "family": "wolf", "status": "tameable"},
         "raptorskinred": {"name": "Red Raptor", "family": "raptor", "status": "tameable"},
         "unusedlook": {"name": "Nobody Uses This", "family": "wolf", "status": "unused"}}


def by_id(out):
    return {c["id"]: c for c in out}


class MergeTest(unittest.TestCase):
    def test_both_sources(self):      # coords and map from Huntmaster, the rest from Petopia
        c = build_data.merge({5356: HM_SNARLER}, [PET_SNARLER], {})[0]
        self.assertEqual(c["coords"], [74.8, 35.4, 75.2, 35.8])
        self.assertEqual((c["map"], c["look"], c["speed"], c["zone"]), (1444, "wolfskinblack", 2.0, "Feralas"))

    def test_huntmaster_only(self):
        c = build_data.merge({30: HM_SPIDER}, [], {})[0]
        self.assertTrue(c["tame"])
        self.assertIsNone(c["look"])
        self.assertEqual((c["abilities"], c["speed"], c["family"]), ([], None, "spider"))

    def test_petopia_only_uses_wowhead_and_area_table(self):
        out = build_data.merge({30: HM_SPIDER}, [PET_NEW], {777: {"area": 12, "coords": [(1.0, 2.0)]}})
        c = by_id(out)[777]
        self.assertEqual((c["map"], c["coords"]), (1429, [1.0, 2.0]))

    def test_wowhead_area_without_known_map_drops_coords(self):
        c = build_data.merge({}, [PET_NEW], {777: {"area": 9999, "coords": [(1.0, 2.0)]}})[0]
        self.assertEqual((c["map"], c["coords"]), (None, []))

    def test_zone_name_table_gives_map_without_coords(self):
        hm = {30: HM_SPIDER}
        pet = [dict(PET_SNARLER, id=30, name="Forest Spider", zone="Elwynn Forest", family="spider"), PET_NEW]
        c = by_id(build_data.merge(hm, pet, {}))[777]
        self.assertEqual((c["map"], c["coords"]), (1429, []))

    def test_no_location(self):
        c = build_data.merge({}, [PET_NEW], {})[0]
        self.assertEqual((c["map"], c["coords"]), (None, []))

    def test_same_npc_in_two_looks_is_kept_once(self):
        out = build_data.merge({}, [PET_SNARLER, dict(PET_SNARLER, look="other")], {})
        self.assertEqual(len(out), 1)
        self.assertEqual(out[0]["look"], "wolfskinblack")

    def test_sorted_by_family_then_look_then_name(self):
        out = build_data.merge({30: HM_SPIDER}, [PET_SNARLER, PET_NEW], {})
        self.assertEqual([c["id"] for c in out], [777, 30, 5356])   # raptor, spider, wolf

    def test_validate_rejects_bad_data(self):
        good = build_data.merge({5356: HM_SNARLER}, [PET_SNARLER], {})
        build_data.validate(good)
        with self.assertRaises(ValueError):
            build_data.validate(good + good)                              # duplicate ID
        with self.assertRaises(ValueError):
            build_data.validate([dict(good[0], coords=[101.0, 5.0])])     # out of range
        with self.assertRaises(ValueError):
            build_data.validate([dict(good[0], family="dragon")])         # unknown family
        with self.assertRaises(ValueError):
            build_data.validate([dict(good[0], coords=[1.0])])            # odd count


class EmitTest(unittest.TestCase):
    def emit(self, creatures):
        path = os.path.join(tempfile.mkdtemp(), "Creatures.lua")
        build_data.emit_lua(creatures, LOOKS, {"wolf": "Meat", "raptor": "Meat"}, path)
        with open(path, encoding="utf-8") as f:
            text = f.read()
        return text, read_lua_tables(text)

    def test_emit_roundtrip(self):
        text, t = self.emit(build_data.merge({5356: HM_SNARLER}, [PET_SNARLER, PET_NEW], {}))
        self.assertTrue(text.startswith("-- GENERATED"))
        self.assertIn("local ADDON, ns = ...", text)
        c = {x["id"]: x for x in t["Creatures"]}
        s = c[5356]
        self.assertEqual((s["name"], s["look"], s["min"], s["max"], s["cls"], s["map"], s["tame"], s["speed"]),
                         ("Snarler", "wolfskinblack", 42, 42, "rare", 1444, True, 2.0))
        self.assertEqual(s["abilities"], [["Bite", 6], ["Furious Howl", 3]])
        self.assertEqual(s["coords"], [74.8, 35.4, 75.2, 35.8])
        self.assertEqual(t["MaxLevel"], 42)
        self.assertEqual(t["FamilyDiet"]["wolf"], "Meat")
        self.assertEqual(t["Looks"]["wolfskinblack"], {"name": "Charcoal Black Wolf", "family": "wolf"})
        self.assertNotIn("unusedlook", t["Looks"])        # looks no creature uses are left out

    def test_lua_string_escaping_and_nil_fields(self):
        _, t = self.emit(build_data.merge({}, [PET_NEW], {}))
        c = t["Creatures"][0]
        self.assertEqual(c["name"], r'Odd "Name" \ Beast')
        self.assertEqual(c["tame"], False)
        self.assertNotIn("map", c)
        self.assertNotIn("speed", c)
        self.assertEqual(c["coords"], [])
        self.assertEqual(c["abilities"], [])
