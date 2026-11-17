import os, unittest
from tools import wowhead

with open(os.path.join(os.path.dirname(__file__), "fixtures", "wowhead_tooltip_5356.json"), encoding="utf-8") as f:
    SNARLER = f.read()


class WowheadTest(unittest.TestCase):
    def test_url(self):
        self.assertEqual(wowhead.url(5356), "https://nether.wowhead.com/forever/tooltip/npc/5356")

    def test_snarler(self):
        d = wowhead.parse_npc(SNARLER)
        self.assertEqual(d["area"], 357)
        self.assertEqual(d["coords"][0], (74.8, 35.4))
        self.assertEqual(len(d["coords"]), 40)
        self.assertTrue(all(0 <= x <= 100 and 0 <= y <= 100 for x, y in d["coords"]))

    def test_no_map(self):
        self.assertIsNone(wowhead.parse_npc('{"name":"X","tooltip":"<table></table>"}'))
        self.assertIsNone(wowhead.parse_npc('{"name":"X","map":{"zone":12,"coords":{}}}'))
        self.assertIsNone(wowhead.parse_npc('{"error":"not found"}'))
        self.assertIsNone(wowhead.parse_npc("<html>blocked</html>"))

    def test_multiple_floors_are_merged(self):
        d = wowhead.parse_npc('{"map":{"zone":1,"coords":{"0":[[1,2]],"1":[[3,4]]}}}')
        self.assertEqual(d["coords"], [(1, 2), (3, 4)])

    def test_coords_as_list(self):   # some responses use a JSON array instead of a floor map
        d = wowhead.parse_npc('{"map":{"zone":1,"coords":[[[1,2]]]}}')
        self.assertEqual(d["coords"], [(1, 2)])
