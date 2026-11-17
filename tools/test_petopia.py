import os, unittest
from tools import petopia

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def read(name):
    with open(os.path.join(FIX, name), encoding="utf-8") as f:
        return f.read()


HOME, WOLF, LOOK = (read("petopia_home.html"), read("petopia_family_wolf.html"),
                    read("petopia_look_wolfskinblack.html"))


class PetopiaTest(unittest.TestCase):
    def test_family_index(self):
        fams = petopia.parse_family_index(HOME)
        self.assertEqual(len(fams), 19)
        self.assertEqual(len(set(fams)), 19)
        self.assertIn("birdofprey", fams)

    def test_wolf_family(self):
        f = petopia.parse_family(WOLF)
        self.assertEqual(f["name"], "Wolves")
        self.assertEqual(f["diet"], "Meat")
        self.assertIn(("wolfskinblack", "tameable"), f["looks"])
        self.assertIn(("direwolfskindarkgrey-wolf", "unused"), f["looks"])
        self.assertIn(("direwolfskinbluebrown", "untameable"), f["looks"])
        self.assertIn(("direwolfskindarkblack", "tameable"), f["looks"])  # status resets per section
        ids = [l for l, _ in f["looks"]]
        self.assertEqual(len(ids), len(set(ids)))

    def test_look(self):
        self.assertEqual(petopia.parse_look_title(LOOK), "Charcoal Black Wolf")
        self.assertEqual(petopia.parse_tameable_count(LOOK), 4)
        cs = {c["id"]: c for c in petopia.parse_look(LOOK)}
        s = cs[5356]
        self.assertEqual((s["name"], s["min"], s["max"], s["cls"], s["zone"]),
                         ("Snarler", 42, 42, "rare", "Feralas"))
        self.assertEqual((s["tame"], s["speed"], s["note"]), (True, 2.0, None))
        self.assertEqual(s["abilities"], [("Bite", 6), ("Furious Howl", 3)])
        self.assertEqual((cs[2681]["min"], cs[2681]["max"], cs[2681]["cls"], cs[2681]["speed"]),
                         (50, 51, "elite", 1.7))
        self.assertEqual(cs[268558]["abilities"], [])
        self.assertEqual(sum(c["tame"] for c in cs.values()), 4)
        self.assertFalse(cs[4244]["tame"])
        self.assertEqual(cs[4244]["name"], "Shadow")
        self.assertEqual(cs[4244]["note"], "Friendly to Alliance players.")
        self.assertIsNone(cs[4244]["speed"])
        self.assertEqual(cs[11871]["cls"], "elite")

    def test_row_edge_cases(self):
        row = ("<tr class='petstats x'><td class='name'><img alt='Can Be Tamed' />"
               "<div class='pettablename'>King Bangalash</div></td>"
               "<td class='level'>43<br/>Rare Elite</td><td class='zone'>Stranglethorn Vale</td>"
               "<td class='links'><a href='https://www.wowhead.com/forever/npc=731'></a></td></tr>"
               "<tr class='petstats x'><td class='name'><img alt='Can Be Tamed' />"
               "<div class='pettablename'>Mystery &amp; Co</div></td>"
               "<td class='level'>??</td><td class='zone'></td><td class='links'></td></tr>")
        cs = petopia.parse_look(row)
        self.assertEqual(len(cs), 1)                      # no Wowhead link -> no ID -> skipped
        self.assertEqual((cs[0]["id"], cs[0]["cls"]), (731, "rareelite"))
